# Chakra Sentinel (Phase 7 — read-only mode)

## Scope, honestly

The master manual's "local-first AI" (Section 55) means bundling an actual LLM runtime — llama.cpp or ONNX Runtime plus a model file. That's a genuinely separate, much larger undertaking (multi-GB model bundling, quantization choices, inference tuning, real testing on real hardware) than anything else in this project, and attempting it as a rushed add-on here would mean doing it badly. It deserves its own deliberate phase once there's a considered decision about which model/runtime, not a token gesture bolted onto Phase 7.

What's built instead: the **real architecture** the manual describes in Sections 13–17 — Intent Engine → Tool Router → Chakra system APIs, with every dispatch going through the Chakra Audit trail — implemented with deterministic pattern-matching instead of a language model. This is genuinely functional today, not a placeholder, and scoped to Risk 0 (read-only) only, exactly as Phase 7 is meant to be — Risk 1–3 actions need Phase 8's enforcement machinery first.

## NVIDIA NIM: optional upgrade, not the foundation

Discussed explicitly with the user before building this (see the conversation this shipped in). NVIDIA NIM (build.nvidia.com's hosted, OpenAI-compatible API) can make Sentinel's explanations genuinely conversational instead of raw command output — but routing every query through a third party by default would invert the manual's own stated priority (local-first, privacy, offline-capable, cloud "added later" as optional). So:

- **Off by default.** `/etc/chakra/sentinel.conf` ships with `NIM_API_KEY=` blank. Sentinel is fully offline and fully functional without it.
- **Never baked into the image.** A shared API key distributed in an OS image would be rate-limited or banned almost immediately, and is bad practice regardless — each user brings their own key if they want this.
- **Never in the decision path.** This is the important one, and it's what keeps this implementation honest to the manual's own AI safety principle (Section 16: `AI → Structured Intent → Policy Validator → Approved Chakra API`, never `AI → raw shell`). The deterministic pattern-matcher *always* decides which tool runs — that decision is Risk-0-scoped and audited before NIM ever sees anything. When configured, NIM only receives the tool's *already-collected* output and is asked to explain it in plain language. It cannot trigger a different action, and if the API call fails or is unreachable, Sentinel silently falls back to showing the raw data — it never blocks on the network.

## What Sentinel can do right now

`chakra-sentinel "question"` (or run with no args for an interactive prompt) routes to one of the Phase 6 tools based on keyword matching:

| You ask about... | Routes to |
|---|---|
| slow/performance | `chakra-health` + `chakra-processlens` |
| RAM/memory/which app | `chakra-processlens` |
| network/connections/ports | `chakra-netguard` |
| updates | `chakra-health` |
| security/threats/suspicious | `chakra-loglens --source security` |
| devices/USB/Bluetooth | `chakra-devicewatch` |
| logs/errors | `chakra-loglens` |
| health/status | `chakra-health` |

Every dispatch — matched or not — is logged to `/var/log/chakra/audit/sentinel.jsonl` via `chakra-audit-log` (`core/security/bin/`), in the exact `{actor, action, target, risk_tier, approved_by, result}` shape the manual's Chakra Audit section illustrates. This is the first thing in the project to actually produce audit records — Phase 5 deferred the real audit trail specifically until something existed to log.

## What's deliberately not here yet

- A real local LLM (see above) — separate future phase.
- Anything above Risk tier 0. No system-changing action goes through Sentinel yet; that needs Phase 8's Policy Engine enforcement first.
- Sentinel Modes (Daily/Developer/Privacy/Defense/Security Lab/Forensics/System Admin) actually changing *behavior* — the `--mode` concept is recorded in the audit log already, but since everything is Risk 0 today, mode doesn't gate anything yet. It will once Phase 8 exists.
- True natural-language understanding — this is keyword matching, not language understanding, and says so to the user when it doesn't recognize a query rather than pretending to.
