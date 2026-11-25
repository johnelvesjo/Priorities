# Local voice capture

Voice capture uses Apple's Speech and AVFoundation frameworks. It checks that the selected recognizer supports on-device recognition before it starts the microphone, then sets `requiresOnDeviceRecognition` to `true`. There is no remote fallback and Priorities does not save audio files.

Model roles are separate. Speech to text uses Apple's on-device recognizer to produce a transcript. Voice interpretation uses a selected local Ollama model to extract tasks from that transcript. Task understanding uses the main local Ollama model for imported conversations. The model manager can assign a different model to voice interpretation, or use the task model for both. These assignments do not replace Apple's speech recognizer. Speech synthesis and full-duplex voice conversation are not implemented.

The first attempt asks macOS for speech recognition and microphone permission. Permission prompts belong to the app bundle, so launch `dist/Priorities.app` rather than the bare Swift executable. If permission is denied, the app explains how to enable it in System Settings. A signed release and distribution process are future work; the build script creates an ad-hoc signed development app.

English (US) and Swedish are offered as recognition languages. Availability depends on the Mac and its installed speech resources. `supportedLocalLocales` reports which of these languages Apple currently identifies as supporting local recognition. A language choice is not a promise that its recognition resources are ready, and a runtime failure is shown instead of switching to a server. This app does not download speech models.

One recognizer handles one selected language at a time. English words in a Swedish sentence, or Swedish names in English, may be transcribed incorrectly. Mixed-language accuracy has not been validated. A successful capture enters the local processing queue automatically when recognition finishes, including after pressing Stop. The selected local language model then extracts tasks. Clear dictated tasks save without a mandatory preview; missing or unclear fields require clarification. Saved tasks remain editable.

If speech recognition reports an error, the transcript stays in the capture window for correction and is not submitted automatically. Use Edited Text submits a corrected or typed capture. Cancel or closing the window discards the current capture without submitting it. The window closes after a successful queue save, with a guard against duplicate submissions.

Starting dictation requires the configured power condition. If power drops below the threshold while recording, microphone input stops and the final transcript is saved to the queue for later processing. A recognition failure still leaves the text available for correction.

`start()` requests permissions and begins a new transcript. `stop()` immediately stops microphone input, preserves partial text, and allows up to three seconds for the final recognition result. The UI can use `isStarting` and `isFinishing` to prevent conflicting actions. `cancel()` stops capture and clears the transcript. The capture view must call `cancel()` when it closes.

## Build and run

Run `./scripts/build-app.sh` to compile and bundle the app without launching it. Run `./scripts/run-app.sh` to build and open it. The scripts copy only `Package.swift`, `Sources` and `Tests` into a temporary directory under `/private/tmp` to avoid a SwiftPM linker problem with literal quotes in the repository path. Compiler output, module caches and SwiftPM configuration stay in that temporary directory, which is removed on success or failure. The finished app is copied back to `dist/Priorities.app` in this repository. `CONFIGURATION=debug` selects a debug build; release is the default. Run `./scripts/test.sh` for the test suite using the same temporary staging process.

The bundle ID is `se.johnelvesjo.priorities`, and its minimum macOS version is 14.0. Changing or rebuilding an ad-hoc signed app can affect macOS privacy permissions. This script does not reset those permissions.

## Verification still requiring a user

Check permission denial and approval, English and Swedish recognition with the network disabled, stop and cancel, closing the capture view during recording, microphone removal, and mixed-language dictation. Compilation cannot establish speech accuracy or permission behavior. No microphone capture is performed by automated tests.

## Apple documentation

- [On-device recognition support](https://developer.apple.com/documentation/speech/sfspeechrecognizer/supportsondevicerecognition)
- [Require recognition to stay on the device](https://developer.apple.com/documentation/speech/sfspeechrecognitionrequest/requiresondevicerecognition)
- [Speech recognition permission](https://developer.apple.com/documentation/speech/asking-permission-to-use-speech-recognition)
- [Live audio recognition requests](https://developer.apple.com/documentation/speech/sfspeechaudiobufferrecognitionrequest)
