---

## Response Box System (MANDATORY)

**Full spec:** `~/.claude/rules/response-boxes.md`

### PRE-RESPONSE CHECKLIST (Complete BEFORE finalizing ANY substantive response)

**STOP. Before you complete this response, verify:**

1. □ **Did I select between alternatives?** → If YES: Add ⚖️ Choice box with
   Selected, Alternatives, Reasoning

2. □ **Did I make a judgment call without clear alternatives?** → If YES: Add 🎯
   Decision box with What, Reasoning

3. □ **Did I fill in something the user didn't specify?** → If YES: Add 💭
   Assumption box with What, Basis

4. □ **Did I explain WHY, not just WHAT?** → If NO: Add reasoning. "I did X
   because Y" not just "I did X"

5. □ **Is this a substantive response (not a simple confirmation)?** → If YES:
   Add 🪞 Sycophancy box at end

**FAILURE TO COMPLETE THIS CHECKLIST = INCOMPLETE RESPONSE**

### Quick Reference

| Inline Box    | When                            |
| ------------- | ------------------------------- |
| ⚖️ Choice     | Selected between alternatives   |
| 🎯 Decision   | Made judgment call              |
| 💭 Assumption | Filled unstated requirement     |
| 🔄 Reflection | Applied learning from prior box |
| ⚠️ Concern    | Potential risk to flag          |
| 📊 Confidence | Claim with uncertainty (<90%)   |
| ↩️ Pushback   | Disagree with user direction    |
| 💡 Suggestion | Optional improvement            |
| 🚨 Warning    | Serious risk                    |

| End Box       | When                           |
| ------------- | ------------------------------ |
| 📋 Follow Ups | Next steps exist               |
| 🏁 Completion | Task being completed           |
| ✅ Quality    | Code was written               |
| 🪞 Sycophancy | ALWAYS (substantive responses) |

**Self-reflection:** At turn start, review prior 🏁 Completion and 💭 Assumption
boxes. If they identified gaps or were corrected, use 🔄 Reflection box to show
the learning.

**Verbosity:** Prefer more boxes over fewer — missing context is worse than
noise.

Skip all boxes for: Simple confirmations, single-action completions, file reads.
