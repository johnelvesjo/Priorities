# Build checkpoint

Updated 25 November 2026 while building the first native macOS app.

## Location and Git

The actual repository folder is `/Users/johnelvesjo/Documents/Local AI/PROJECTS/Priorities/"Priorities"`, with literal quotation marks in its name. Work is on `codex/initial-mac-app`, based on clean initial commit `94b546c` from `main_je`. After John said "try now", the connected GitHub account verified the public repository `johnelvesjo/Priorities`. Origin is now `https://github.com/johnelvesjo/Priorities.git`. Fetch succeeded; the remote has no branches yet. Nothing has been pushed.

The older `../priorities-app` folder contains the original discovery documents. Their current copies in this repository are the implementation reference. Do not move private material from the parent project into this repository.

## Current work

- Native SwiftUI app with task lists, editor, details, snooze, suggestion review, one-minute completed display, archive and restoration.
- Atomic local workspace persistence, persistent processing queue and model settings.
- Ollama adapter with loopback-only connections, local model checks, model controls, downloads and structured extraction with source evidence validation.
- Battery-aware processing, queue/resume, serialized runtime controls and cancellation.
- On-device English/Swedish speech capture. Successful dictation automatically queues analysis; uncertain fields are reviewed. No cloud fallback.
- Build and test scripts stage sources into a clean temporary path because literal quotes in the repo folder break some SwiftPM paths. They now use the native build system to avoid the sandboxed dSYM failure in the default engine.

## Latest steering to preserve

1. Different models are assignable to task understanding and voice interpretation. Speech-to-text is already a distinct engine. NVIDIA PersonaPlex research is recorded in docs/voice-roadmap.md; native Mac and Swedish support are not established. Voice commands for Done, Remove and Snooze are a proposed next feature, not implemented yet.
2. Any email marked for follow-up is an explicit task, bypassing AI suggestion review. Marking it Done should clear the original flag when the provider supports it. The core mapping and pending write-intent boundary are implemented and tested; actual mailbox connections and writeback are not implemented yet. Do not claim flags are cleared by this build.
3. John plans to close the lid and wants work to continue. Available execution tools are local only; cloud handoff is unsupported. Work may suspend with the Mac. Do not change sleep settings or promise continued execution during sleep.

## Validation and next actions

- Final release build and app signature verification passed. App bundle: `dist/Priorities.app`. The scripts use SwiftPM's native build system to avoid the quoted-path and sandboxed dSYM problems. The toolchain emits a deprecation warning for that build-system option; it does not fail the build.
- Final `./scripts/test.sh` run passed 55 XCTest cases with zero failures. Coverage includes lifecycle, snooze extension, one-minute archival, corrupt and atomic persistence, local endpoint restrictions, extraction evidence validation, date-only deadlines including DST, and email-flag mapping/write intents.
- AppModel was reviewed and rewritten to address atomic saves, cancellation of manual model operations, stale responses and unload/reload races. Role-specific model assignment is implemented.
- Native UI checks passed for manual task capture, task details, due-date ordering, snoozing with preserved creation/promise dates, completion countdown and later archival, model-role settings, and unavailable-runtime messaging. The app's synthetic sample action and an explicitly named synthetic UI test task were used. No real account content was accessed.
- The app is open with synthetic examples in its normal local store. A separate isolated demo process was also launched and then stopped. Do not remove or overwrite normal app data automatically, because John may be interacting with the running app.
- The current Mac reports on-device English speech support but no local Swedish support. No microphone session was started. Live model inference, model downloads and direct source access remain untested. No runtime/model has been installed.
- Next work: dedicated local Swedish/mixed-language speech support; real model quality/cancellation tests; Outlook/Gmail/Slack authorization and synchronization; durable source-flag writeback; summaries and notifications; voice task commands. Keep unavailable connections and unfinished features visible and honest.

The first version has no cloud AI or backend of its own. All speech and task interpretation must stay local. Tasks, source content, runtime data and credentials stay outside Git. No commits or pushes have been made for this implementation yet.
