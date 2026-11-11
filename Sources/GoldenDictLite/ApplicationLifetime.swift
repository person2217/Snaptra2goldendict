import AppKit
import SwiftUI

/// Keeps ordinary close and quit actions in the menu bar; only its menu item exits.
@MainActor
enum ApplicationLifetime {
    private static var allowTermination = false

    static func hideToMenuBar() {
        if !Model.shared.showMenuBar { Model.shared.showMenuBar = true }
        NSApp.hide(nil)
    }

    static func quitFromStatusMenu() {
        allowTermination = true
        NSApp.terminate(nil)
    }

    static func terminationDecision(explicitStatusMenuExit: Bool) -> NSApplication.TerminateReply {
        explicitStatusMenuExit ? .terminateNow : .terminateCancel
    }

    static func shouldTerminate() -> NSApplication.TerminateReply {
        guard terminationDecision(explicitStatusMenuExit: allowTermination) == .terminateNow else {
            hideToMenuBar()
            return .terminateCancel
        }
        return .terminateNow
    }
}

struct OpenSettingsMenuButton: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button("设置…") {
            NSApp.unhide(nil)
            openSettings()
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
