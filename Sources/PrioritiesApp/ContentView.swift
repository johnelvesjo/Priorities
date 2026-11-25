import SwiftUI
import PrioritiesCore

struct ContentView: View {
    @ObservedObject var model: AppModel
    @State private var voiceDraft: PendingVoiceTask?

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 250)
        } detail: {
            VStack(spacing: 0) {
                header
                Divider()
                if let error = model.errorMessage {
                    HStack(alignment: .top) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        Text(error).font(.callout).textSelection(.enabled)
                        Spacer()
                        Button("Dismiss") { model.errorMessage = nil }
                    }
                    .padding(12).background(Color.orange.opacity(0.08))
                }
                if let draft = model.pendingVoiceTasks.first, model.workspace != .models {
                    HStack {
                        Image(systemName: "mic.badge.plus")
                        Text("One detail needs clarification: \(draft.question)")
                            .font(.callout).lineLimit(2)
                        Spacer()
                        Button("Review") { voiceDraft = draft }
                    }.padding(12).background(Color.accentColor.opacity(0.07))
                }
                Group {
                    switch model.workspace {
                    case .models: ModelManagerView(model: model)
                    case .sources: SourcesView(model: model)
                    default: tasksWorkspace
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
                Divider()
                statusBar
            }
            .background(Color(nsColor: .textBackgroundColor))
        }
        .sheet(isPresented: $model.showNewTask) {
            TaskEditor(initial: nil, direction: model.workspace == .waiting ? .owedToMe : .mine) { model.saveTask($0) }
        }
        .sheet(item: $model.editItem) { item in
            TaskEditor(initial: item, direction: item.direction) { model.saveTask($0) }
        }
        .sheet(item: $model.snoozeItem) { item in
            SnoozeDateView(item: item) { model.snooze(item, until: $0) }
        }
        .sheet(isPresented: $model.showImport) { ImportConversationView(model: model) }
        .sheet(isPresented: $model.showVoice) { VoiceEntryView(model: model) }
        .sheet(item: $voiceDraft) { draft in
            TaskEditor(initial: draft.item, direction: draft.item.direction, clarification: draft.question) {
                model.resolveVoiceDraft($0)
            }
        }
        .onChange(of: model.pendingVoiceTasks.count) { _, _ in
            if !model.showVoice && voiceDraft == nil { voiceDraft = model.pendingVoiceTasks.first }
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.square.fill")
                    .font(.system(size: 28)).foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Priorities").font(.title3.weight(.semibold))
                    Text("A clearer next step").font(.caption).foregroundStyle(.secondary)
                }
            }.padding(.top, 14).padding(.horizontal, 16)
            VStack(spacing: 4) {
                ForEach([Workspace.tasks, .suggestions, .waiting, .archive]) { destination in
                    navigationButton(destination)
                }
            }.padding(.horizontal, 10)
            Spacer()
            VStack(spacing: 4) {
                navigationButton(.sources)
                navigationButton(.models)
            }.padding(.horizontal, 10)
            HStack(spacing: 6) {
                Image(systemName: "lock.shield")
                Text("Stored on this Mac")
            }.font(.caption).foregroundStyle(.secondary).padding(.horizontal, 18).padding(.bottom, 16)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func navigationButton(_ destination: Workspace) -> some View {
        Button {
            model.workspace = destination
        } label: {
            HStack(spacing: 10) {
                Image(systemName: destination.icon).frame(width: 20)
                Text(destination.title)
                Spacer(minLength: 4)
                let count = model.count(destination)
                if count > 0 {
                    Text("\(count)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 10)
            .foregroundStyle(model.workspace == destination ? Color.accentColor : Color.primary)
            .background(model.workspace == destination ? Color.accentColor.opacity(0.1) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }.buttonStyle(.plain)
        .accessibilityIdentifier("nav.\(destination.rawValue)")
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.workspace.title).font(.system(size: 26, weight: .semibold))
                Text(model.workspace.subtitle).font(.callout).foregroundStyle(.secondary)
            }
            Spacer(minLength: 20)
            Button { model.showImport = true } label: { Image(systemName: "text.badge.plus") }
                .help("Import a conversation for local analysis")
                .accessibilityLabel("Import Conversation")
            Button { model.showVoice = true } label: { Image(systemName: "mic") }
                .help("Add a task by voice")
                .accessibilityLabel("Add by Voice")
            Button { model.showNewTask = true } label: { Label("Add Task", systemImage: "plus") }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("addTask")
        }.padding(.horizontal, 24).padding(.vertical, 22)
    }

    private var tasksWorkspace: some View {
        HSplitView {
            TaskListView(model: model).frame(minWidth: 410)
            if let item = model.selectedTask {
                TaskDetailView(model: model, item: item)
                    .frame(minWidth: 300, idealWidth: 350, maxWidth: 440)
            }
        }
    }

    private var statusBar: some View {
        HStack(spacing: 8) {
            if model.processingJobID != nil { ProgressView().controlSize(.small) }
            else { Image(systemName: model.canProcess ? "circle.fill" : "pause.circle").foregroundStyle(model.canProcess ? .green : .orange).font(.system(size: 8)) }
            Text(model.processingStatus)
            if model.queuedCount > 0 {
                Text("\(model.queuedCount) queued").foregroundStyle(.secondary)
            }
            Spacer()
            if let notice = model.notice { Text(notice).lineLimit(1).foregroundStyle(.secondary) }
        }.font(.caption).padding(.horizontal, 18).padding(.vertical, 10)
    }
}

private struct RowFramesKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

struct TaskListView: View {
    @ObservedObject var model: AppModel
    @State private var viewportSize = CGSize.zero
    @State private var rowFrames: [UUID: CGRect] = [:]

    var body: some View {
        VStack(spacing: 0) {
            if model.workspace == .suggestions {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "eye")
                    Text("Visible suggestions count once per visit. After two visits, unapproved suggestions archive when you leave this list. Suggestions also expire after a week.")
                        .fixedSize(horizontal: false, vertical: true)
                }.font(.caption).foregroundStyle(.secondary).padding(16)
                Divider()
            }
            if model.visibleTasks.isEmpty {
                emptyState
            } else {
                HStack {
                    Text(model.workspace == .archive ? "MOST RECENTLY ARCHIVED" : "DUE DATE")
                    Spacer()
                    Text("\(model.visibleTasks.count) items")
                }.font(.caption2.weight(.medium)).foregroundStyle(.secondary)
                    .padding(.horizontal, 20).padding(.vertical, 12)
                GeometryReader { viewport in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(model.visibleTasks) { item in
                                TaskRow(model: model, item: item)
                                    .background(GeometryReader { geometry in
                                        Color.clear.preference(key: RowFramesKey.self, value: [item.id: geometry.frame(in: .named("taskViewport"))])
                                    })
                                Divider().padding(.leading, 54)
                            }
                        }.padding(.bottom, 20)
                    }
                    .coordinateSpace(name: "taskViewport")
                    .onAppear { viewportSize = viewport.size }
                    .onChange(of: viewport.size) { _, size in viewportSize = size; reportVisible() }
                    .onPreferenceChange(RowFramesKey.self) { frames in rowFrames = frames; reportVisible() }
                    .onChange(of: model.applicationIsActive) { _, _ in reportVisible() }
                }
            }
        }
    }

    private func reportVisible() {
        guard model.workspace == .suggestions, viewportSize.height > 0 else { return }
        let viewport = CGRect(origin: .zero, size: viewportSize)
        let ids = Set(rowFrames.compactMap { id, frame -> UUID? in
            let intersection = frame.intersection(viewport)
            return !intersection.isNull && intersection.height >= min(frame.height / 2, 30) ? id : nil
        })
        model.reviewVisible(ids)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: model.workspace.icon).font(.system(size: 40, weight: .light)).foregroundStyle(.secondary)
            Text(emptyTitle).font(.title2.weight(.medium))
            Text(emptyDescription).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 360)
            if model.workspace == .suggestions {
                Button("Import a Conversation") { model.showImport = true }.buttonStyle(.bordered)
            } else if model.workspace != .archive {
                Button("Add Your First Task") { model.showNewTask = true }.buttonStyle(.borderedProminent)
                if model.tasks.isEmpty {
                    Button("Try synthetic sample tasks") { model.addSampleTasks() }.buttonStyle(.link).font(.caption)
                }
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(32)
    }
    private var emptyTitle: String {
        switch model.workspace {
        case .suggestions: return "Room for the next good suggestion"
        case .waiting: return "Nothing waiting on someone else"
        case .archive: return "Your history will appear here"
        default: return "Start with what matters"
        }
    }
    private var emptyDescription: String {
        switch model.workspace {
        case .suggestions: return "Import a conversation and let your local model look for actions. You choose what becomes a task."
        case .waiting: return "Track promises, replies and deliverables other people owe you."
        case .archive: return "Completed tasks appear here one minute after you mark them Done."
        default: return "Add a task, choose when it is due, and keep everything in one visible list."
        }
    }
}

struct TaskRow: View {
    @ObservedObject var model: AppModel
    let item: TaskItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            leadingControl
                .frame(width: 22).padding(.top, 2)
            VStack(alignment: .leading, spacing: 7) {
                Text(item.title).font(.system(size: 14, weight: .medium))
                    .strikethrough(item.isCompleted)
                    .foregroundStyle(item.isOverdue(at: model.now) ? Color.red : Color.primary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    if !item.person.isEmpty { Label(item.person, systemImage: "person").lineLimit(1) }
                    if let minutes = item.estimatedMinutes { Text("\(minutes) min") }
                    if item.state == .suggested { Text("\(item.reviewSessionIDs.count)/2 reviews") }
                    if item.state == .archived { Text(item.archiveReason?.displayName ?? "Archived") }
                }.font(.caption).foregroundStyle(.secondary)
                if let completed = item.completedAt, item.state == .active {
                    Text("Done. Archives in \(max(0, 60 - Int(model.now.timeIntervalSince(completed))))s")
                        .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                }
            }
            Spacer(minLength: 12)
            VStack(alignment: .trailing, spacing: 7) {
                Text(item.dueDate.formatted(.dateTime.month(.abbreviated).day()))
                Text(item.dueDate.formatted(date: .omitted, time: .shortened))
            }.font(.caption).monospacedDigit()
                .foregroundStyle(item.isOverdue(at: model.now) ? Color.red : Color.primary)
            if item.state == .active && !item.isCompleted {
                SnoozeMenu(model: model, item: item).labelStyle(.iconOnly)
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(model.selectedTaskID == item.id ? Color.accentColor.opacity(0.07) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { model.selectedTaskID = item.id }
        .contextMenu {
            if item.state == .archived { Button("Restore") { model.restore(item) } }
            else {
                Button("Edit") { model.editItem = item }
                if item.state == .suggested { Button("Approve") { model.approve(item) } }
                else if item.isCompleted { Button("Undo Done") { model.undoComplete(item) } }
                else { Button("Mark Done") { model.complete(item) } }
                Button(item.state == .suggested ? "Dismiss" : "Remove") { model.archive(item) }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("task.\(item.id.uuidString)")
    }

    @ViewBuilder private var leadingControl: some View {
        if item.state == .suggested {
            Button { model.approve(item) } label: { Image(systemName: "plus.circle").font(.title3) }
                .buttonStyle(.plain).foregroundStyle(Color.accentColor).help("Approve suggestion")
                .accessibilityLabel("Approve \(item.title)")
        } else if item.state == .archived {
            Image(systemName: item.archiveReason == .completed ? "checkmark.circle.fill" : "archivebox")
                .foregroundStyle(.secondary)
        } else {
            Button {
                if item.isCompleted { model.undoComplete(item) } else { model.complete(item) }
            } label: {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3).foregroundStyle(item.isCompleted ? Color.green : Color.secondary)
            }.buttonStyle(.plain).help(item.isCompleted ? "Undo completion" : "Mark done")
                .accessibilityLabel(item.isCompleted ? "Undo Done: \(item.title)" : "Mark Done: \(item.title)")
        }
    }
}

struct SnoozeMenu: View {
    @ObservedObject var model: AppModel
    let item: TaskItem
    var body: some View {
        let twoHours = Date().addingTimeInterval(7200)
        let tomorrow = AppModel.tomorrowMorning()
        let nextWorkingDay = AppModel.nextWorkingMorning()
        let oneWeek = Calendar.current.date(byAdding: .day, value: 7, to: Date())!
        Menu {
            Button("In two hours") { model.snooze(item, until: twoHours) }
                .disabled(twoHours <= item.dueDate)
            Button("Tomorrow at 09:00") { model.snooze(item, until: tomorrow) }
                .disabled(tomorrow <= item.dueDate)
            Button("Next working day at 09:00") { model.snooze(item, until: nextWorkingDay) }
                .disabled(nextWorkingDay <= item.dueDate)
            Button("In one week") { model.snooze(item, until: oneWeek) }
                .disabled(oneWeek <= item.dueDate)
            Divider()
            Button("Choose date...") { model.snoozeItem = item }
        } label: { Label("Snooze", systemImage: "clock.arrow.circlepath") }
        .menuStyle(.borderlessButton).fixedSize().help("Move the due date later")
        .accessibilityLabel("Snooze \(item.title)")
    }
}

struct TaskDetailView: View {
    @ObservedObject var model: AppModel
    let item: TaskItem
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    Text(item.state.displayName.uppercased()).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Spacer()
                    Button { model.selectedTaskID = nil } label: { Image(systemName: "xmark") }
                        .buttonStyle(.plain).accessibilityLabel("Close details")
                }
                Text(item.title).font(.title2.weight(.semibold)).strikethrough(item.isCompleted)
                HStack {
                    if item.state == .suggested {
                        Button("Approve") { model.approve(item) }.buttonStyle(.borderedProminent)
                        Button("Dismiss") { model.archive(item) }
                    } else if item.state == .archived {
                        Button("Restore") { model.restore(item) }.buttonStyle(.borderedProminent)
                    } else if item.isCompleted {
                        Button("Undo Done") { model.undoComplete(item) }
                    } else {
                        Button("Done") { model.complete(item) }.buttonStyle(.borderedProminent)
                        SnoozeMenu(model: model, item: item)
                    }
                    Spacer()
                    if item.state != .archived { Button("Edit") { model.editItem = item } }
                }.controlSize(.small)
                VStack(alignment: .leading, spacing: 14) {
                    detail("Due", value: item.dueDate.formatted(date: .abbreviated, time: .shortened))
                    detail(item.direction == .mine ? "Owed to" : "Responsible person", value: item.person.isEmpty ? "Not specified" : item.person)
                    detail("Time estimate", value: item.estimatedMinutes.map { "\($0) minutes" } ?? "Not estimated")
                    detail("Created", value: item.createdAt.formatted(date: .abbreviated, time: .shortened))
                    if let promised = item.promisedDueDate { detail("Original promise", value: promised.formatted(date: .abbreviated, time: .shortened)) }
                    detail("Origin", value: item.origin.displayName)
                    if let reason = item.archiveReason { detail("Archive reason", value: reason.displayName) }
                }
                if !item.notes.isEmpty {
                    Divider()
                    sectionTitle("Notes")
                    Text(item.notes).font(.callout).textSelection(.enabled)
                }
                if let source = item.sourceText, !source.isEmpty {
                    Divider()
                    sectionTitle("Source evidence")
                    Text(source).font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
                }
                if let urlString = item.sourceURL, let url = URL(string: urlString), ["https", "http"].contains(url.scheme?.lowercased() ?? "") {
                    Link("Open original", destination: url)
                }
                if !item.history.isEmpty {
                    Divider()
                    sectionTitle("History")
                    ForEach(item.history.reversed().prefix(12)) { event in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(event.description).font(.caption).textSelection(.enabled)
                            Text(event.date.formatted(date: .abbreviated, time: .shortened)).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
                if item.state == .active {
                    Divider()
                    Button("Remove task") { model.archive(item) }.foregroundStyle(.secondary)
                }
            }.padding(24)
        }.background(Color(nsColor: .controlBackgroundColor).opacity(0.4))
    }
    private func detail(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.callout).textSelection(.enabled)
        }
    }
    private func sectionTitle(_ title: String) -> some View {
        Text(title).font(.headline)
    }
}

extension TaskState {
    var displayName: String {
        switch self { case .active: return "Active"; case .suggested: return "Suggested"; case .archived: return "Archived" }
    }
}
extension TaskOrigin {
    var displayName: String {
        ["manual": "Added manually", "voice": "Voice capture", "imported": "Imported conversation", "emailFlag": "Email flag"][rawValue] ?? rawValue
    }
}
extension ArchiveReason {
    var displayName: String {
        switch self {
        case .completed: return "Done"
        case .removed: return "Removed"
        case .dismissed: return "Dismissed suggestion"
        case .reviewedTwice: return "Reviewed twice"
        case .expired: return "Older than a week"
        }
    }
}
