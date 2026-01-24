import type { Plugin } from "@opencode-ai/plugin";
import { promises as fs } from "fs";
import * as crypto from "crypto";
import * as os from "os";
import * as path from "path";

interface MessagePart {
  readonly type: string;
  readonly text?: string;
}

interface MessageInfo {
  readonly role?: string;
  readonly parts?: MessagePart[];
  readonly sessionID?: string;
}

interface EventLike {
  readonly type: string;
  readonly sessionID?: string;
  readonly properties?: {
    readonly info?: MessageInfo;
    readonly [key: string]: unknown;
  };
}

interface BoxSegment {
  readonly boxType: string;
  readonly fields: Record<string, string>;
  readonly raw: string;
}

interface BoxCreatedEvent {
  readonly event: "BoxCreated";
  readonly id: string;
  readonly ts: string;
  readonly box_type: string;
  readonly fields: Record<string, string>;
  readonly context: Record<string, unknown>;
  readonly initial_score: number;
  readonly schema_version: number;
}

const DEFAULT_ANALYTICS_DIR = path.join(
  os.homedir(),
  ".response-boxes",
  "analytics",
);
const DEFAULT_BOXES_FILE = path.join(DEFAULT_ANALYTICS_DIR, "boxes.jsonl");

const BOXES_FILE = process.env.RESPONSE_BOXES_FILE ?? DEFAULT_BOXES_FILE;
const SCHEMA_VERSION = 1;

// Generate a unique ID using crypto for collision resistance
function generateUniqueId(prefix: string): string {
  const timestamp = Date.now().toString(36);
  const random = crypto.randomBytes(4).toString("hex");
  return `${prefix}_${timestamp}_${random}`;
}

// Calculate initial score based on box type (matches scoring in hooks)
function calculateInitialScore(boxType: string): number {
  const highValueTypes = ["Reflection", "Warning", "Pushback", "Assumption"];
  const mediumValueTypes = [
    "Choice",
    "Completion",
    "Concern",
    "Confidence",
    "Decision",
  ];

  if (highValueTypes.includes(boxType)) {
    return 85;
  }
  if (mediumValueTypes.includes(boxType)) {
    return 60;
  }
  return 40;
}

async function ensureAnalyticsDir(): Promise<void> {
  const dir = path.dirname(BOXES_FILE);
  await fs.mkdir(dir, { recursive: true });
}

function extractBoxesFromText(text: string): BoxSegment[] {
  const segments: BoxSegment[] = [];

  // Match headers like: "⚖️ Choice ─────────────" (emoji + type + dashes)
  const headerPattern = /^(.+?)\s+([A-Za-z][A-Za-z ]*)\s+[-\u2500]{10,}\s*$/gm;

  const matches = Array.from(text.matchAll(headerPattern));
  if (matches.length === 0) {
    return segments;
  }

  for (let index = 0; index < matches.length; index += 1) {
    const match = matches[index];
    if (match.index === undefined) {
      continue;
    }

    const start = match.index;
    const end =
      index + 1 < matches.length && matches[index + 1].index !== undefined
        ? (matches[index + 1].index as number)
        : text.length;

    const block = text.slice(start, end).trim();
    if (block.length === 0) {
      continue;
    }

    const headerLineEnd = block.indexOf("\n");
    const boxTypeRaw = match[2] ?? "";
    const boxType = boxTypeRaw.trim();

    const body =
      headerLineEnd === -1 ? "" : block.slice(headerLineEnd + 1).trim();
    const fields: Record<string, string> = {};

    const fieldPattern = /\*\*([^*]+)\*\*:\s*(.+)/g;
    let fieldMatch: RegExpExecArray | null;
    while ((fieldMatch = fieldPattern.exec(body)) !== null) {
      const rawName = fieldMatch[1]?.trim();
      const value = fieldMatch[2]?.trim() ?? "";
      if (!rawName || value === "") {
        continue;
      }
      const key = rawName.toLowerCase().replace(/\s+/g, "_");
      if (!(key in fields)) {
        fields[key] = value;
      }
    }

    segments.push({
      boxType,
      fields,
      raw: block,
    });
  }

  return segments;
}

async function appendBoxEvents(events: BoxCreatedEvent[]): Promise<void> {
  if (events.length === 0) {
    return;
  }

  await ensureAnalyticsDir();

  const json = events.map((event) => JSON.stringify(event)).join("\n");
  const withNewline = `${json}\n`;

  await fs.appendFile(BOXES_FILE, withNewline, { encoding: "utf8" });
}

async function projectContextFromEvents(): Promise<string | null> {
  let raw: string;
  try {
    raw = await fs.readFile(BOXES_FILE, { encoding: "utf8" });
  } catch {
    return null;
  }

  const lines = raw.split(/\r?\n/);
  const boxes: BoxCreatedEvent[] = [];
  const learnings: { insight: string; confidence: number; ts: string }[] = [];

  for (const line of lines) {
    const trimmed = line.trim();
    if (trimmed === "") {
      continue;
    }

    let parsed: unknown;
    try {
      parsed = JSON.parse(trimmed);
    } catch {
      continue;
    }

    if (typeof parsed !== "object" || parsed === null) {
      continue;
    }

    const record = parsed as Record<string, unknown>;
    const eventType =
      typeof record.event === "string" ? record.event : "BoxCreated";

    if (eventType === "BoxCreated") {
      const ts =
        typeof record.ts === "string" ? record.ts : new Date(0).toISOString();
      const boxType =
        typeof record.box_type === "string"
          ? record.box_type
          : typeof record.type === "string"
            ? record.type
            : "Unknown";
      const fields =
        record.fields && typeof record.fields === "object"
          ? (record.fields as Record<string, string>)
          : {};

      boxes.push({
        event: "BoxCreated",
        id: typeof record.id === "string" ? record.id : `oc_legacy_${ts}`,
        ts,
        box_type: boxType,
        fields,
        context:
          record.context && typeof record.context === "object"
            ? (record.context as Record<string, unknown>)
            : {},
        initial_score:
          typeof record.initial_score === "number" ? record.initial_score : 50,
        schema_version:
          typeof record.schema_version === "number" ? record.schema_version : 0,
      });
    } else if (eventType === "LearningCreated") {
      const insight = typeof record.insight === "string" ? record.insight : "";
      if (insight === "") {
        continue;
      }
      const confidence =
        typeof record.confidence === "number" ? record.confidence : 0.0;
      const ts =
        typeof record.ts === "string" ? record.ts : new Date(0).toISOString();
      learnings.push({ insight, confidence, ts });
    }
  }

  if (boxes.length === 0 && learnings.length === 0) {
    return null;
  }

  const maxLearnings =
    Number.parseInt(process.env.BOX_INJECT_LEARNINGS ?? "3", 10) || 3;
  const maxBoxes =
    Number.parseInt(process.env.BOX_INJECT_BOXES ?? "5", 10) || 5;

  // Sort learnings by confidence (desc), then by timestamp (desc)
  learnings.sort((a, b) => {
    if (b.confidence !== a.confidence) {
      return b.confidence - a.confidence;
    }
    return (new Date(b.ts).getTime() || 0) - (new Date(a.ts).getTime() || 0);
  });

  // Sort boxes by timestamp (desc)
  boxes.sort((a, b) => {
    return (new Date(b.ts).getTime() || 0) - (new Date(a.ts).getTime() || 0);
  });

  const topLearnings = learnings.slice(0, maxLearnings);
  const topBoxes = boxes.slice(0, maxBoxes);

  const linesOut: string[] = [];
  linesOut.push("PRIOR SESSION LEARNINGS (from Response Boxes):");
  linesOut.push("");

  if (topLearnings.length > 0) {
    linesOut.push("Patterns (AI-synthesized learnings)");
    for (const l of topLearnings) {
      const conf = Number.isFinite(l.confidence)
        ? l.confidence.toFixed(2)
        : "--";
      linesOut.push(`• [${conf}] ${l.insight}`);
    }
    linesOut.push("");
  }

  if (topBoxes.length > 0) {
    linesOut.push("Recent notable boxes");
    for (const box of topBoxes) {
      const entries = Object.entries(box.fields);
      const summaryValues = entries
        .slice(0, 2)
        .map(([key, value]) => `${key}: ${value}`);
      const summary = summaryValues.join(" | ");
      linesOut.push(`• ${box.box_type}: ${summary}`);
    }
    linesOut.push("");
  }

  linesOut.push(
    "Apply relevant learnings using a 🔄 Reflection box in your response.",
  );

  return linesOut.join("\n");
}

const plugin: Plugin = (context) => {
  const { directory, worktree } = context;

  // Track which sessions have had context injected
  const injectedSessions = new Set<string>();

  // Track message counts per session for deduplication
  const sessionMessageCounts = new Map<string, number>();

  return {
    // Unified event hook for message capture
    event: async ({ event }: { event: EventLike }) => {
      if (process.env.RESPONSE_BOXES_DISABLED === "true") {
        return;
      }

      if (event.type !== "message.updated") {
        return;
      }

      const info = event.properties?.info;
      if (!info || info.role !== "assistant") {
        return;
      }

      const parts = info.parts ?? [];
      const textParts = parts.filter(
        (part) => part.type === "text" && typeof part.text === "string",
      );

      if (textParts.length === 0) {
        return;
      }

      const fullText = textParts.map((part) => part.text ?? "").join("\n\n");
      if (fullText.trim().length === 0) {
        return;
      }

      const boxes = extractBoxesFromText(fullText);
      if (boxes.length === 0) {
        return;
      }

      const nowIso = new Date().toISOString();
      const sessionId = event.sessionID ?? info.sessionID ?? "unknown";

      // Track message count for this session to create unique IDs
      const currentCount = sessionMessageCounts.get(sessionId) ?? 0;
      sessionMessageCounts.set(sessionId, currentCount + 1);

      const baseContext: Record<string, unknown> = {
        source: "opencode_plugin",
        session_id: sessionId,
        message_index: currentCount,
        agent: "OpenCode",
        directory,
        worktree,
      };

      const eventsToWrite: BoxCreatedEvent[] = boxes.map((box, index) => ({
        event: "BoxCreated",
        id: generateUniqueId(`oc_${sessionId.slice(0, 8)}`),
        ts: nowIso,
        box_type: box.boxType,
        fields: box.fields,
        context: baseContext,
        initial_score: calculateInitialScore(box.boxType),
        schema_version: SCHEMA_VERSION,
      }));

      await appendBoxEvents(eventsToWrite);
    },

    // System prompt transform: inject projected learnings/boxes
    "experimental.chat.system.transform": async (
      input: { sessionID: string },
      output: { system: string[] },
    ) => {
      if (process.env.RESPONSE_BOXES_DISABLED === "true") {
        return;
      }

      const { sessionID } = input;
      if (injectedSessions.has(sessionID)) {
        return;
      }

      const contextText = await projectContextFromEvents();
      if (!contextText) {
        return;
      }

      injectedSessions.add(sessionID);
      output.system.push(contextText);
    },

    // Optional: Use chat.headers for session correlation (stable API, Jan 2026)
    "chat.headers": (input: { sessionID: string }) => {
      return {
        "X-Response-Boxes-Session": input.sessionID,
        "X-Response-Boxes-Version": SCHEMA_VERSION.toString(),
      };
    },
  };
};

export default plugin;
