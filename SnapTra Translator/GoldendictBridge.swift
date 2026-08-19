import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

// MARK: - Hotkey parsing helpers for the GoldenDict-ng clipboard hotkey

/// Parses, formats and simulates hotkey combinations like "option+q".
enum GoldendictHotkeyParser {
    private static let modifierKeyCodes: Set<UInt16> = [
        0x36, 0x37, // command (right, left)
        0x38, 0x3C, // shift (left, right)
        0x3A, 0x3D, // option (left, right)
        0x3B, 0x3E, // control (left, right)
        0x3F,       // fn
        0x39,       // caps lock
    ]

    private static let charToKeyCode: [Character: CGKeyCode] = [
        "a": 0x00, "s": 0x01, "d": 0x02, "f": 0x03, "h": 0x04, "g": 0x05,
        "z": 0x06, "x": 0x07, "c": 0x08, "v": 0x09, "b": 0x0B, "q": 0x0C,
        "w": 0x0D, "e": 0x0E, "r": 0x0F, "y": 0x10, "t": 0x11, "1": 0x12,
        "2": 0x13, "3": 0x14, "4": 0x15, "6": 0x16, "5": 0x17, "=": 0x18,
        "9": 0x19, "7": 0x1A, "-": 0x1B, "8": 0x1C, "0": 0x1D, "]": 0x1E,
        "o": 0x1F, "u": 0x20, "[": 0x21, "i": 0x22, "p": 0x23, "l": 0x25,
        "j": 0x26, "'": 0x27, "k": 0x28, ";": 0x29, "\\": 0x2A, ",": 0x2B,
        "/": 0x2C, "n": 0x2D, "m": 0x2E, ".": 0x2F, " ": 0x31, "`": 0x32,
    ]

    private static let modifierNames: [String: String] = [
        "fn": "fn",
        "control": "⌃",
        "option": "⌥",
        "shift": "⇧",
        "command": "⌘",
    ]

    struct ParsedHotkey {
        let modifiers: [String]
        let key: String
    }

    /// Builds a normalized hotkey string from a key event, e.g. "option+q".
    static func string(from event: NSEvent) -> String? {
        guard !modifierKeyCodes.contains(event.keyCode) else { return nil }
        guard let chars = event.charactersIgnoringModifiers?.lowercased(),
              let first = chars.first,
              first.isLetter || first.isNumber || first.isPunctuation || first.isSymbol
        else { return nil }

        var parts: [String] = []
        let flags = event.modifierFlags
        if flags.contains(.function) { parts.append("fn") }
        if flags.contains(.control) { parts.append("control") }
        if flags.contains(.option) { parts.append("option") }
        if flags.contains(.shift) { parts.append("shift") }
        if flags.contains(.command) { parts.append("command") }
        parts.append(String(first))
        return parts.joined(separator: "+")
    }

    /// Parses a stored hotkey string into a normalized structure.
    static func parse(_ hotkey: String) -> ParsedHotkey? {
        let parts = hotkey.lowercased().split(separator: "+").map(String.init)
        guard let key = parts.last, !key.isEmpty else { return nil }
        let allowed = Set(["fn", "control", "option", "shift", "command"])
        let mods = parts.dropLast()
        guard mods.allSatisfy({ allowed.contains($0) }) else { return nil }
        return ParsedHotkey(modifiers: Array(mods), key: key)
    }

    /// Renders a stored hotkey string for display, e.g. "⌥ Q".
    static func displayString(for hotkey: String) -> String? {
        var parts = hotkey.lowercased().split(separator: "+").map(String.init)
        guard let key = parts.popLast(), !key.isEmpty else { return nil }
        let mods = parts.compactMap { modifierNames[$0] }
        return (mods + [key.uppercased()]).joined(separator: " ")
    }

    /// Posts the hotkey to the system. Requires Accessibility permission.
    static func simulate(hotkey: String) -> Bool {
        guard AXIsProcessTrusted() else { return false }
        guard let parsed = parse(hotkey),
              let keyCode = charToKeyCode[Character(parsed.key)],
              let source = CGEventSource(stateID: .combinedSessionState)
        else { return false }

        var flags: CGEventFlags = []
        for modifier in parsed.modifiers {
            switch modifier {
            case "fn": flags.insert(.maskSecondaryFn)
            case "control": flags.insert(.maskControl)
            case "option": flags.insert(.maskAlternate)
            case "shift": flags.insert(.maskShift)
            case "command": flags.insert(.maskCommand)
            default: break
            }
        }

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        keyDown?.flags = flags
        keyDown?.post(tap: .cghidEventTap)

        // Small delay so the system processes the key-down before the key-up.
        usleep(60_000)

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        keyUp?.flags = flags
        keyUp?.post(tap: .cghidEventTap)
        return true
    }
}

// MARK: - GoldenDict-ng integration

/// Bridges word lookups from SnapTra to GoldenDict-ng.
@MainActor
final class GoldendictBridge {
    static let shared = GoldendictBridge()

    static let bundleIdentifier = "org.xiaoyifang"
    static let fallbackAppPath = "/Applications/GoldenDict-ng.app"

    /// Prevents the same word from triggering GoldenDict repeatedly within a short window
    /// (continuous translation re-captures the same word many times per second).
    private static let debounceInterval: TimeInterval = 1.0
    private var lastQuery: (word: String, date: Date)?

    static var isAccessibilityGranted: Bool {
        AXIsProcessTrusted()
    }

    /// Looks up `word` in GoldenDict-ng using the selected method.
    /// Returns false when the lookup could not be triggered.
    @discardableResult
    func lookup(word: String, method: GoldendictQueryMethod, copyToClipboard: Bool) -> Bool {
        let now = Date()
        if let last = lastQuery,
           last.word == word,
           now.timeIntervalSince(last.date) < Self.debounceInterval {
            return true // Debounced: already queried recently.
        }
        lastQuery = (word, now)

        switch method {
        case .urlScheme:
            return Self.openURLScheme(word: word, copyToClipboard: copyToClipboard)
        case .simulateHotkey:
            // The clipboard hotkey translates whatever is on the clipboard, so the
            // word must be written first (regardless of the copy-to-clipboard option).
            return Self.simulateClipboardHotkey(word: word)
        }
    }

    private static func openURLScheme(word: String, copyToClipboard: Bool) -> Bool {
        if copyToClipboard {
            writeToClipboard(word)
        }
        // Place the word in the URL *path* (empty host) instead of the host.
        // macOS/Qt turn non-ASCII hosts into punycode (xn--...), which GoldenDict
        // would then query literally; the path is kept as UTF-8 and GoldenDict's
        // extractWordFromUrl falls back to the path when the authority is empty.
        var components = URLComponents()
        components.scheme = "goldendict"
        components.host = ""
        components.path = "/" + word
        components.queryItems = [URLQueryItem(name: "target", value: "popup")]
        guard let url = components.url else { return false }
        // Open the URL without switching/activating GoldenDict-ng, so a
        // fullscreen video app stays in fullscreen while the popup shows.
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        NSWorkspace.shared.open(url, configuration: configuration) { _, _ in }
        return true
    }

    private static func simulateClipboardHotkey(word: String) -> Bool {
        writeToClipboard(word)
        let hotkey = SettingsStore.shared.goldendictClipboardHotkey
        guard !hotkey.isEmpty else { return false }
        return GoldendictHotkeyParser.simulate(hotkey: hotkey)
    }

    /// Atomically replaces the clipboard contents with `word`.
    private static func writeToClipboard(_ word: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(word, forType: .string)
    }

    /// Returns the URL of the installed GoldenDict-ng app, if any.
    static func appURL() -> URL? {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            return url
        }
        let fallback = URL(fileURLWithPath: fallbackAppPath)
        return FileManager.default.fileExists(atPath: fallback.path) ? fallback : nil
    }
}
