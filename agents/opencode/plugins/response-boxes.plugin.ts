import type { Plugin } from "@opencode-ai/plugin";
import { promises as fs } from "fs";
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

const DEFAULT_ANALYTICS_DIR = path.join(os.homedir(), ".response-boxes", "analytics");
const DEFAULT_BOXES_FILE = path.join(DEFAULT_ANALYTICS_DIR, "boxes.jsonl");

const BOXES_FILE = process.env.RESPONSE_BOXES_FILE ?? DEFAULT_BOXES_FILE;

async function ensureAnalyticsDir(): Promise<void> {
  const dir = path.dirname(BOXES_FILE);
  await fs.mkdir(dir, { recursive: true });
}

function extractBoxesFromText(text: string): BoxSegment[] {
  const segments: BoxSegment[] = [];

  // Match headers like: " Choice ─────────────" (type + dashes)
  const headerPattern = /^(.+?)\s+([A-Za-z][A-Za-z ]*)\s+[-\u2500]{10,}\s*$/gm;

  const matches = Array.from(text.matchAll(headerPattern));
  if (matches.length === 0) {
    return segments;
  }

  for (let index = 0; index < matches.length; index += 1) {
    const match = matches[index];
    if (match.index === undefined) {
      // Should not happen, but guard anyway
      continue;
    }

    const start = match.index;
    const end = index + 1 < matches.length && matches[index + 1].index !== undefined
      ? matches[index + 1].index as number
      : text.length;

    const block = text.slice(start, end).trim();
    if (block.length === 0) {
      continue;
    }

    const headerLineEnd = block.indexOf("\n");
    const headerLine = headerLineEnd === -1 ? block : block.slice(0, headerLineEnd);
    const boxTypeRaw = match[2] ?? "";
    const boxType = boxTypeRaw.trim();

    const body = headerLineEnd === -1 ? "" : block.slice(headerLineEnd + 1).trim();
    const fields: Record<string, string> = {};

    const fieldPattern = /\*\*([^*]+)\*\*:\s*(.+)/g;
    let fieldMatch: RegExpExecArray | null;
    // eslint-disable-next-line no-cond-assign
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

    let parsed: any;
    try {
      // eslint-disable-next-line @typescript-eslint/no-unsafe-assignment
      parsed = JSON.parse(trimmed);
    } catch {
      continue;
    }

    const eventType = typeof parsed.event === "string" ? parsed.event : "BoxCreated";

    if (eventType === "BoxCreated") {
      const ts = typeof parsed.ts === "string" ? parsed.ts : new Date(0).toISOString();
      const boxType = typeof parsed.box_type === "string"
        ? parsed.box_type
        : typeof parsed.type === "string"
          ? parsed.type
          : "Unknown";
      const fields = (parsed.fields && typeof parsed.fields === "object") ? parsed.fields as Record<string, string> : {};

      boxes.push({
        event: "BoxCreated",
        id: typeof parsed.id === "string" ? parsed.id : `oc_legacy_${ts}`,
        ts,
        box_type: boxType,
        fields,
        context: (parsed.context && typeof parsed.context === "object")
          ? parsed.context as Record<string, unknown>
          : {},
        initial_score: typeof parsed.initial_score === "number" ? parsed.initial_score : 50,
        schema_version: typeof parsed.schema_version === "number" ? parsed.schema_version : 0,
      });
    } else if (eventType === "LearningCreated") {
      const insight = typeof parsed.insight === "string" ? parsed.insight : "";
      if (insight === "") {
        continue;
      }
      const confidence = typeof parsed.confidence === "number" ? parsed.confidence : 0.0;
      const ts = typeof parsed.ts === "string" ? parsed.ts : new Date(0).toISOString();
      learnings.push({ insight, confidence, ts });
    }
  }

  if (boxes.length === 0 && learnings.length === 0) {
    return null;
  }

  const maxLearnings = Number.parseInt(process.env.BOX_INJECT_LEARNINGS ?? "3", 10) || 3;
  const maxBoxes = Number.parseInt(process.env.BOX_INJECT_BOXES ?? "5", 10) || 5;

  learnings.sort((a, b) => {
    if (b.confidence !== a.confidence) {
      return b.confidence - a.confidence;
    }
    return (new Date(b.ts).getTime() || 0) - (new Date(a.ts).getTime() || 0);
  });

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
      const conf = Number.isFinite(l.confidence) ? l.confidence.toFixed(2) : "--";
      linesOut.push(`• [${conf}] ${l.insight}`);
    }
    linesOut.push("");
  }

  if (topBoxes.length > 0) {
    linesOut.push("Recent notable boxes");
    for (const box of topBoxes) {
      const entries = Object.entries(box.fields);
      const summaryValues = entries.slice(0, 2).map(([key, value]) => `${key}: ${value}`);
      const summary = summaryValues.join(" | ");
      linesOut.push(`• ${box.box_type}: ${summary}`);
    }
    linesOut.push("");
  }

  return linesOut.join("\n");
}

const plugin: Plugin = (context) => {
  const { directory, worktree } = context;

  const injectedSessions = new Set<string>();

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
      const textParts = parts.filter((part) => part.type === "text" && typeof part.text === "string");

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

      const baseContext: Record<string, unknown> = {
        source: "opencode_plugin",
        session_id: sessionId,
        agent: "OpenCode",
        directory,
        worktree,
      };

      const eventsToWrite: BoxCreatedEvent[] = boxes.map((box, index) => ({
        event: "BoxCreated",
        id: `oc_${sessionId}_${Date.now()}_${index}`,
        ts: nowIso,
        box_type: box.boxType,
        fields: box.fields,
        context: baseContext,
        initial_score: 50,
        schema_version: 1,
      }));

      await appendBoxEvents(eventsToWrite);
    },

    // System prompt transform: inject projected learnings/boxes computed
    // directly from the shared event store.
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
  };
};

export default plugin;
