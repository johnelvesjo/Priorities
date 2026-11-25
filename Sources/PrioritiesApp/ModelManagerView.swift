import SwiftUI
import PrioritiesCore
import Speech

struct ModelManagerView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var power: PowerMonitor
    @State private var endpointDraft = ""
    @State private var endpointError: String?
    @State private var downloadName = ""
    @State private var modelToDelete: String?
    @State private var showDeleteConfirmation = false
    @State private var speechSupport: [String: Bool] = [:]

    @MainActor
    init(model: AppModel) {
        self.model = model
        self.power = model.power
    }

    private var selectedModel: LocalModelInfo? {
        model.models.first { $0.name == model.settings.selectedModel }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Models & power")
                        .font(.system(size: 28, weight: .semibold))
                    Text("Choose local models for understanding conversations and interpreting dictation.")
                        .foregroundStyle(.secondary)
                }

                connectionSection
                downloadedModelsSection
                roleAssignmentSection
                downloadSection
                ModelPowerSection(model: model, power: power)

                if let error = model.errorMessage, !error.isEmpty {
                    Label(error, systemImage: "exclamationmark.circle")
                        .font(.callout)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            }
            .padding(32)
            .frame(maxWidth: 920)
            .frame(maxWidth: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            endpointDraft = model.settings.endpoint
            refreshSpeechSupport()
            await model.refreshModels()
        }
        .alert("Delete downloaded model?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { modelToDelete = nil }
            Button("Delete Model", role: .destructive) {
                guard let name = modelToDelete else { return }
                modelToDelete = nil
                Task { await model.removeModel(name) }
            }
        } message: {
            Text("Delete \(modelToDelete ?? "this model") from this Mac's shared Ollama library? Other apps using this model will also lose access until it is downloaded again.")
        }
    }

    private var connectionSection: some View {
        ModelSettingsCard(title: "On this Mac", systemImage: "desktopcomputer") {
            Text("Connect to Ollama running on this Mac. Remote servers and cloud models are not supported.")
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                TextField("http://127.0.0.1:11434", text: $endpointDraft)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Local Ollama server address")
                    .onSubmit(connect)
                    .disabled(model.runtimeBusy)
                Button("Connect", action: connect)
                    .disabled(model.runtimeBusy || endpointDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if let endpointError {
                Text(endpointError)
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            HStack(alignment: .top, spacing: 10) {
                if model.runtimeBusy {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                }
                Text(model.runtimeMessage.isEmpty ? "Connect to check your local model library." : model.runtimeMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }

            Divider()
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ollama is installed separately")
                        .font(.callout.weight(.medium))
                    Text("If it is unavailable, install and start Ollama, then connect here. Priorities does not install it automatically.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Link("Setup guide", destination: URL(string: "https://docs.ollama.com/macos")!)
                    .fixedSize()
            }
        }
    }

    private var downloadedModelsSection: some View {
        ModelSettingsCard(title: "Downloaded models", systemImage: "internaldrive") {
            if model.models.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("No local models to show")
                        .font(.callout.weight(.medium))
                    Text("Connect to Ollama to see downloaded models, or download one below after connecting.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(model.models) { item in
                        modelRow(item)
                        if item.id != model.models.last?.id { Divider() }
                    }
                }
            }

            HStack(spacing: 10) {
                Button("Refresh") {
                    refreshSpeechSupport()
                    Task { await model.refreshModels() }
                }
                    .disabled(model.runtimeBusy)
                Spacer()
                Button("Load") { Task { await model.loadSelectedModel() } }
                    .disabled(model.runtimeBusy || selectedModel == nil || !model.canProcess)
                Button("Unload") { Task { await model.unloadSelectedModel() } }
                    .disabled(model.runtimeBusy || selectedModel?.isLoaded != true)
                Button("Test Selected Model") { Task { await model.testSelectedModel() } }
                    .disabled(model.runtimeBusy || selectedModel == nil || !model.canProcess)
            }

            Text("Select your task-understanding model. Loading puts it in memory. Unloading frees that memory and pauses task processing; use Resume Processing below when you are ready.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Unload and Delete act on the model in Ollama and can affect other apps using it.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var roleAssignmentSection: some View {
        ModelSettingsCard(title: "Models by role", systemImage: "square.stack.3d.up") {
            Text("Use one model for both kinds of text, or choose a different model to interpret dictated tasks.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 7) {
                Picker("Task understanding", selection: Binding(
                    get: { model.settings.selectedModel },
                    set: { model.selectModel($0) }
                )) {
                    Text("Choose a model").tag("").disabled(true)
                    if !model.settings.selectedModel.isEmpty,
                       !model.models.contains(where: { $0.name == model.settings.selectedModel }) {
                        Text("\(model.settings.selectedModel) (unavailable)")
                            .tag(model.settings.selectedModel)
                            .disabled(true)
                    }
                    ForEach(model.models) { item in
                        Text(item.name).tag(item.name)
                    }
                }
                .disabled(model.runtimeBusy)
                Text("Finds tasks in imported conversations. The load, unload and test controls above manage this model.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 7) {
                Picker("Voice interpretation", selection: Binding(
                    get: { model.settings.voiceInterpretationModel },
                    set: { model.selectVoiceInterpretationModel($0) }
                )) {
                    Text("Use task model").tag("")
                    if !model.settings.voiceInterpretationModel.isEmpty,
                       !model.models.contains(where: { $0.name == model.settings.voiceInterpretationModel }) {
                        Text("\(model.settings.voiceInterpretationModel) (unavailable)")
                            .tag(model.settings.voiceInterpretationModel)
                            .disabled(true)
                    }
                    ForEach(model.models) { item in
                        Text(item.name).tag(item.name)
                    }
                }
                .disabled(model.runtimeBusy)
                Text("Interprets the text produced by dictation and turns it into tasks. Use task model follows your task-understanding choice.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Speech to text").font(.callout.weight(.medium))
                    Spacer()
                    Text("Apple on-device speech").font(.callout).foregroundStyle(.secondary)
                }
                Text("Turns microphone audio into text before the voice-interpretation model runs. Ollama model choices do not change speech recognition.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(VoiceCapture.languages) { language in
                    HStack {
                        Text(language.name)
                        Spacer()
                        if let supported = speechSupport[language.id] {
                            Label(supported ? "Local support detected" : "Not available locally",
                                  systemImage: supported ? "checkmark.circle" : "circle.slash")
                                .foregroundStyle(supported ? Color.teal : Color.secondary)
                        } else {
                            Text("Checking local support").foregroundStyle(.secondary)
                        }
                    }
                    .font(.caption)
                }
                Text("Availability is checked again before each recording. Voice replies and listening while speaking are not available yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func modelRow(_ item: LocalModelInfo) -> some View {
        HStack(spacing: 14) {
            Button {
                model.selectModel(item.name)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: item.name == model.settings.selectedModel ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(item.name == model.settings.selectedModel ? Color.accentColor : Color.secondary)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(item.name)
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                        Text(modelDetails(item))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    if item.isLoaded {
                        Text("In memory")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.teal)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.teal.opacity(0.08), in: Capsule())
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(model.runtimeBusy)
            .accessibilityLabel("Use \(item.name) for task understanding")
            .accessibilityValue(item.name == model.settings.selectedModel ? "Selected" : "Not selected")

            Button {
                modelToDelete = item.name
                showDeleteConfirmation = true
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help("Delete downloaded model")
            .accessibilityLabel("Delete \(item.name)")
            .disabled(model.runtimeBusy)
        }
        .padding(.vertical, 12)
    }

    private var downloadSection: some View {
        ModelSettingsCard(title: "Download a model", systemImage: "arrow.down.circle") {
            Text("Enter a local model tag from the Ollama library. The download uses the internet and saves the model in Ollama's storage on this Mac.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                TextField("Model tag", text: $downloadName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(download)
                    .disabled(model.runtimeBusy)
                Button("Download", action: download)
                    .disabled(model.runtimeBusy || downloadName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Link("Browse models", destination: URL(string: "https://ollama.com/library")!)
            }

            if let progress = model.downloadProgress {
                VStack(alignment: .leading, spacing: 8) {
                    ProgressView(value: min(1, max(0, progress)))
                    HStack {
                        Text(model.downloadMessage.isEmpty ? "Downloading model" : model.downloadMessage)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int((min(1, max(0, progress)) * 100).rounded()))%")
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Button("Cancel") { model.cancelDownload() }
                    }
                }
            } else if !model.downloadMessage.isEmpty {
                Text(model.downloadMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Text("Compare speed and Swedish accuracy on your own examples before choosing a model for everyday use.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func modelDetails(_ item: LocalModelInfo) -> String {
        let size = ByteCountFormatter.string(fromByteCount: item.sizeBytes, countStyle: .file)
        return ([size] + [item.parameterSize, item.quantization].compactMap { $0 }.filter { !$0.isEmpty })
            .joined(separator: " · ")
    }

    private func refreshSpeechSupport() {
        speechSupport = Dictionary(uniqueKeysWithValues: VoiceCapture.languages.map { language in
            let supported = SFSpeechRecognizer(locale: Locale(identifier: language.id))?
                .supportsOnDeviceRecognition == true
            return (language.id, supported)
        })
    }

    private func connect() {
        guard !model.runtimeBusy else { return }
        do {
            let client = try LocalModelClient(endpoint: endpointDraft)
            endpointError = nil
            model.settings.endpoint = client.endpoint.absoluteString
            endpointDraft = model.settings.endpoint
            Task { await model.refreshModels() }
        } catch {
            endpointError = error.localizedDescription
        }
    }

    private func download() {
        let name = downloadName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !model.runtimeBusy else { return }
        Task { await model.downloadModel(name) }
    }
}

private struct ModelPowerSection: View {
    @ObservedObject var model: AppModel
    @ObservedObject var power: PowerMonitor

    private var powerAllowsProcessing: Bool {
        power.canRun(minimumBattery: model.settings.minimumBattery)
    }

    var body: some View {
        ModelSettingsCard(title: "When to process", systemImage: "battery.75percent") {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(model.settings.processingPaused ? "Task processing is paused" : "Task processing is enabled")
                        .font(.callout.weight(.medium))
                    Text(model.settings.processingPaused
                         ? "Queued material will wait until you resume. The battery rule still applies after resuming."
                         : "Pause at any time to hold queued material until you are ready.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Button(model.settings.processingPaused ? "Resume Processing" : "Pause Processing") {
                    if model.settings.processingPaused {
                        model.resumeProcessing()
                    } else {
                        model.pauseProcessing()
                    }
                }
                .fixedSize()
            }

            Divider()

            HStack {
                Text(power.statusDescription)
                    .font(.callout.weight(.medium))
                Spacer()
                Label(powerAllowsProcessing ? "Power allows processing" : "Waiting for power", systemImage: powerAllowsProcessing ? "checkmark.circle" : "pause.circle")
                    .font(.callout)
                    .foregroundStyle(powerAllowsProcessing ? Color.teal : Color.secondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Minimum battery")
                    Spacer()
                    Text("\(Int(model.settings.minimumBattery.rounded()))%")
                        .monospacedDigit()
                        .fontWeight(.medium)
                    Stepper("Minimum battery", value: $model.settings.minimumBattery, in: 10...95, step: 5)
                        .labelsHidden()
                        .accessibilityLabel("Minimum battery percentage")
                }
                Slider(value: $model.settings.minimumBattery, in: 10...95, step: 5)
                    .accessibilityLabel("Minimum battery percentage")
                Text("Process when plugged in, or when the battery is at least \(Int(model.settings.minimumBattery.rounded()))%. Below that, keep new material queued for later.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(alignment: .top) {
                Text(model.powerExplanation)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                if model.queuedCount > 0 {
                    Text("\(model.queuedCount) queued")
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .fixedSize()
                }
            }
        }
    }
}

private struct ModelSettingsCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            content()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        }
    }
}
