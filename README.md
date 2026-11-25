# Priorities

A native macOS task app with local storage and local AI. The first build is a working foundation for John's personal workflow.

## Run

Requirements: macOS 14 or later and Xcode with the Swift toolchain.

```sh
./scripts/run-app.sh
```

This builds `dist/Priorities.app` and opens it. You can also open that app directly after building it once.

```sh
./scripts/build-app.sh
./scripts/test.sh
```

The checkout's folder name contains literal quotation marks. SwiftPM's generated paths do not handle those reliably, so these scripts stage only the package manifest and source files into a private temporary directory, then copy the finished app back. Temporary build files are removed automatically.

## Working in this build

- Separate My Tasks, Suggestions, Owed to Me and Archive views.
- Local persistence of tasks, source evidence, settings, captured text and queued analysis.
- Manual task capture with person, due date, estimate, notes and an optional original promised deadline.
- Due-date ordering, overdue tasks in red and snoozing that preserves creation time and the original promise.
- Done marking with a tick and strikethrough, followed by archival after 60 seconds. Completion can be undone during that interval.
- Suggestions reviewed once per visible-list visit, with archival after the second visit ends or after a week. Dismissal archives immediately.
- Task details, evidence and change history.
- Pasted conversation capture with a persistent local AI queue. This is the first end-to-end source route.
- Ollama connection checks, downloaded model inventory, selection, load/unload, download progress, cancellation and deletion.
- Separate local text-model assignments for task understanding and voice interpretation, with a shared-model option. Speech-to-text is a distinct on-device engine.
- Configurable battery threshold. Local AI runs while plugged in OR at or above the threshold, queues work otherwise and resumes when power allows.
- Pause/resume processing and explicit local-only inference checks. Remote endpoints and cloud model aliases are rejected.
- On-device speech capture for supported English and Swedish speech models. Local model analysis saves clear captures and asks for clarification when details are uncertain.
- Tested core mapping from email follow-up flags to active tasks, with idempotent pending flag-clear intents. This is not yet connected to a real mailbox.

## Local AI setup

Install and start Ollama separately, then open Local AI in the app. The initial endpoint is `http://127.0.0.1:11434`. The app accepts only loopback HTTP endpoints.

Connect to inspect downloaded models, or enter a local model name from the Ollama library to download it. Downloads require internet access. Choose a downloaded model and run the synthetic connection test before processing a conversation.

No model is downloaded automatically. No model has yet been recommended based on a real task-quality benchmark. The synthetic test verifies a connection and output parsing; it does not establish extraction accuracy.

If other applications use the same Ollama runtime, manual unloading and deletion affect that model there too. Background battery handling cancels this app's work rather than shutting down the shared runtime.

## Voice capture

The app explicitly requires on-device speech recognition and never falls back to a remote recognizer. macOS may require microphone and Speech Recognition permission. A language unavailable for on-device recognition stays disabled in practice with an explanatory error.

English and Swedish are exposed as primary language choices. During the first UI check on John's Mac, the system reported English on-device support and no local Swedish support. No microphone capture was performed. Swedish and mixed-language support need an installed local speech model or another local speech engine. See [voice support](docs/voice-support.md) and [voice roadmap](docs/voice-roadmap.md).

## Local data

Normal application data is stored in `~/Library/Application Support/Priorities/workspace.json`, outside this repository. One versioned document contains tasks, settings, queued work and voice clarifications. Writes are atomic. Corrupt or newer-format data is preserved and surfaced as an error instead of being overwritten.

For an isolated manual test, set `PRIORITIES_DATA_DIRECTORY` to a private test directory before launching the executable. Add `--demo` to populate explicitly synthetic examples only when that store is empty. The normal first launch starts empty.

## Still to build or validate

- Direct Outlook, Gmail and Slack account authorization and synchronization. The Sources screen accurately shows them as unconnected.
- Morning summaries and notifications.
- Automatic approval rules, task updates across conversations and semantic duplicate detection.
- Model recommendations based on measured accuracy and performance on John's Mac.
- Real-runtime cancellation, battery interruption and model download recovery tests with an installed local model.
- Mixed English/Swedish voice validation and a more integrated local speech engine if macOS recognition is insufficient.
- Backup/export, accessibility refinements and distribution outside the local Mac.

All task analysis and speech processing must remain local. The first version has no cloud AI fallback and no hosted backend of its own.

## Project notes

The first release build and app signature check pass. The current suite has 55 passing XCTest cases. Native UI checks covered manual capture, task details, due-date sorting, snooze, completion/archival and model settings using synthetic data. Actual account connections, microphone recognition and live local-model inference have not been exercised.

- [Product brief](docs/product-brief.md)
- [Development approach](docs/development.md)
- [Build checkpoint](docs/BUILD-CHECKPOINT.md)

The repository was started from the clean local `main_je` baseline. The verified public repository `https://github.com/johnelvesjo/Priorities.git` is now connected as origin. Fetch succeeded and found no remote branches. No implementation has been pushed. Actual source messages, credentials and personal task data must never be committed.
