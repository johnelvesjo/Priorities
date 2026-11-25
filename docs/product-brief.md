# Product brief

## Confirmed intent

John wants to build desktop software for macOS that connects to sources where actions, todos and projects are discussed, proposed, agreed or changed. It should infer what the user needs to do and help prioritize that work.

Development will happen locally, with a repository in John's personal GitHub account. John wants hands-on guidance on product structure, technical decisions, tools and spending, with substantial discovery before implementation.

Product direction confirmed: personal first, potentially commercial. John is the first user. Solve his problem first, then test whether others share it strongly enough to pay. Commercial demand remains unvalidated.

Discovery uses frequent, focused questions in small rounds, helping John understand the consequences before implementation. Separate confirmed choices from recommendations and unresolved details.

## Confirmed problem and product requirements

Action points are scattered across emails, meetings and chats. John lacks one trusted overview of commitments across projects, making it difficult to decide what to focus on next.

- Email is the main source of action points.
- The first working version should cover Outlook work, Gmail personal and Slack. Specific accounts, workspace permissions and the order of implementation remain open.
- Goldfish is an explicitly requested source. Surface it prominently in the source catalog alongside the initial email and Slack priorities.
- Include planned placeholders for other reasonable source providers across email, calendars, messaging, meetings, task tools, CRMs, documents, local context, developer tools and customer support. A placeholder is not a working connection or a promise of unrestricted provider access.
- Support multiple independent accounts, workspaces, folders or devices for the same provider. Multiple Outlook or Gmail accounts and multiple Slack workspaces are first-class requirements, not a single global connection setting.
- Other relevant sources include calendars, WhatsApp, Apple Messages, Taalk calls and chats, Granola meeting notes, Monday and other CRMs, and information captured by Goldfish screen recording. Later integration order and access methods remain open.
- Microsoft To Do is an existing tool and a major interaction reference. Whether to replace it or synchronize with it remains open.
- Track action points and their due dates, allow project membership, and support snoozing.
- Track things other people owe John in a separate list, normally sorted by due date, with similar snooze and completion controls to his own task list.
- Connect to multiple sources through MCP and other appropriate integration methods. Each source's actual access capabilities must be verified.
- The first version uses local processing and storage, including local voice transcription, with no cloud AI and no backend of our own. This is a firm requirement and supersedes earlier permission to consider cloud AI for this version. Direct authenticated connections to Outlook, Gmail and Slack remain allowed for retrieving source data.
- Some catch-up time for new suggestions and the morning summary after the Mac wakes is acceptable. Continuous processing while the Mac sleeps is not a first-version requirement. The specific local models and runtime remain to be selected and evaluated; inadequate quality does not authorize a cloud fallback.
- Local inference must respect a user-configurable battery threshold: run when plugged in OR when the battery is at or above the chosen minimum. Otherwise queue work and automatically resume when power allows.
- The local AI capability must include model management within the app: selecting, recommending, connecting to and controlling downloaded models. John must be able to change the model.
- Support separate models for different roles, including task understanding, voice interpretation, speech-to-text and potentially spoken responses. Do not assume one model handles every role.
- An email flagged for follow-up is an explicit task signal and must become an active task. Marking that task Done should clear the source flag when the provider supports it and the account has the needed permission.
- During the early pilot, missing a real task is worse than producing extra suggestions. This favors broad candidate detection; it does not by itself authorize broad automatic approval.
- Provide a morning summary and occasional urgent notifications. Delivery channel, timing, timezone and the definition of urgent remain undecided.
- Easy manual task creation through a visible Add Task button is required.
- Task creation by voice is required. Voice capture should understand the action, person, due date and estimated duration, rather than only transcribing the title.
- Broader two-way voice interaction remains a possible later capability. Spoken responses, model requirements and implementation remain to be decided.

The immediate product aim is a trusted cross-project overview that supports choosing the next focus. The main active list is ordered by current due date, rather than an opaque AI priority score. Rules for inferred commitments and automatic approval remain open.

## Confirmed workflow decisions, 25 November 2026

### Source catalog and multiple connections

- Separate the provider catalog from individual source connections. One provider can have many named connections.
- Let users add, label, edit and remove planned source placeholders before the integrations are implemented. Keep them explicitly marked Planned and do not request credentials or imply synchronization has started.
- Every connection has a stable identity independent of its display label. Keep the provider ID as a string so saved entries for a future or temporarily unavailable provider are not discarded.
- Email accounts and Slack workspaces must remain distinguishable in source attribution. Future authentication, synchronization positions, access scopes, failures and writeback must belong to the appropriate connection.
- Goldfish supplies observed local context. Its screen-derived coverage is partial and must not be presented as a complete mailbox or calendar synchronization.
- Keep the existing manual and voice capture routes available separately from planned integrations. Adding a placeholder does not connect an account or send its content anywhere.

### Local AI power and model management

- Let John set the minimum battery percentage for running local AI.
- Local AI may run when the Mac is plugged in OR when its battery is at or above that minimum. Both conditions are not required together.
- When the power condition is not met, queue processing and resume automatically when it is met again. Do not automatically route this queued work to cloud AI because of a battery pause.
- Provide a model management area for model recommendations, selection, connection and control of downloaded models, including switching the model used by the app.
- Only locally executing models are eligible in the first version. A local runtime endpoint must not silently route inference to a cloud provider.
- The default minimum battery percentage is not yet selected. Detailed runtime choice and supported model capabilities remain technical decisions.

### Manual and voice capture

- Provide an easy-to-find Add Task button for manual entry.
- Support adding a task by speaking.
- Interpret spoken details into the action, person, due date and estimated duration. For example, "Send Anna the proposal tomorrow, allow 30 minutes" supplies all four fields.
- Understand English and Swedish, including sentences that mix both languages.
- Save a dictated task immediately when the action and relevant details are clear. Ask only about uncertain details rather than requiring a preview or confirmation for every task.
- Immediate saving of a user-dictated task is separate from automatic approval of tasks inferred from connected sources; the latter policy remains undecided.
- John is interested in simultaneous listening and speaking, including NVIDIA models, and voice controls for marking Done, removing and snoozing tasks. These are proposed capabilities requiring model/runtime research and a clear ambiguity/undo policy. They are not implemented by ordinary dictation.

### Email follow-up flags

- Import a follow-up flag as an Active task without asking AI whether it should be a task.
- Keep a stable link to the account and source email so repeated synchronization does not create duplicate tasks.
- Preserve the original task creation date, user-edited due date and completion state when the same flag is seen again.
- On Done, clear the provider's flag when supported. Track pending or failed writeback explicitly rather than implying the flag was cleared.
- Provider mappings need verification. Outlook follow-up flags and Gmail stars are different features; do not silently equate all labels or importance markers with a follow-up flag.
- The behavior for undoing completion after a flag has already been cleared, and for flags cleared externally, still needs a decision.

### Task states and suggestion review

- The main states are Suggested, Active and Archived.
- Source activity generates suggested tasks for John to approve. High-conviction suggestions may eventually be approved automatically; the qualifying policy remains undecided.
- A suggestion archives if it is reviewed twice, is older than one week, or is explicitly dismissed. Any one of these conditions is sufficient.
- Seeing a suggestion in the visible list counts as reviewing it, at most once per review session. Opening its details or pressing a review button is not required.
- Review-session boundaries and the exact moment of automatic archival still need to be defined.
- Archive distinguishes completed tasks, removed tasks and suggestions never approved. More detailed archive reasons are a proposal below.
- The review and age rules apply to suggestions, not accepted active tasks.

### Due dates, snoozing and presentation

- Snoozing pushes the current due date forward and preserves the original creation date.
- All active tasks remain in their respective list, including snoozed tasks. John's own tasks and things others owe him use separate lists. Snoozing does not hide items.
- Sort by time until due, with the most overdue first, then tasks due soon, then upcoming tasks.
- Overdue tasks are red; other tasks are black. Presentation in dark mode remains to be decided.
- If a source gives an externally promised deadline, preserve it in the task details while using the current, editable due date for sorting.
- For a task without an explicit deadline, AI proposes a due date that John can change when approving it.
- The task should include origin, counterparty, relevant background, related information and an estimated duration.

### Things other people owe John

- Show these items in a separate list from John's own tasks. The final list name remains undecided.
- Normally sort this list by current due date, consistent with John's own task flow.
- Provide similar snooze options. Moving the current due date should preserve original creation time and the externally promised date in the details, following the existing snooze rules.
- Provide Done marking, using the shared completion behavior below.

### Completion and archival

- In both John's own task list and the list of things others owe him, marking Done keeps the item visible with its checkbox ticked and its text struck through for one minute.
- After that one-minute period, move the completed item to Archived.

### Proposed details, not yet confirmed

- Show local AI status plainly, including selected model, whether it is loaded, why processing is paused, queued work and the last successfully processed activity.
- Check power eligibility before loading or starting local AI and when power changes. If eligibility is lost during a request, safely stop or cancel the work and requeue it rather than publishing incomplete task data.
- Keep ordinary task viewing, typed capture, snoozing and completion available while AI is paused. Voice input and local speech recognition need an explicit policy if they require inference under the battery limit.
- Use safe retry and resume behavior so sleep, restart, a battery pause or a model switch cannot lose queued work or duplicate tasks. Consider a small resume margin to avoid repeated starts and stops near the battery threshold.
- Recommend models using task accuracy, English and Swedish support, context capacity, measured speed, available memory and download size. Distinguish measured results from estimates.
- Expose model download and installation progress, cancellation and resume where supported, storage usage, deletion, selection, load and unload, connection checks, and a small task-specific test. Show unsupported controls honestly rather than implying every runtime implements them.
- Switch models between jobs, preserving existing task decisions. Keep the model version with generated results, and revalidate automatic-approval behavior after a model change.
- Control only app-owned jobs and model instances. When connecting to a runtime shared with other applications, avoid stopping unrelated work or unloading models used elsewhere.
- Treat completion as effective immediately even while the ticked, struck-through row is still visible. Stop overdue alerts and exclude it from outstanding-work counts during that interval.
- Let John undo completion during the display period, cancelling the pending archival and restoring the item to its previous list.
- Show the responsible person clearly on each item in the list of things owed to John. Tracking an item or snoozing it does not send a reminder to that person.
- Tasks John deliberately creates through manual or voice entry should become Active directly and should not inherit suggestion expiry or review counts. Record their origin as Manual or Voice.
- After immediately saving a clear dictated task, show a compact saved-task confirmation with Edit and Undo. When clarification is needed, preserve the understood fields and ask about only the uncertain detail.
- For manual or voice tasks without a supplied due date, propose an editable date consistently with source suggestions. Whether an inferred date can be saved immediately or requires a question remains to be decided; do not reintroduce a mandatory preview for every otherwise clear dictated task.
- Resolve spoken dates using John's timezone, preserve ambiguous people or details for correction, and prevent a repeated save or transcription retry from creating duplicate tasks.
- Keep a suggestion available through the end of its second review session, then archive it if it is still unapproved. Avoid removing a row while John is deciding what to do with it.
- Measure suggestion age from when the suggestion was first created. Ordinary context updates should not restart its age or review count.
- Preserve a change history and distinguish why a suggestion archived: reviewed twice, older than one week, or dismissed.
- Date-only tasks become overdue after their local due day ends; tasks with a specified time become overdue after that time.
- Snooze shortcuts such as tomorrow are relative to the current time, including for tasks that are already overdue.
- Give tasks with identical due dates a stable secondary order, such as original creation time.
- Preserve John's due-date changes when later source messages arrive. New evidence may suggest a change, rather than silently overwriting his choice.
- An explicit approval should take precedence over a concurrent automatic expiry during offline synchronization.

## Proposed architecture, awaiting technical decisions

The confirmed first-version boundary is local task storage, local AI and local voice transcription, with no backend of our own. This is not a fully offline app: Outlook, Gmail and Slack remain external cloud services, and downloading new activity requires direct authenticated connections to them. Sign-in, model downloads and software updates can also require internet access.

For a personal prototype, test local models through an existing runner against the same labeled task examples. Keep the inference interface replaceable between supported local models. Measure missed tasks, wrong ownership and dates, English and Swedish understanding, processing speed, backlog recovery and resource use before choosing. Evaluate the app's model behavior locally; no cloud model calls are part of its first-version workflow or harness. Model management controls are part of the first usable local AI capability. An established external runtime can supply inference and model lifecycle APIs while the app supplies its own management interface; whether to embed the engine is a separate technical decision.

Propose supporting one established runtime with several interchangeable models initially. Verify which controls its actual version exposes. The app owns the battery policy, durable processing queue, recommendations and task-specific evaluation, even where a runtime handles downloads and inference.

Propose running source connectors, task and evidence storage, queued processing, model settings and inference on the Mac. Use direct incremental source synchronization or a supported desktop connection instead of operating webhook receivers in the cloud. Resume from saved source positions after waking, reconcile any expired history, and show catch-up progress and source freshness. A morning summary should indicate incomplete processing instead of implying all sources have been checked. Actual acceptable delay and measured performance remain to be established.

Speech transcription must also stay on the Mac. Verify English, Swedish and mixed-language behavior and prevent remote fallback. Propose keeping backups and export local by default and deferring cloud synchronization. A user-selected backup destination is a separate choice. Do not add cloud analytics or content-bearing crash uploads as an incidental dependency of the proposed local architecture.

An always-on service would require an explicit future change of direction if mobile access, synchronization between devices or faster overnight updates justify it. It is outside the first-version scope. A cloud collector with local inference could collect changes while the Mac sleeps, but interpretation would still wait for an available local model.

Keep task viewing, approval, snoozing and completion available locally, including while offline or while inference is paused. Keep source credentials protected, preserve synchronization cursors, make repeated event delivery safe and retain a compact change history. Any future hosting design must be evaluated separately rather than introduced as a first-version dependency.

Use different quality thresholds for generating a suggestion and automatically approving it. John's preference for catching more possible tasks applies to the suggestion inbox. The qualifying rules for automatic approval need a separate decision and validation.

The morning summary should distinguish new suggestions, active tasks due or overdue, automatic additions and source connections that are not current. Exact content remains a proposal. A summary must not claim complete coverage when a connector has fallen behind.

## Proposed product principles, awaiting discussion

1. Explain every inferred commitment with source evidence and a route back to its context.
2. Distinguish suggestions, requests, explicit commitments and inferred opportunities.
3. Track ownership, changes, completion, cancellation and dependencies over time.
4. Combine related evidence without turning repeated mentions into duplicate tasks.
5. Explain proposed due dates and relevant consequences while preserving the confirmed due-date order of the main active list.
6. Make corrections easy and preserve them when new evidence arrives.
7. Begin with read-only source access and a small number of valuable integrations.

## Open decisions

- Concrete first workflow and success criteria for John's trusted overview; potential wider user group to explore later.
- Exact Outlook and Gmail accounts, Slack workspaces, calendar scope and boundaries between work and personal contexts.
- Specific local models and runtime, acceptable catch-up duration and first-version implementation. Local processing, including voice, and no cloud AI or backend of our own are confirmed. Direct connections to existing source providers remain necessary. Also resolve source storage and retention, backup, synchronization and local resource budgets.
- Default minimum battery percentage, any Low Power Mode or thermal policies, and treatment of voice processing while local AI is paused. The plugged-in OR minimum-battery rule and automatic queue/resume behavior are confirmed.
- First supported local runtime, model recommendations, connection setup, download controls and model-switching behavior. User-selectable model management is required.
- Role-specific model assignments, local speech synthesis or full-duplex voice feasibility, and safe task selection for voice Done/Remove/Snooze commands.
- Email flag provider mappings, permissions, pending-writeback behavior and undo when a remote flag has already changed.
- Review-session boundaries, visible exposure needed to count a review, suggestion age calculation and automatic archival timing.
- Automatic-approval rules and the evidence needed to enable them. Catching real tasks is more important than avoiding extra suggestions during the pilot.
- How AI should propose due dates using goals, deadlines, obligations and effort, without overriding the main list's confirmed sorting rule.
- Date-only versus timed deadlines, timezone behavior, snooze presets and treatment of equal due dates.
- Final name for the separate list of things others owe John. Both lists use the confirmed one-minute completed display before archival.
- Existing task systems to replace, complement or write back to.
- Morning-summary timing and delivery, urgency criteria, notification frequency and desired automation beyond task approval.
- Voice activation controls, handling of missing dates, correction interactions and offline behavior. Structured English and Swedish dictation, mixed-language sentences and immediate saving when clear are confirmed.
- macOS-only scope versus future iPhone, web or Windows support.
- Time commitment, learning goals, budget and first useful milestone.
- GitHub account, repository name and visibility. Proposed default: private.

## First proof to design after discovery

Use synthetic examples of realistic conversations to measure whether the app can identify the right owner, distinguish an idea from a commitment, connect later updates, recognize completion and explain a useful priority order. Then validate a narrow workflow with authorized real sources outside Git.

## Research status

The parent folder contains research/action-point-sources-access.md dated 2026-10-05. Treat it as historical background: the current research pass found incorrect claims, including its statements that Microsoft Graph lacks mail push notifications and Microsoft To Do lacks an official API. Current official references: [Outlook change notifications](https://learn.microsoft.com/en-us/graph/outlook-change-notifications-overview) and [To Do API](https://learn.microsoft.com/en-us/graph/api/resources/todo-overview?view=graph-rest-1.0).

Microsoft now states that To Do apps retire on 30 June 2027, with service and API retirement on separate later timelines. Treat To Do as a workflow reference and potential import source when planning; do not assume it is a durable backend for this app. Source: [Microsoft retirement notice](https://support.microsoft.com/en-us/planner/to-do-to-planner).

Do not assume an integration available inside a development assistant is also available to a separately distributed application. Exact account access remains untested for this app, and no hosting provider or model has been selected.
