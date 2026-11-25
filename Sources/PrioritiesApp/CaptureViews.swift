import SwiftUI
import PrioritiesCore

struct TaskEditor: View {
    @Environment(\.dismiss) private var dismiss
    let initial: TaskItem?
    let clarification: String?
    let onSave: (TaskItem) -> Void
    @State private var title: String
    @State private var person: String
    @State private var notes: String
    @State private var dueDate: Date
    @State private var direction: TaskDirection
    @State private var minutes: String
    @State private var hasPromisedDate: Bool
    @State private var promisedDate: Date
    @FocusState private var titleFocused: Bool

    init(initial: TaskItem?, direction: TaskDirection, clarification: String? = nil, onSave: @escaping (TaskItem) -> Void) {
        self.initial = initial
        self.clarification = clarification
        self.onSave = onSave
        _title = State(initialValue: initial?.title ?? "")
        _person = State(initialValue: initial?.person ?? "")
        _notes = State(initialValue: initial?.notes ?? "")
        _dueDate = State(initialValue: initial?.dueDate ?? AppModel.tomorrowMorning())
        _direction = State(initialValue: direction)
        _minutes = State(initialValue: initial?.estimatedMinutes.map(String.init) ?? "")
        _hasPromisedDate = State(initialValue: initial?.promisedDueDate != nil)
        _promisedDate = State(initialValue: initial?.promisedDueDate ?? initial?.dueDate ?? AppModel.tomorrowMorning())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(clarification != nil ? "One detail to clarify" : initial == nil ? "Add Task" : "Edit Task").font(.title2.weight(.semibold))
            if let clarification {
                Label(clarification, systemImage: "questionmark.circle").font(.callout).foregroundStyle(.secondary)
            }
            TextField("What needs to happen?", text: $title)
                .textFieldStyle(.roundedBorder).font(.title3).focused($titleFocused)
                .accessibilityIdentifier("taskTitle")
            Form {
                Picker("List", selection: $direction) {
                    Text("My Tasks").tag(TaskDirection.mine)
                    Text("Owed to Me").tag(TaskDirection.owedToMe)
                }
                TextField(direction == .mine ? "Owed to" : "Responsible person", text: $person)
                DatePicker("Due", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                TextField("Estimated minutes", text: $minutes)
                Toggle("Keep an original promised deadline", isOn: $hasPromisedDate)
                if hasPromisedDate {
                    DatePicker("Original promise", selection: $promisedDate, displayedComponents: [.date, .hourAndMinute])
                }
            }.formStyle(.grouped).frame(height: hasPromisedDate ? 264 : 226)
            VStack(alignment: .leading, spacing: 6) {
                Text("Notes and background").font(.caption).foregroundStyle(.secondary)
                TextEditor(text: $notes).font(.body).frame(height: 90)
                    .border(Color(nsColor: .separatorColor).opacity(0.5))
            }
            HStack {
                Button(clarification == nil ? "Cancel" : "Keep for later") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button(initial == nil || clarification != nil ? "Add Task" : "Save Changes") { save() }
                    .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !validMinutes)
                    .accessibilityIdentifier("saveTask")
            }
        }.padding(28).frame(width: 540)
            .onAppear { titleFocused = true }
    }
    private var validMinutes: Bool {
        minutes.isEmpty || (Int(minutes).map { $0 > 0 && $0 <= 100_000 } ?? false)
    }
    private func save() {
        var item = initial ?? TaskItem(title: title, dueDate: dueDate, direction: direction)
        item.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        item.person = person.trimmingCharacters(in: .whitespacesAndNewlines)
        item.notes = notes
        item.dueDate = dueDate
        item.direction = direction
        item.estimatedMinutes = Int(minutes)
        item.promisedDueDate = hasPromisedDate ? promisedDate : nil
        if clarification != nil { item.state = .active }
        item.history.append(TaskChange(description: initial == nil ? "Added manually" : "Details updated by you"))
        onSave(item)
        dismiss()
    }
}

struct SnoozeDateView: View {
    @Environment(\.dismiss) private var dismiss
    let item: TaskItem
    let onSave: (Date) -> Void
    @State private var date: Date

    init(item: TaskItem, onSave: @escaping (Date) -> Void) {
        self.item = item
        self.onSave = onSave
        _date = State(initialValue: max(AppModel.tomorrowMorning(), item.dueDate.addingTimeInterval(60)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Move the due date").font(.title2.weight(.semibold))
            Text(item.title).foregroundStyle(.secondary)
            DatePicker("New due date", selection: $date, in: item.dueDate..., displayedComponents: [.date, .hourAndMinute])
            Text("Choose a date later than the current due date. The task stays visible, with its creation date and original promise preserved.")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Snooze") {
                    guard date > item.dueDate else { return }
                    onSave(date)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent)
                .disabled(date <= item.dueDate)
            }
        }.padding(28).frame(width: 450)
    }
}

struct ImportConversationView: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Import a Conversation", systemImage: "text.badge.plus").font(.title2.weight(.semibold))
            Text("Paste an email or conversation. Your selected local model will suggest tasks with evidence. Nothing is sent to cloud AI.")
                .foregroundStyle(.secondary)
            TextEditor(text: $text).font(.body).frame(height: 260)
                .border(Color(nsColor: .separatorColor).opacity(0.5))
                .accessibilityIdentifier("importText")
            HStack {
                Text("\(text.count)/12,000 characters").font(.caption).foregroundStyle(.secondary)
                Spacer()
                if !model.canProcess { Label("Will wait for power", systemImage: "battery.25").font(.caption) }
                else if model.settings.selectedModel.isEmpty { Text("Will wait for a local model").font(.caption) }
            }
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Find Tasks Locally") { model.enqueue(text, kind: .conversation); dismiss() }
                    .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || text.count > 12_000)
            }
        }.padding(28).frame(width: 620)
    }
}

struct VoiceEntryView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var power: PowerMonitor
    @StateObject private var voice = VoiceCapture()
    @Environment(\.dismiss) private var dismiss
    @State private var startTask: Task<Void, Never>?
    @State private var captureSessionID: UUID?
    @State private var autoSubmitPending = false
    @State private var hasRecorded = false
    @State private var isSubmitting = false
    @State private var isClosing = false
    @State private var captureError: String?

    init(model: AppModel) { self.model = model; power = model.power }

    private var voiceIsBusy: Bool {
        voice.isStarting || voice.isRecording || voice.isFinishing
    }

    private var transcriptIsValid: Bool {
        let text = voice.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        return !text.isEmpty && text.count <= 12_000
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Add by Voice", systemImage: "mic").font(.title2.weight(.semibold))
            Text("Say the action, person, due date and time estimate, then stop. Clear tasks save after local analysis. Only missing or unclear details need your input.")
                .foregroundStyle(.secondary)
            HStack {
                Picker("Speech language", selection: $voice.selectedLocaleIdentifier) {
                    ForEach(VoiceCapture.languages) { language in Text(language.name).tag(language.id) }
                }.frame(width: 260).disabled(voiceIsBusy || startTask != nil || isSubmitting)
                Spacer()
                if voice.isRecording {
                    Button("Stop", systemImage: "stop.fill") { voice.stop() }.tint(.red)
                } else {
                    Button("Start Dictation", systemImage: "mic.fill", action: startDictation)
                        .disabled(!model.canProcess || voiceIsBusy || startTask != nil || isSubmitting || isClosing)
                }
            }
            if voice.isStarting || voice.isFinishing {
                HStack { ProgressView().controlSize(.small); Text(voice.isStarting ? "Preparing local speech recognition" : "Finishing transcription") }.font(.caption)
            }
            TextEditor(text: $voice.transcript).font(.body).frame(height: 200)
                .border(Color(nsColor: .separatorColor).opacity(0.5))
                .disabled(voiceIsBusy || startTask != nil || isSubmitting)
            if let error = voice.errorMessage { Text(error).font(.callout).foregroundStyle(.red) }
            if let captureError { Text(captureError).font(.callout).foregroundStyle(.red) }
            if voice.transcript.count > 12_000 {
                Text("Shorten this capture to 12,000 characters before saving it.").font(.caption).foregroundStyle(.red)
            }
            if !model.canProcess { Text(model.powerExplanation).font(.caption).foregroundStyle(.orange) }
            Text("Uses on-device speech only. Availability and mixed-language recognition depend on the speech models installed on this Mac.")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Cancel") { cancelCapture(); dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Use Edited Text", action: submitTranscript)
                    .buttonStyle(.borderedProminent)
                    .disabled(voiceIsBusy || startTask != nil || isSubmitting || isClosing || !transcriptIsValid)
            }
        }.padding(28).frame(width: 620)
            .onDisappear(perform: cancelCapture)
            .onChange(of: voiceIsBusy) { wasBusy, isBusy in
                if wasBusy && !isBusy { submitFinishedCaptureIfReady() }
            }
            .onChange(of: model.canProcess) { _, allowed in
                guard !allowed else { return }
                if voice.isRecording {
                    voice.stop()
                } else if voice.isStarting || startTask != nil {
                    startTask?.cancel()
                    startTask = nil
                    autoSubmitPending = false
                    captureSessionID = nil
                    voice.stop()
                }
            }
    }

    private func startDictation() {
        guard model.canProcess, !voiceIsBusy, startTask == nil, !isSubmitting, !isClosing else { return }
        let sessionID = UUID()
        captureSessionID = sessionID
        autoSubmitPending = true
        hasRecorded = false
        captureError = nil
        startTask = Task { @MainActor in
            await voice.start()
            guard captureSessionID == sessionID, !isClosing, !Task.isCancelled else { return }
            startTask = nil
            guard voice.isRecording else {
                autoSubmitPending = false
                return
            }
            hasRecorded = true
            if !model.canProcess { voice.stop() }
        }
    }

    private func submitFinishedCaptureIfReady() {
        guard autoSubmitPending, hasRecorded, !voiceIsBusy, startTask == nil, !isSubmitting, !isClosing else { return }
        autoSubmitPending = false
        guard voice.errorMessage == nil else { return }
        submitTranscript()
    }

    private func submitTranscript() {
        guard !voiceIsBusy, startTask == nil, !isSubmitting, !isClosing, transcriptIsValid else { return }
        isSubmitting = true
        autoSubmitPending = false
        captureError = nil
        let existingIDs = Set(model.jobs.map(\.id))
        model.enqueue(voice.transcript, kind: .voice)
        guard model.jobs.contains(where: { !existingIDs.contains($0.id) }) else {
            isSubmitting = false
            captureError = model.errorMessage ?? "This capture could not be saved. Your text is still here; try again."
            return
        }
        isClosing = true
        dismiss()
    }

    private func cancelCapture() {
        isClosing = true
        autoSubmitPending = false
        captureSessionID = nil
        startTask?.cancel()
        startTask = nil
        voice.cancel()
    }
}

struct SourcesView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                GroupBox {
                    HStack(alignment: .top, spacing: 16) {
                        Image(systemName: "text.badge.plus").font(.title).foregroundStyle(Color.accentColor)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Paste a conversation").font(.headline)
                            Text("Available now. Turn text you provide into evidence-backed suggestions using your local model.").foregroundStyle(.secondary)
                            Button("Import Conversation") { model.showImport = true }.buttonStyle(.borderedProminent)
                        }
                        Spacer()
                    }.padding(16)
                }
                VStack(alignment: .leading, spacing: 14) {
                    Text("Account connections").font(.headline)
                    Text("Direct account synchronization is not connected in this first build. Your mailboxes and Slack have not been accessed.")
                        .foregroundStyle(.secondary)
                    ForEach(["Outlook work", "Gmail personal", "Slack"], id: \.self) { name in
                        HStack { Image(systemName: name == "Slack" ? "bubble.left.and.bubble.right" : "envelope"); Text(name); Spacer(); Text("Not connected").foregroundStyle(.secondary) }
                            .padding(.vertical, 10)
                        Divider()
                    }
                }
                if !model.jobs.isEmpty {
                    Text("Local processing queue").font(.headline)
                    ForEach(model.jobs) { job in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(job.kind == .voice ? "Voice capture" : "Imported conversation").font(.subheadline.weight(.medium))
                                Spacer()
                                Text(job.createdAt.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                            }
                            Text(String(job.text.prefix(140))).lineLimit(3).font(.callout).foregroundStyle(.secondary)
                            if let error = job.error {
                                Text(error).font(.caption).foregroundStyle(.red)
                                Button("Retry") { model.retryJob(job.id) }
                            } else { Text(model.processingJobID == job.id ? "Processing locally" : "Queued").font(.caption).foregroundStyle(.secondary) }
                            Button("Remove from queue") { model.removeJob(job.id) }.font(.caption)
                            Divider()
                        }
                    }
                }
            }.padding(28).frame(maxWidth: 780, alignment: .leading).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
