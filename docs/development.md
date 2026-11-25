# Development approach

## Repository boundary

This folder is the application repository. The parent folder's travel records and research are outside its Git history.

Implementation started on 25 November 2026 in the separate repository whose folder name is literally `"Priorities"`. Its clean baseline is commit `94b546c` on `main_je`; work began on `codex/initial-mac-app`. The verified public repository `https://github.com/johnelvesjo/Priorities.git` is now connected as origin. Fetch succeeded and returned no upstream branches because the remote is empty. No implementation has been pushed. No subscriptions have been purchased.

The first build uses native SwiftUI with Foundation, AppKit, IOKit and on-device Speech support. The domain and local runtime adapter live in a separate Swift package target with tests. There are no third-party package dependencies.

Current implementation and remaining work are described in the repository README. The source-provider connections and morning summary are not implemented yet. Model management uses a separately installed local Ollama runtime; no model has been installed or selected as part of development.

## Proposed workflow

Use the appropriate current upstream baseline when a remote exists. Implement bounded changes on short-lived branches, inspect their diffs and run appropriate checks. Create pull requests only when John requests them. Keep actual source data and credentials outside version control.

## Delivery sequence

1. Discovery: agree on the first user, problem, sources and success criteria.
2. Feasibility: verify access to the selected sources and decide data and model boundaries.
3. Technical decision: compare suitable application stacks against the agreed constraints and document the choice. Some catch-up time after waking is acceptable. Test local inference and local English/Swedish transcription against labeled examples. The first version excludes cloud AI and a backend of our own. Verify a local runtime's model inventory, download, connection, load/unload and cancellation capabilities, including that selected models actually execute locally.
4. Vertical prototype: one source, evidence-backed task extraction, user correction and the confirmed due-date-ordered task view. Use local task storage and resumable direct source synchronization. Local AI must include battery-aware queue/resume behavior and in-app model selection and management. Measure catch-up time and source coverage; do not add a hosted backend or cloud inference fallback.
5. Quality evaluation: test ownership, missed obligations, duplication, changed commitments, completion, suggestion expiry and offline edits using synthetic fixtures. Also test battery-threshold crossings, unplugging, pause/restart and model switching during queued work. Measure suggestion quality and automatic-approval quality separately for each model configuration.
6. Personal pilot: use the application in John's real workflow and measure corrections, missed commitments and usefulness.
7. Expansion: add sources and automation based on observed value.

## Spending approach

List existing subscriptions and available equipment before buying anything. Verify current pricing and access restrictions when a specific purchase becomes relevant. Separate development-tool spending from model API usage and future per-user operating cost. Agree on spending limits before enabling paid services.

## Local model management feasibility, 25 November 2026

Model management is part of the app's first usable local AI capability. Propose one established external runtime initially, with an adapter that lets the app own model selection, recommendations, connection status, power policy and job control. No runtime has been selected, installed or tested for this app.

- LM Studio documents native REST endpoints for model inventory, download jobs and status, loading and unloading. Its CLI can estimate memory before loading. Download pause/cancel/resume exists in its UI, but the inspected native REST endpoint list does not establish equivalent remote controls. Verify them before promising those controls in this app. Sources: [native REST](https://lmstudio.ai/docs/developer/rest), [load and memory estimate](https://lmstudio.ai/docs/cli/local-models/load), [download status](https://lmstudio.ai/docs/developer/rest/download-status).
- Ollama documents model inventory, running models, streamed download progress and load/unload controls. Its repository documentation describes resuming interrupted pulls. Verify actual cancellation and shared-download behavior with the chosen version. Sources: [model inventory](https://docs.ollama.com/api/tags), [download API](https://docs.ollama.com/api/pull), [lifecycle controls](https://docs.ollama.com/faq), [download recovery](https://github.com/ollama/ollama/blob/main/docs/api.md).
- A local endpoint does not prove local inference. Verify the selected model's execution location and keep any cloud routing explicit. Source: [Ollama local and cloud access](https://docs.ollama.com/api/introduction).
- macOS exposes power-source information and change notifications. Use current external-power availability and battery percentage for the confirmed OR rule, including when charging is paused or the battery is full. Source: [Apple power-source information](https://developer.apple.com/documentation/iokit/1523867-iopsgetpowersourcedescription).

The bounded feasibility check should detect a runtime, list downloaded models, estimate or measure fit, load a selected model, extract a task from synthetic evidence, stop this app's inference when power becomes ineligible, unload an owned instance, and recover after a runtime restart. Also test an interrupted download before offering cancellation/resume. Distinguish downloaded, selected and loaded states. Never stop a shared runtime or another application's model work to enforce this app's battery policy.

## Direct source access without our own backend

The confirmed first-version architecture keeps storage and processing on the Mac while connecting directly to the existing source providers. Google recommends poll-based synchronization for installed Gmail clients; Microsoft Graph supports incremental message synchronization to a local store; Slack Socket Mode avoids a public webhook endpoint. Exact account permissions, authorization flows, retention gaps and recovery still require a feasibility check. Sources: [Gmail installed clients](https://developers.google.com/workspace/gmail/api/guides/push), [Graph message synchronization](https://learn.microsoft.com/en-us/graph/delta-query-messages), [Slack Socket Mode](https://docs.slack.dev/apis/events-api/using-socket-mode/).

Source-provider app registrations may still be necessary. They are separate from deploying our own cloud server. Slack currently excludes Socket Mode apps from its public Marketplace, so revisit distribution before a commercial launch.

## Hosting shortlist, 25 November 2026

Historical comparison only: the first version now explicitly excludes a backend of our own and cloud AI. These are not selected providers or authorized purchases. They apply only if John changes the scope for a later version. Published prices are in USD and exclude tax, model usage and additional consumption.

- Render: a paid web service ($7/month), background worker ($7/month) and smallest Postgres instance ($6/month) start around $20/month before storage and other charges. Using the 1 GB database tier makes the component total about $33/month. Frankfurt is an available EU region. A conventional worker is a good fit for resumable source imports and synchronization. Sources: [pricing](https://render.com/pricing), [regions](https://render.com/docs/regions).
- Supabase: Pro starts at $25/month for one Micro project with the included compute credit. It bundles Postgres, Auth and Edge Functions; Cron and Queues can coordinate background work. Stockholm and other specific EU regions are available. Paid functions have a 400-second wall-time limit and a 2-second CPU-time limit, so imports need small resumable batches or a separate worker. Sources: [pricing](https://supabase.com/pricing), [function limits](https://supabase.com/docs/guides/functions/limits), [regions](https://supabase.com/docs/guides/platform/regions).
- If continuous hosted monitoring is selected, use a provisional infrastructure allowance of $25 to $50/month before AI usage, pending the budget decision and an ingestion test. Free services with sleep or expiry behavior do not provide the desired continuity. Sources: [Render free-service limits](https://render.com/docs/free), [Supabase plan comparison](https://supabase.com/pricing).

If a hosted backend is introduced, prefer a small system with an authenticated application API, a background worker and one managed database. A database-backed jobs table is sufficient to evaluate initially; a separate Redis service or vector database is not an initial requirement. Source credentials and source content must remain outside Git and ordinary application logs for every architecture.

AI cost must be measured separately from hosting. For illustration only, 100 assessments per day for 30 days, each using 3,000 input tokens and 300 output tokens, costs $27 at $2 per million input tokens and $10 per million output tokens. These are current standard rates for GPT-6.2 Sol and Claude Sonnet 5.5. This is a calculation scenario, not an estimate of John's actual volume or a model choice. It excludes additional passes, reasoning tokens beyond the assumed output, retries, initial historical imports and any other charges. Sources: [OpenAI pricing](https://developers.openai.com/api/docs/pricing), [Claude pricing](https://claude.com/pricing).
