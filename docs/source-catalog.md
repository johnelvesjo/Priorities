# Source catalog and connection planning

The Sources screen separates capture methods that work now, planned source instances and the provider catalog. Goldfish is a priority source alongside Outlook, Gmail, Slack, Taalk, Granola and Monday.

## Provider versus connection

A provider describes a service, such as Gmail or Slack. A connection describes one account, workspace, folder or device belonging to that provider.

Examples using synthetic labels:

- Gmail: Personal inbox, Consulting inbox.
- Outlook: Work inbox, Shared team mailbox.
- Slack: Team workspace, Community workspace.
- Goldfish: This Mac, Another Mac.
- Local folders: Project notes, Meeting exports.

Each instance has its own UUID, display label and optional account or workspace hint. Labels are not account identity and need not be unique. The hint is descriptive metadata, not a password or token. Unknown provider identifiers must survive storage round trips.

All added catalog entries are currently planned placeholders. They do not authenticate, fetch content, clear flags or start monitoring. Removing a placeholder removes only that local planning entry.

## Catalog coverage

Include the user's named sources and common tools that contain requests, commitments, assigned work or supporting context:

- Email and calendars.
- Work and personal messaging.
- Calls, meeting notes and transcripts.
- Personal task tools and project systems.
- CRMs and customer support tickets.
- Documents, notes and shared files.
- Local activity and folders.
- Developer issues, reviews and projects.

This grouping is informed by current first-party ecosystem documentation, including [Google Workspace developer products](https://developers.google.com/workspace/products), [Microsoft Graph services](https://learn.microsoft.com/en-us/graph/overview-major-services), [Slack's integration categories](https://slack.com/integrations) and [Fireflies' CRM coverage](https://guide.fireflies.ai/articles/7306220598-crm-platforms-supported). These establish useful source families, not implementation or access guarantees for Priorities.

Personal messaging providers need individual access investigations. A placeholder does not imply that a supported personal-inbox API exists. Goldfish is local observed context, not an authoritative record of every message or calendar change.

## Future connector requirements

- Keep authentication, access scopes, synchronization cursors and connection health per instance.
- Namespace remote item identities by provider and account/workspace, so identical message IDs from different accounts cannot collide.
- After authentication, detect an accidentally repeated connection to the same real account without conflating genuinely distinct accounts.
- Reuse credentials across related source types only through an explicit credential profile, not by assuming matching display names identify the same account.
- Apply completion writeback only to the source account that owns the item.
- Preserve tasks and evidence when a connection is removed unless a separate explicit data-removal action is chosen.
- Continue local processing and storage. No connector placeholder introduces a hosted backend or cloud AI.
