import AppKit
import Combine
import CryptoKit
import Foundation
import PrioritiesCore

enum Workspace: String, CaseIterable, Identifiable {
    case tasks, suggestions, waiting, archive, models, sources
    var id: String { rawValue }
    var title: String {
        switch self {
        case .tasks: return "My Tasks"
        case .suggestions: return "Suggestions"
        case .waiting: return "Owed to Me"
        case .archive: return "Archive"
        case .models: return "Local AI"
        case .sources: return "Sources"
        }
    }
    var icon: String {
        switch self {
        case .tasks: return "checklist"
        case .suggestions: return "sparkles"
        case .waiting: return "person.2"
        case .archive: return "archivebox"
        case .models: return "cpu"
        case .sources: return "tray.and.arrow.down"
        }
    }
    var subtitle: String {
        switch self {
        case .tasks: return "What you owe, in due-date order."
        case .suggestions: return "Review what deserves a place on your list."
        case .waiting: return "What other people owe you."
        case .archive: return "Completed, removed and unapproved items."
        case .models: return "Your models, running on this Mac."
        case .sources: return "Bring context into your task list."
        }
    }
}

struct AppSettings: Codable, Equatable {
    var endpoint = "http://127.0.0.1:11434"
    var selectedModel = ""
    var voiceInterpretationModel = ""
    var minimumBattery: Double = 50
    var processingPaused = false

    init() {}

    private enum CodingKeys: String, CodingKey {
        case endpoint, selectedModel, voiceInterpretationModel, minimumBattery, processingPaused
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        endpoint = try values.decodeIfPresent(String.self, forKey: .endpoint) ?? "http://127.0.0.1:11434"
        selectedModel = try values.decodeIfPresent(String.self, forKey: .selectedModel) ?? ""
        voiceInterpretationModel = try values.decodeIfPresent(String.self, forKey: .voiceInterpretationModel) ?? ""
        minimumBattery = try values.decodeIfPresent(Double.self, forKey: .minimumBattery) ?? 50
        processingPaused = try values.decodeIfPresent(Bool.self, forKey: .processingPaused) ?? false
    }
}

struct ProcessingJob: Identifiable, Codable {
    enum Kind: String, Codable { case conversation, voice }
    var id = UUID()
    var text: String
    var kind: Kind
    var createdAt = Date()
    var error: String?
}

struct PendingVoiceTask: Identifiable, Codable {
    var item: TaskItem
    var question: String
    var id: UUID { item.id }
}

struct WorkspaceSnapshot: Codable {
    var tasks: [TaskItem]
    var settings: AppSettings
    var jobs: [ProcessingJob]
    var pendingVoiceTasks: [PendingVoiceTask]
}

private enum WorkspaceValidationError: LocalizedError {
    case invalid(String)
    var errorDescription: String? {
        if case .invalid(let detail) = self { return detail }
        return nil
    }
}

private struct RuntimeResult {
    var models: [LocalModelInfo]?
    var message: String
    var deletedModel: String?
}

@MainActor
final class AppModel: ObservableObject {
    @Published var tasks: [TaskItem] = []
    @Published var workspace: Workspace = .tasks {
        didSet {
            if oldValue == .suggestions && workspace != .suggestions { finishReviewSession() }
            if workspace == .suggestions && oldValue != .suggestions { reviewSessionID = UUID() }
            selectedTaskID = nil
        }
    }
    @Published var selectedTaskID: UUID?
    @Published var showNewTask = false
    @Published var showImport = false
    @Published var showVoice = false
    @Published var editItem: TaskItem?
    @Published var snoozeItem: TaskItem?
    @Published var errorMessage: String?
    @Published var notice: String?
    @Published var settings: AppSettings {
        didSet {
            guard !applyingSnapshot else { return }
            let requested = settings
            // SwiftUI bindings write here. Revert until the complete workspace is saved.
            applyingSnapshot = true
            settings = oldValue
            applyingSnapshot = false
            var updated = snapshot
            updated.settings = requested
            commit(updated)
        }
    }
    @Published var models: [LocalModelInfo] = []
    @Published var runtimeMessage = "Connect to a local Ollama runtime to get started."
    @Published var runtimeBusy = false
    @Published var downloadProgress: Double?
    @Published var downloadMessage = ""
    @Published var jobs: [ProcessingJob] = []
    @Published var pendingVoiceTasks: [PendingVoiceTask] = []
    @Published var processingJobID: UUID?
    @Published var now = Date()
    @Published var applicationIsActive = true
    let power = PowerMonitor()
    let dataDirectory: URL
    private let store: LocalDocumentStore<WorkspaceSnapshot>
    private var timer: AnyCancellable?
    private var powerObserver: AnyCancellable?
    private var terminationObserver: AnyCancellable?
    private var activeObserver: AnyCancellable?
    private var inactiveObserver: AnyCancellable?
    private var processingTask: Task<Void, Never>?
    private var downloadingTask: Task<Void, Never>?
    private var runtimeTask: Task<RuntimeResult, Error>?
    private var runtimeOperationID: UUID?
    private var runtimeRequiresPower = false
    private var processingRunID: UUID?
    private var reviewSessionID = UUID()
    private var storageHealthy = true
    private var applyingSnapshot = false

    init() {
        let override = ProcessInfo.processInfo.environment["PRIORITIES_DATA_DIRECTORY"]
        dataDirectory = override.map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Priorities", isDirectory: true)
        store = LocalDocumentStore(directory: dataDirectory)
        settings = AppSettings()
        do {
            if let saved = try store.load() {
                try Self.validate(saved)
                apply(saved)
            }
        } catch {
            storageHealthy = false
            errorMessage = "Your local data could not be opened. Nothing will be overwritten. \(error.localizedDescription)"
        }
        if ProcessInfo.processInfo.arguments.contains("--demo"), tasks.isEmpty, storageHealthy {
            addSampleTasks()
        }
        timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect().sink { [weak self] date in
            self?.tick(date)
        }
        powerObserver = power.objectWillChange.sink { [weak self] in
            self?.objectWillChange.send()
            Task { @MainActor in self?.checkProcessingPower() }
        }
        terminationObserver = NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification).sink { [weak self] _ in
            self?.finishReviewSession()
            self?.interruptProcessing()
            self?.runtimeTask?.cancel()
            self?.downloadingTask?.cancel()
        }
        activeObserver = NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification).sink { [weak self] _ in
            self?.applicationIsActive = true
            self?.power.refresh()
        }
        inactiveObserver = NotificationCenter.default.publisher(for: NSApplication.willResignActiveNotification).sink { [weak self] _ in
            self?.applicationIsActive = false
        }
        tick(Date())
    }

    var visibleTasks: [TaskItem] {
        let filtered = tasks.filter { item in
            switch workspace {
            case .tasks: return item.state == .active && item.direction == .mine
            case .waiting: return item.state == .active && item.direction == .owedToMe
            case .suggestions: return item.state == .suggested
            case .archive: return item.state == .archived
            default: return false
            }
        }
        if workspace == .archive {
            return filtered.sorted { ($0.archivedAt ?? $0.createdAt) > ($1.archivedAt ?? $1.createdAt) }
        }
        return TaskEngine.sorted(filtered)
    }

    var selectedTask: TaskItem? { tasks.first { $0.id == selectedTaskID } }
    var queuedCount: Int { jobs.count }
    var canProcess: Bool { power.canRun(minimumBattery: settings.minimumBattery) }
    var powerExplanation: String {
        if power.isPluggedIn { return "Plugged in. Local AI is allowed to run." }
        if let percent = power.batteryPercent {
            return canProcess
                ? "Battery \(Int(percent))%. Local AI can run above your \(Int(settings.minimumBattery))% minimum."
                : "Paused for battery: \(Int(percent))%. Plug in or charge to \(Int(settings.minimumBattery))%."
        }
        return "Waiting for reliable power information. Local AI is paused."
    }
    var processingStatus: String {
        if !storageHealthy { return "Local storage needs attention" }
        if settings.processingPaused { return "Local processing paused" }
        if !canProcess { return "AI paused for battery" }
        if processingJobID != nil { return "Processing on this Mac" }
        if runtimeBusy { return "Updating local model" }
        if settings.selectedModel.isEmpty && settings.voiceInterpretationModel.isEmpty { return "Choose a local model" }
        if jobs.contains(where: { $0.error != nil }) { return "Queued work needs attention" }
        if !jobs.isEmpty && !jobs.contains(where: { !modelName(for: $0.kind).isEmpty }) { return "Choose a model for queued work" }
        return jobs.isEmpty ? "Local AI ready" : "\(jobs.count) queued"
    }

    func modelName(for kind: ProcessingJob.Kind) -> String {
        if kind == .voice, !settings.voiceInterpretationModel.isEmpty {
            return settings.voiceInterpretationModel
        }
        return settings.selectedModel
    }

    func count(_ destination: Workspace) -> Int {
        tasks.filter { item in
            switch destination {
            case .tasks: return item.state == .active && item.direction == .mine && !item.isCompleted
            case .waiting: return item.state == .active && item.direction == .owedToMe && !item.isCompleted
            case .suggestions: return item.state == .suggested
            case .archive: return item.state == .archived
            default: return false
            }
        }.count
    }

    func saveTask(_ item: TaskItem) {
        guard storageHealthy else { return }
        var updated = tasks
        if let index = updated.firstIndex(where: { $0.id == item.id }) { updated[index] = item }
        else { updated.append(item) }
        if persistTasks(updated) {
            selectedTaskID = item.id
            notice = "Task saved"
        }
    }

    @discardableResult
    private func change(_ id: UUID, _ mutation: (inout TaskItem) -> Void) -> Bool {
        guard storageHealthy, let index = tasks.firstIndex(where: { $0.id == id }) else { return false }
        var updated = tasks
        mutation(&updated[index])
        guard updated != tasks else { return false }
        return persistTasks(updated)
    }

    func complete(_ item: TaskItem) {
        change(item.id) { TaskEngine.complete(&$0, now: Date()) }
    }
    func undoComplete(_ item: TaskItem) {
        change(item.id) { TaskEngine.undoCompletion(&$0, now: Date()) }
    }
    func approve(_ item: TaskItem) {
        if change(item.id, { TaskEngine.approve(&$0, now: Date()) }) {
            notice = "Added to \(item.direction == .mine ? "My Tasks" : "Owed to Me")"
        }
    }
    func archive(_ item: TaskItem) {
        change(item.id) { TaskEngine.archive(&$0, reason: item.state == .suggested ? .dismissed : .removed, now: Date()) }
    }
    func restore(_ item: TaskItem) {
        change(item.id) { TaskEngine.restore(&$0, now: Date()) }
    }
    func snooze(_ item: TaskItem, until date: Date) {
        if change(item.id, { TaskEngine.snooze(&$0, until: date, now: Date()) }) {
            notice = "Due date moved to \(date.formatted(date: .abbreviated, time: .shortened))"
        }
    }

    func reviewVisible(_ ids: Set<UUID>) {
        guard workspace == .suggestions, applicationIsActive, storageHealthy else { return }
        var updated = tasks
        for index in updated.indices where ids.contains(updated[index].id) {
            TaskEngine.markReviewed(&updated[index], sessionID: reviewSessionID, now: now)
        }
        if updated != tasks { persistTasks(updated) }
    }

    private func finishReviewSession() {
        guard storageHealthy else { return }
        var updated = tasks
        TaskEngine.maintenance(&updated, now: Date(), endingReviewSessionID: reviewSessionID)
        if updated != tasks { persistTasks(updated) }
    }

    private func tick(_ date: Date) {
        now = date
        guard storageHealthy else { return }
        var updated = tasks
        TaskEngine.maintenance(&updated, now: date)
        if updated != tasks { persistTasks(updated) }
        checkProcessingPower()
        startQueueIfPossible()
    }

    func enqueue(_ text: String, kind: ProcessingJob.Kind) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, storageHealthy else { return }
        guard trimmed.count <= 12_000 else {
            errorMessage = "Please use a conversation of up to 12,000 characters for this first build."
            return
        }
        var updated = snapshot
        updated.jobs.append(ProcessingJob(text: trimmed, kind: kind))
        if commit(updated) {
            notice = canProcess && !modelName(for: kind).isEmpty && !settings.processingPaused ? "Added to the local processing queue" : "Saved locally. Processing will wait until a model, power and processing are available."
            startQueueIfPossible()
        }
    }

    func retryJob(_ id: UUID) {
        var updated = snapshot
        if let index = updated.jobs.firstIndex(where: { $0.id == id }) {
            updated.jobs[index].error = nil
            if commit(updated) { startQueueIfPossible() }
        }
    }
    func removeJob(_ id: UUID) {
        var updated = snapshot
        updated.jobs.removeAll { $0.id == id }
        if commit(updated), processingJobID == id { interruptProcessing() }
    }

    func pauseProcessing() {
        settings.processingPaused = true
        if settings.processingPaused, storageHealthy { notice = "Local processing paused. Queued work is saved." }
    }

    func resumeProcessing() {
        settings.processingPaused = false
        if !settings.processingPaused, storageHealthy {
            notice = canProcess ? "Local processing resumed" : "Processing will resume when power allows."
            startQueueIfPossible()
        }
    }

    private func checkProcessingPower() {
        if !canProcess {
            interruptProcessing()
            if runtimeRequiresPower { runtimeTask?.cancel() }
        }
    }

    private func interruptProcessing() {
        processingRunID = nil
        processingTask?.cancel()
        processingJobID = nil
    }

    private func startQueueIfPossible() {
        guard storageHealthy, canProcess, !settings.processingPaused,
              !runtimeBusy, processingTask == nil,
              let job = jobs.first(where: { $0.error == nil && !modelName(for: $0.kind).isEmpty }) else { return }
        let runID = UUID()
        let selectedModel = modelName(for: job.kind)
        let endpoint = settings.endpoint
        processingRunID = runID
        processingJobID = job.id
        processingTask = Task { [weak self] in
            guard let self else { return }
            defer {
                self.processingTask = nil
                self.processingJobID = nil
                self.processingRunID = nil
            }
            do {
                let client = try LocalModelClient(endpoint: endpoint)
                let extracted = try await client.extractTasks(text: job.text, model: selectedModel, now: job.createdAt, timeZone: .current)
                try Task.checkCancellation()
                guard self.processingRunID == runID, self.canProcess, !self.settings.processingPaused,
                      self.settings.endpoint == endpoint, self.modelName(for: job.kind) == selectedModel,
                      self.jobs.contains(where: { $0.id == job.id }) else { return }
                var updated = self.snapshot
                let processedAt = Date()
                for (index, draft) in extracted.enumerated() {
                    let id = Self.resultID(jobID: job.id, index: index)
                    guard !updated.tasks.contains(where: { $0.id == id }), !updated.pendingVoiceTasks.contains(where: { $0.id == id }) else { continue }
                    let isVoice = job.kind == .voice
                    let uncertainty = draft.uncertainty?.trimmingCharacters(in: .whitespacesAndNewlines)
                    let needsClarification = isVoice && ((uncertainty?.isEmpty == false) || draft.dueDate == nil)
                    let item = TaskItem(
                        id: id, title: draft.title, dueDate: draft.dueDate ?? Self.tomorrowMorning(),
                        person: draft.person,
                        notes: uncertainty.map { "Needs review: \($0)" } ?? "",
                        estimatedMinutes: draft.estimatedMinutes, direction: draft.direction,
                        state: isVoice ? .active : .suggested,
                        origin: isVoice ? .voice : .imported,
                        sourceText: job.text, createdAt: isVoice ? job.createdAt : processedAt, promisedDueDate: draft.dueDate,
                        history: [TaskChange(description: "Created using local model \(selectedModel). Evidence: \(draft.supportingQuote)")]
                    )
                    if needsClarification {
                        updated.pendingVoiceTasks.append(PendingVoiceTask(item: item, question: uncertainty?.isEmpty == false ? uncertainty! : "What due date would you like?"))
                    } else { updated.tasks.append(item) }
                }
                updated.jobs.removeAll { $0.id == job.id }
                // Results and removal from the source queue share one atomic replacement.
                guard self.commit(updated) else { return }
                self.notice = extracted.isEmpty ? "No clear tasks found in this conversation" : "Processed locally: \(extracted.count) task\(extracted.count == 1 ? "" : "s")"
                if job.kind == .conversation { self.workspace = .suggestions }
            } catch {
                guard self.processingRunID == runID else { return }
                if !Task.isCancelled, let index = self.jobs.firstIndex(where: { $0.id == job.id }) {
                    var updated = self.snapshot
                    updated.jobs[index].error = error.localizedDescription
                    self.commit(updated)
                }
            }
        }
    }

    func resolveVoiceDraft(_ edited: TaskItem) {
        var updated = snapshot
        guard updated.pendingVoiceTasks.contains(where: { $0.id == edited.id }) else { return }
        updated.tasks.removeAll { $0.id == edited.id }
        updated.tasks.append(edited)
        updated.pendingVoiceTasks.removeAll { $0.id == edited.id }
        if commit(updated) { notice = "Task saved"; selectedTaskID = edited.id }
    }
    func discardVoiceDraft(_ id: UUID) {
        var updated = snapshot
        updated.pendingVoiceTasks.removeAll { $0.id == id }
        commit(updated)
    }

    func refreshModels() async {
        await performRuntimeOperation { client, _, _ in
            let models = try await client.listModels()
            return RuntimeResult(models: models, message: models.isEmpty
                ? "Connected. Download a local model to begin."
                : "Connected to Ollama on this Mac. \(models.count) local model\(models.count == 1 ? "" : "s") available.")
        }
    }
    func selectModel(_ name: String) {
        settings.selectedModel = name
        if storageHealthy, settings.selectedModel == name { notice = "Selected \(name)." }
    }
    func selectVoiceInterpretationModel(_ name: String) {
        settings.voiceInterpretationModel = name
        if storageHealthy, settings.voiceInterpretationModel == name {
            notice = name.isEmpty ? "Voice interpretation will use the task model." : "Voice interpretation will use \(name)."
        }
    }
    func loadSelectedModel() async {
        await performRuntimeOperation(requiresPower: true) { client, name, _ in
            try await client.loadModel(name)
            return RuntimeResult(models: try await client.listModels(), message: "Selected model loaded.")
        }
    }
    func unloadSelectedModel() async {
        guard !runtimeBusy else { return }
        pauseProcessing()
        guard settings.processingPaused, storageHealthy else { return }
        await performRuntimeOperation { client, name, _ in
            try await client.unloadModel(name)
            return RuntimeResult(models: try await client.listModels(), message: "Selected model unloaded. Resume processing when you want to use it again.")
        }
    }
    func removeModel(_ name: String) async {
        await performRuntimeOperation { client, _, _ in
            try await client.deleteModel(name)
            // Deletion success must be handled even if the subsequent inventory refresh fails.
            return RuntimeResult(models: try? await client.listModels(), message: "Model removed from Ollama on this Mac.", deletedModel: name)
        }
    }

    @discardableResult
    private func performRuntimeOperation(
        requiresPower: Bool = false,
        operation: @escaping @MainActor (LocalModelClient, String, UUID) async throws -> RuntimeResult
    ) async -> Bool {
        guard storageHealthy, !runtimeBusy else { return false }
        guard !requiresPower || canProcess else { runtimeMessage = powerExplanation; return false }
        let id = UUID()
        let endpoint = settings.endpoint
        let selectedModel = settings.selectedModel
        let voiceInterpretationModel = settings.voiceInterpretationModel
        let previousProcessing = processingTask
        runtimeBusy = true
        runtimeOperationID = id
        runtimeRequiresPower = requiresPower
        interruptProcessing()
        let operationTask = Task { @MainActor in
            // Wait for the cancelled request to settle before changing runtime state.
            if let previousProcessing { await previousProcessing.value }
            try Task.checkCancellation()
            let client = try LocalModelClient(endpoint: endpoint)
            let result = try await operation(client, selectedModel, id)
            try Task.checkCancellation()
            return result
        }
        runtimeTask = operationTask
        defer {
            if runtimeOperationID == id {
                runtimeTask = nil
                runtimeOperationID = nil
                runtimeRequiresPower = false
                runtimeBusy = false
            }
        }
        do {
            let result = try await withTaskCancellationHandler {
                try await operationTask.value
            } onCancel: {
                operationTask.cancel()
            }
            guard runtimeOperationID == id, settings.endpoint == endpoint,
                  settings.selectedModel == selectedModel,
                  settings.voiceInterpretationModel == voiceInterpretationModel, !operationTask.isCancelled,
                  !requiresPower || canProcess else { return false }
            if let inventory = result.models { models = inventory }
            if let deleted = result.deletedModel {
                models.removeAll { $0.name == deleted }
                if settings.selectedModel == deleted || settings.voiceInterpretationModel == deleted {
                    var updated = snapshot
                    if updated.settings.selectedModel == deleted { updated.settings.selectedModel = "" }
                    if updated.settings.voiceInterpretationModel == deleted { updated.settings.voiceInterpretationModel = "" }
                    guard commit(updated) else {
                        runtimeMessage = "Model removed, but local settings could not be saved. Resolve the storage error before continuing."
                        return false
                    }
                }
            }
            runtimeMessage = result.message
            return true
        } catch {
            guard runtimeOperationID == id, settings.endpoint == endpoint,
                  settings.selectedModel == selectedModel,
                  settings.voiceInterpretationModel == voiceInterpretationModel else { return false }
            if operationTask.isCancelled || error is CancellationError {
                runtimeMessage = requiresPower && !canProcess ? powerExplanation : "Local model operation cancelled."
            } else {
                runtimeMessage = error.localizedDescription
            }
            return false
        }
    }

    func downloadModel(_ name: String) async {
        guard downloadingTask == nil, !runtimeBusy, storageHealthy else { return }
        downloadProgress = 0
        downloadMessage = "Preparing download"
        let endpoint = settings.endpoint
        downloadingTask = Task { [weak self] in
            guard let self else { return }
            let succeeded = await self.performRuntimeOperation { [weak self] client, _, operationID in
                try await client.downloadModel(name) { [weak self] progress, message in
                    Task { @MainActor [weak self] in
                        guard let self, self.runtimeOperationID == operationID,
                              self.settings.endpoint == endpoint else { return }
                        self.downloadProgress = progress
                        self.downloadMessage = message
                    }
                }
                return RuntimeResult(models: try await client.listModels(), message: "Download complete.")
            }
            if self.settings.endpoint == endpoint {
                self.downloadMessage = succeeded ? "Download complete" :
                    Task.isCancelled ? "Download cancelled. Pull the same model again to resume." : self.runtimeMessage
            }
            self.downloadProgress = nil
            self.downloadingTask = nil
        }
    }
    func cancelDownload() { downloadingTask?.cancel() }
    func testSelectedModel() async {
        await performRuntimeOperation(requiresPower: true) { client, name, _ in
            let started = Date()
            let result = try await client.extractTasks(
                text: "This is a synthetic test. I promised Anna: I will send the proposal tomorrow. It should take me 30 minutes.",
                model: name
            )
            return RuntimeResult(models: nil, message: "Local test: \(result.count) task\(result.count == 1 ? "" : "s") extracted in \(String(format: "%.1f", Date().timeIntervalSince(started))) seconds. This checks the connection, not overall model accuracy.")
        }
    }

    func addSampleTasks() {
        guard tasks.isEmpty, storageHealthy else { return }
        let now = Date()
        let samples = [
            TaskItem(title: "Send the revised proposal", dueDate: now.addingTimeInterval(-7200), person: "Anna", notes: "Synthetic example. Open a task to see its context and history.", estimatedMinutes: 30, promisedDueDate: now.addingTimeInterval(-7200)),
            TaskItem(title: "Review the launch checklist", dueDate: now.addingTimeInterval(3600), person: "Sam", notes: "Synthetic example.", estimatedMinutes: 20),
            TaskItem(title: "Book a planning session", dueDate: Self.tomorrowMorning(), estimatedMinutes: 10),
            TaskItem(title: "Receive the updated figures", dueDate: now.addingTimeInterval(7200), person: "Alex", notes: "Synthetic example. Alex owes you the figures.", direction: .owedToMe),
            TaskItem(title: "Share feedback on the first draft", dueDate: Self.tomorrowMorning(), person: "Robin", estimatedMinutes: 15, state: .suggested, origin: .imported, sourceText: "Synthetic conversation: Robin asked you to share feedback on the first draft tomorrow.")
        ]
        persistTasks(samples)
    }

    static func tomorrowMorning() -> Date {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        return Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow)!
    }
    static func nextWorkingMorning() -> Date {
        var day = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        while Calendar.current.isDateInWeekend(day) { day = Calendar.current.date(byAdding: .day, value: 1, to: day)! }
        return Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: day)!
    }

    @discardableResult
    private func persistTasks(_ items: [TaskItem]) -> Bool {
        var updated = snapshot
        updated.tasks = items
        return commit(updated)
    }

    private var snapshot: WorkspaceSnapshot {
        WorkspaceSnapshot(tasks: tasks, settings: settings, jobs: jobs, pendingVoiceTasks: pendingVoiceTasks)
    }

    @discardableResult
    private func commit(_ updated: WorkspaceSnapshot) -> Bool {
        guard storageHealthy else { return false }
        do { try Self.validate(updated) }
        catch {
            errorMessage = "Could not save these changes: \(error.localizedDescription)"
            return false
        }
        do {
            try store.save(updated)
            let oldSettings = settings
            apply(updated)
            settingsDidChange(from: oldSettings)
            return true
        } catch {
            // Prevent any later write from replacing a state that needs recovery.
            storageHealthy = false
            interruptProcessing()
            runtimeTask?.cancel()
            downloadingTask?.cancel()
            errorMessage = "Could not save the local workspace. Resolve the storage problem and reopen the app before making further changes. \(error.localizedDescription)"
            return false
        }
    }

    private func apply(_ saved: WorkspaceSnapshot) {
        applyingSnapshot = true
        tasks = saved.tasks
        settings = saved.settings
        jobs = saved.jobs
        pendingVoiceTasks = saved.pendingVoiceTasks
        applyingSnapshot = false
    }

    private func settingsDidChange(from old: AppSettings) {
        if old.endpoint != settings.endpoint || old.selectedModel != settings.selectedModel
            || old.voiceInterpretationModel != settings.voiceInterpretationModel {
            interruptProcessing()
            runtimeTask?.cancel()
            downloadingTask?.cancel()
            if old.endpoint != settings.endpoint {
                models = []
                runtimeMessage = "Connection changed. Connect to refresh the local model library."
                downloadMessage = ""
            }
        }
        if settings.processingPaused && !old.processingPaused {
            interruptProcessing()
            if runtimeRequiresPower { runtimeTask?.cancel() }
        }
        checkProcessingPower()
    }

    private static func validate(_ saved: WorkspaceSnapshot) throws {
        guard saved.settings.minimumBattery.isFinite, (0...100).contains(saved.settings.minimumBattery) else {
            throw WorkspaceValidationError.invalid("The saved battery threshold is invalid.")
        }
        _ = try LocalModelClient(endpoint: saved.settings.endpoint)
        guard Set(saved.jobs.map(\.id)).count == saved.jobs.count,
              Set(saved.tasks.map(\.id)).count == saved.tasks.count,
              Set(saved.pendingVoiceTasks.map(\.id)).count == saved.pendingVoiceTasks.count,
              Set(saved.tasks.map(\.id)).isDisjoint(with: Set(saved.pendingVoiceTasks.map(\.id))) else {
            throw WorkspaceValidationError.invalid("The saved workspace contains duplicate identifiers.")
        }
        for job in saved.jobs {
            guard !job.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  job.text.count <= 12_000, job.createdAt.timeIntervalSinceReferenceDate.isFinite else {
                throw WorkspaceValidationError.invalid("The saved processing queue contains invalid source text or dates.")
            }
        }
        for item in saved.tasks + saved.pendingVoiceTasks.map(\.item) {
            let dates = [item.createdAt, item.dueDate]
                + [item.promisedDueDate, item.completedAt, item.archivedAt, item.suggestionCycleStartedAt].compactMap { $0 }
                + item.history.map(\.date)
            guard !item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  dates.allSatisfy({ $0.timeIntervalSinceReferenceDate.isFinite }),
                  item.estimatedMinutes.map({ $0 >= 0 }) ?? true else {
                throw WorkspaceValidationError.invalid("The saved workspace contains invalid task details.")
            }
        }
    }
    private static func resultID(jobID: UUID, index: Int) -> UUID {
        let bytes = Array(SHA256.hash(data: Data("\(jobID.uuidString):\(index)".utf8)).prefix(16))
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7], bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }
}
