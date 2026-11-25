import Combine
import Foundation
@preconcurrency import AVFoundation
@preconcurrency import Speech

struct VoiceLocale: Identifiable, Hashable {
    let id: String
    let name: String
}

@MainActor
final class VoiceCapture: ObservableObject {
    @Published var transcript = ""
    @Published private(set) var isRecording = false
    @Published private(set) var isStarting = false
    @Published private(set) var isFinishing = false
    @Published private(set) var errorMessage: String?
    @Published var selectedLocaleIdentifier = "en-US"

    static let languages = [
        VoiceLocale(id: "en-US", name: "English (US)"),
        VoiceLocale(id: "sv-SE", name: "Swedish")
    ]

    var supportedLocalLocales: [VoiceLocale] {
        Self.languages.filter { language in
            SFSpeechRecognizer(locale: Locale(identifier: language.id))?
                .supportsOnDeviceRecognition == true
        }
    }

    private let audioEngine = AVAudioEngine()
    private var recognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var finishTimeout: Task<Void, Never>?
    private var sessionID = UUID()
    private var tapInstalled = false

    func start() async {
        guard !Task.isCancelled, !isStarting, !isRecording else { return }
        resetSession()
        transcript = ""
        errorMessage = nil
        isStarting = true
        let currentSession = sessionID
        let localeIdentifier = selectedLocaleIdentifier
        defer {
            if sessionID == currentSession { isStarting = false }
        }

        let speechPermission = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        guard sessionID == currentSession, !Task.isCancelled else { return }
        guard speechPermission == .authorized else {
            errorMessage = "Allow Speech Recognition for Priorities in System Settings > Privacy & Security to use dictation."
            return
        }

        guard let localRecognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier)),
              localRecognizer.supportsOnDeviceRecognition else {
            errorMessage = "On-device recognition is not available for this language on this Mac. Choose another language or type your task. Audio will not be sent to a server."
            return
        }
        guard localRecognizer.isAvailable else {
            errorMessage = "On-device speech recognition is unavailable right now. Try again or type your task."
            return
        }

        let microphonePermission = await AVCaptureDevice.requestAccess(for: .audio)
        guard sessionID == currentSession, !Task.isCancelled else { return }
        guard microphonePermission else {
            errorMessage = "Allow Microphone access for Priorities in System Settings > Privacy & Security to dictate a task."
            return
        }

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            errorMessage = "No microphone is available. Connect a microphone or type your task."
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        request.taskHint = .dictation
        recognizer = localRecognizer
        recognitionRequest = request

        inputNode.installTap(onBus: 0, bufferSize: 1_024, format: format) { buffer, _ in
            request.append(buffer)
        }
        tapInstalled = true

        recognitionTask = localRecognizer.recognitionTask(with: request) { [weak self] result, error in
            let text = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal == true
            let failure = error?.localizedDescription
            Task { @MainActor [weak self] in
                guard let self, self.sessionID == currentSession else { return }
                if let text { self.transcript = text }
                if isFinal || failure != nil {
                    self.resetSession()
                    if let failure, !isFinal {
                        self.errorMessage = "Dictation stopped: \(failure). Any captured text is still available to edit."
                    } else if self.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        self.errorMessage = "No speech was recognized. Try again or type your task."
                    }
                }
            }
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
            isStarting = false
            isRecording = true
        } catch {
            resetSession()
            errorMessage = "The microphone could not start: \(error.localizedDescription)"
        }
    }

    func stop() {
        guard isRecording else {
            if isStarting { resetSession() }
            return
        }
        stopAudioInput()
        isRecording = false
        isFinishing = true
        recognitionRequest?.endAudio()
        let currentSession = sessionID
        finishTimeout = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .seconds(3))
            } catch {
                return
            }
            guard let self, self.sessionID == currentSession else { return }
            self.resetSession()
            if self.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.errorMessage = "No speech was recognized. Try again or type your task."
            } else {
                self.errorMessage = "The final transcription did not finish. Check the captured text, then use Use Edited Text to save it."
            }
        }
    }

    func cancel() {
        resetSession()
        transcript = ""
        errorMessage = nil
    }

    private func stopAudioInput() {
        audioEngine.stop()
        if tapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
    }

    private func resetSession() {
        sessionID = UUID()
        finishTimeout?.cancel()
        finishTimeout = nil
        stopAudioInput()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        recognizer = nil
        isStarting = false
        isRecording = false
        isFinishing = false
    }
}
