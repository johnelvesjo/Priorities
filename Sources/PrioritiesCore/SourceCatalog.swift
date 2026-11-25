import Foundation

public enum SourceCategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case email
    case calendar
    case messaging
    case meetings
    case projects
    case crm
    case support
    case documents
    case local
    case developer

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .email: return "Email"
        case .calendar: return "Calendars"
        case .messaging: return "Messages"
        case .meetings: return "Meetings"
        case .projects: return "Tasks and projects"
        case .crm: return "CRM"
        case .support: return "Customer support"
        case .documents: return "Documents"
        case .local: return "Local sources"
        case .developer: return "Development"
        }
    }

    public var symbol: String {
        switch self {
        case .email: return "envelope"
        case .calendar: return "calendar"
        case .messaging: return "bubble.left.and.bubble.right"
        case .meetings: return "video"
        case .projects: return "checklist"
        case .crm: return "person.2"
        case .support: return "questionmark.bubble"
        case .documents: return "doc.text"
        case .local: return "externaldrive"
        case .developer: return "chevron.left.forwardslash.chevron.right"
        }
    }
}

public struct SourceProvider: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let category: SourceCategory
    public let summary: String
    public let connectionLabel: String
    public let isPriority: Bool
    public let accessNote: String?
    public let keywords: [String]

    public init(
        id: String,
        name: String,
        category: SourceCategory,
        summary: String,
        connectionLabel: String,
        isPriority: Bool = false,
        accessNote: String? = nil,
        keywords: [String] = []
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.summary = summary
        self.connectionLabel = connectionLabel
        self.isPriority = isPriority
        self.accessNote = accessNote
        self.keywords = keywords
    }
}

public struct SourceConnection: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let providerID: String
    public var label: String
    public var accountHint: String
    public let createdAt: Date

    // This is a planned source entry, not an authenticated connection or credential store.
    public init(
        id: UUID = UUID(),
        providerID: String,
        label: String,
        accountHint: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.providerID = providerID
        self.label = label
        self.accountHint = accountHint
        self.createdAt = createdAt
    }
}

public enum SourceCatalog {
    // All entries describe planned integrations. Presence here does not claim working access.
    public static let providers: [SourceProvider] = [
        source("outlook", "Outlook and Microsoft 365", .email,
               "Email threads, follow-up flags and commitments.", "account", priority: true,
               note: "Account authorization and organization permissions still need verification.",
               keywords: ["Microsoft", "M365", "Office 365", "Exchange", "Outlook.com", "Hotmail"]),
        source("gmail", "Gmail and Google Workspace", .email,
               "Email threads, requests and follow-up context.", "account", priority: true,
               note: "Account authorization is not implemented. Mapping stars to tasks requires a separate choice.",
               keywords: ["Google", "G Suite", "Google Mail", "personal email"]),
        source("icloud-mail", "iCloud Mail", .email,
               "Personal email and conversation context.", "account",
               note: "The supported access method and account requirements still need verification.",
               keywords: ["Apple", "me.com", "mac.com"]),
        source("fastmail", "Fastmail", .email,
               "Email conversations and follow-up requests.", "account",
               keywords: ["mail", "JMAP"]),
        source("yahoo-mail", "Yahoo Mail", .email,
               "Email conversations and outstanding requests.", "account",
               keywords: ["Yahoo", "mail"]),
        source("proton-mail", "Proton Mail", .email,
               "Private email conversations and follow-up context.", "account",
               note: "A supported access route, potentially through a local bridge, still needs verification.",
               keywords: ["Proton", "ProtonMail", "Bridge", "encrypted email"]),
        source("imap", "Other email via IMAP", .email,
               "Mail from an email provider selected by the user.", "account",
               note: "Provider authentication and flag behavior need individual verification.",
               keywords: ["generic email", "mail server", "custom domain"]),

        source("google-calendar", "Google Calendar", .calendar,
               "Upcoming events, attendees and preparation context.", "account",
               keywords: ["Google Workspace", "G Suite", "appointments"]),
        source("outlook-calendar", "Outlook Calendar", .calendar,
               "Work and personal events with their meeting context.", "account",
               keywords: ["Microsoft", "M365", "Office 365", "Exchange"]),
        source("apple-calendar", "Apple Calendar", .calendar,
               "Calendars available on the Mac.", "device",
               note: "Local calendar permissions and available calendar coverage need verification.",
               keywords: ["iCloud", "iCal", "macOS"]),

        source("slack", "Slack", .messaging,
               "Workspace conversations, requests and commitments.", "workspace", priority: true,
               note: "Workspace approval, channel access and history coverage need verification.",
               keywords: ["channels", "DM", "direct messages"]),
        source("teams", "Microsoft Teams", .messaging,
               "Work conversations, channels and meeting context.", "account",
               note: "Organization permissions and message access need verification.",
               keywords: ["Microsoft", "M365", "Office 365", "channels"]),
        source("google-chat", "Google Chat", .messaging,
               "Workspace conversations, spaces and follow-up requests.", "account",
               note: "Available personal and workspace message access needs verification.",
               keywords: ["Google Workspace", "G Suite", "spaces", "Hangouts"]),
        source("linkedin-messages", "LinkedIn messages", .messaging,
               "Professional conversations and relationship follow-ups.", "account",
               note: "A supported personal-message access route has not been established.",
               keywords: ["Linked In", "InMail", "professional network"]),
        source("whatsapp", "WhatsApp", .messaging,
               "Personal and group conversations selected for follow-up.", "account",
               note: "Personal chat access is unverified. Business messaging access is not equivalent.",
               keywords: ["Meta", "chat", "groups"]),
        source("apple-messages", "Apple Messages", .messaging,
               "Messages and related commitments on an Apple device.", "device",
               note: "A supported personal-message access method still needs verification.",
               keywords: ["iMessage", "SMS", "MMS", "text messages"]),
        source("telegram", "Telegram", .messaging,
               "Chats, groups and follow-up requests.", "account",
               note: "Personal-account access and conversation coverage need verification.",
               keywords: ["chat", "groups", "channels"]),
        source("signal", "Signal", .messaging,
               "Private conversations selected for task context.", "device",
               note: "A supported personal-message integration has not been established.",
               keywords: ["private messages", "encrypted chat"]),
        source("discord", "Discord", .messaging,
               "Server discussions and direct-message follow-ups.", "workspace",
               note: "Server permissions and personal-message coverage need verification.",
               keywords: ["server", "community", "channels", "DM"]),
        source("messenger", "Messenger", .messaging,
               "Personal conversations and requests to follow up.", "account",
               note: "Personal chat access is unverified. Business messaging tools may have different coverage.",
               keywords: ["Facebook", "Meta", "Facebook Messenger"]),

        source("taalk", "Taalk", .meetings,
               "Call and chat context, notes and agreed actions.", "account", priority: true,
               note: "Available conversations, transcript permissions and synchronization need verification.",
               keywords: ["calls", "transcripts", "chat"]),
        source("granola", "Granola", .meetings,
               "Meeting notes, decisions and action points.", "workspace", priority: true,
               note: "The app's supported export or connection route still needs verification.",
               keywords: ["notes", "transcripts", "calls"]),
        source("fireflies", "Fireflies", .meetings,
               "Meeting notes, transcripts and follow-up actions.", "account",
               keywords: ["Fireflies.ai", "recordings", "transcripts"]),
        source("otter", "Otter", .meetings,
               "Conversation transcripts and meeting notes.", "account",
               keywords: ["Otter.ai", "recordings", "transcription"]),
        source("zoom", "Zoom", .meetings,
               "Meeting context and available recordings or notes.", "account",
               note: "Recording and transcript availability depend on the selected account and permissions.",
               keywords: ["video calls", "recordings", "transcripts"]),
        source("google-meet", "Google Meet", .meetings,
               "Meeting context and available notes or transcripts.", "account",
               note: "Available meeting content and access requirements need verification.",
               keywords: ["Google Workspace", "video calls", "Hangouts"]),

        source("apple-reminders", "Apple Reminders", .projects,
               "Existing reminders, lists and due dates.", "device",
               keywords: ["iCloud", "Apple", "to-do", "tasks"]),
        source("todoist", "Todoist", .projects,
               "Existing tasks, projects and deadlines.", "account",
               keywords: ["Doist", "to-do", "tasks"]),
        source("things", "Things", .projects,
               "Personal tasks, projects and planned work.", "device",
               note: "A supported local integration or import route still needs verification.",
               keywords: ["Things 3", "Cultured Code", "to-do"]),
        source("omnifocus", "OmniFocus", .projects,
               "Actions, projects and deferred work.", "device",
               note: "The supported local integration or import route still needs verification.",
               keywords: ["Omni Group", "GTD", "to-do"]),
        source("ticktick", "TickTick", .projects,
               "Existing tasks, lists and scheduled follow-ups.", "account",
               keywords: ["to-do", "reminders", "tasks"]),
        source("microsoft-to-do", "Microsoft To Do", .projects,
               "Existing task lists and follow-up items.", "account",
               note: "Future availability and migration options need checking before implementation.",
               keywords: ["Microsoft Todo", "Microsoft To-Do", "Wunderlist", "M365"]),
        source("google-tasks", "Google Tasks", .projects,
               "Existing tasks, lists and due dates.", "account",
               keywords: ["Google Workspace", "G Suite", "to-do"]),
        source("microsoft-planner", "Microsoft Planner", .projects,
               "Assigned work, plans and team follow-ups.", "account",
               note: "Plan types, account permissions and available task coverage need verification.",
               keywords: ["Microsoft", "M365", "Office 365", "plans"]),
        source("notion", "Notion", .projects,
               "Tasks, project pages and related decisions.", "workspace",
               keywords: ["databases", "wiki", "documents"]),
        source("monday", "Monday.com", .projects,
               "Board items, updates and assigned work.", "workspace", priority: true,
               keywords: ["Monday", "boards", "work management", "CRM"]),
        source("asana", "Asana", .projects,
               "Assigned tasks, projects and conversation context.", "workspace",
               keywords: ["work management", "assignments"]),
        source("trello", "Trello", .projects,
               "Cards, boards and outstanding actions.", "workspace",
               keywords: ["Atlassian", "Kanban", "cards"]),
        source("clickup", "ClickUp", .projects,
               "Tasks, project updates and related documents.", "workspace",
               keywords: ["Click Up", "work management", "assignments"]),

        source("attio", "Attio", .crm,
               "Contact, company and deal follow-ups.", "workspace",
               keywords: ["sales", "relationships", "deals"]),
        source("hubspot", "HubSpot", .crm,
               "Contact records, deals and customer follow-ups.", "account",
               keywords: ["Hub Spot", "sales", "customers"]),
        source("salesforce", "Salesforce", .crm,
               "Account activity, opportunities and next actions.", "organization",
               keywords: ["SFDC", "sales", "opportunities"]),
        source("pipedrive", "Pipedrive", .crm,
               "Deals, activities and relationship follow-ups.", "account",
               keywords: ["Pipe Drive", "pipeline", "sales"]),

        source("zendesk", "Zendesk", .support,
               "Customer requests, tickets and promised follow-ups.", "workspace",
               keywords: ["help desk", "customer service", "tickets"]),
        source("intercom", "Intercom", .support,
               "Customer conversations and outstanding support actions.", "workspace",
               keywords: ["customer service", "support inbox", "tickets"]),
        source("freshdesk", "Freshdesk", .support,
               "Support tickets, customer replies and follow-up work.", "workspace",
               keywords: ["Freshworks", "help desk", "customer service"]),

        source("google-drive", "Google Drive", .documents,
               "Files, shared documents and related background.", "account",
               keywords: ["Google Workspace", "G Suite", "Docs", "Sheets", "Slides"]),
        source("dropbox", "Dropbox", .documents,
               "Selected synced files and shared-folder context.", "folder",
               note: "Use selected local synced folders first. Access is not connected yet.",
               keywords: ["files", "shared folders", "local sync"]),
        source("onedrive", "OneDrive", .documents,
               "Selected synced files and their task context.", "folder",
               note: "A selected local synced folder is the initial planned access route.",
               keywords: ["Microsoft", "One Drive", "M365", "local sync"]),
        source("sharepoint", "SharePoint", .documents,
               "Selected synced team documents and project context.", "folder",
               note: "Use selected local synced SharePoint folders first. Access is not connected yet.",
               keywords: ["Microsoft", "Share Point", "team sites", "OneDrive", "local sync"]),
        source("apple-notes", "Apple Notes", .documents,
               "Personal notes, checklists and project background.", "device",
               note: "A supported local access or import route still needs verification.",
               keywords: ["iCloud", "notes", "checklists", "macOS"]),
        source("onenote", "OneNote", .documents,
               "Notebooks, meeting notes and action lists.", "account",
               keywords: ["Microsoft", "One Note", "M365", "notebooks"]),
        source("box", "Box", .documents,
               "Shared files, project documents and related context.", "account",
               keywords: ["files", "shared folders", "documents"]),

        source("goldfish", "Goldfish", .local,
               "Local activity memory, observed conversations and commitments.", "device", priority: true,
               note: "The planned connection is local. Observed screen context is partial, not complete mailbox or calendar synchronization.",
               keywords: ["screen memory", "activity", "personal memory", "promises"]),
        source("local-folders", "Local folders", .local,
               "Files and notes in folders chosen on this Mac.", "folder",
               note: "Folder selection and permission handling are not implemented yet.",
               keywords: ["Finder", "files", "directory", "disk"]),
        source("obsidian", "Obsidian", .local,
               "Local notes, project context and linked action items.", "vault",
               keywords: ["Markdown", "notes", "vaults"]),

        source("github", "GitHub", .developer,
               "Issues, pull requests and requested reviews.", "account",
               keywords: ["repositories", "PR", "code review", "Git Hub"]),
        source("gitlab", "GitLab", .developer,
               "Issues, merge requests and development follow-ups.", "account",
               keywords: ["repositories", "MR", "code review", "Git Lab"]),
        source("linear", "Linear", .developer,
               "Issues, projects and engineering commitments.", "workspace",
               keywords: ["tickets", "engineering", "roadmap"]),
        source("jira", "Jira", .developer,
               "Assigned issues, project updates and delivery context.", "site",
               keywords: ["Atlassian", "tickets", "engineering", "sprints"])
    ]

    public static func provider(id: String) -> SourceProvider? {
        providers.first { $0.id == id }
    }

    public static func search(query: String, category: SourceCategory? = nil) -> [SourceProvider] {
        let terms = normalized(query).split(whereSeparator: { $0.isWhitespace }).map(String.init)
        return providers.filter { provider in
            if let category, provider.category != category { return false }
            let searchable = normalized(([
                provider.id, provider.name, provider.summary, provider.connectionLabel,
                provider.category.rawValue, provider.category.displayName
            ] + provider.keywords).joined(separator: " "))
            return terms.allSatisfy { searchable.contains($0) }
        }
    }

    private static func normalized(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }

    private static func source(
        _ id: String,
        _ name: String,
        _ category: SourceCategory,
        _ summary: String,
        _ connectionLabel: String,
        priority: Bool = false,
        note: String? = nil,
        keywords: [String] = []
    ) -> SourceProvider {
        SourceProvider(
            id: id, name: name, category: category, summary: summary,
            connectionLabel: connectionLabel, isPriority: priority,
            accessNote: note, keywords: keywords
        )
    }
}
