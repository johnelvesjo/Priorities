import SwiftUI
import PrioritiesCore

@main
struct PrioritiesApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .frame(minWidth: 1040, minHeight: 640)
                .preferredColorScheme(.light)
        }
        .defaultSize(width: 1240, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Task") { model.showNewTask = true }
                    .keyboardShortcut("n", modifiers: .command)
                Button("Add by Voice") { model.showVoice = true }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                Button("Import Conversation") { model.showImport = true }
                    .keyboardShortcut("i", modifiers: [.command, .shift])
            }
        }
    }
}
