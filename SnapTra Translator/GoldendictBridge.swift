import AppKit
import Foundation

// MARK: - GoldenDict-ng integration

/// Opens captured words in GoldenDict-ng's popup through its URL scheme.
@MainActor
final class GoldendictBridge {
    static let shared = GoldendictBridge()

    private static let bundleIdentifier = "org.xiaoyifang"
    private static let fallbackAppPath = "/Applications/GoldenDict-ng.app"

    /// Continuous capture can report the same word repeatedly while the mouse moves.
    private static let debounceInterval: TimeInterval = 1.0
    private var lastQuery: (word: String, date: Date)?

    /// Sends a word to GoldenDict-ng using `goldendict:///<word>?target=popup`.
    /// The word is put in the URL path so non-ASCII text is not converted to an
    /// IDN host by macOS before GoldenDict-ng receives it.
    @discardableResult
    func lookup(word: String, copyToClipboard: Bool) -> Bool {
        let now = Date()
        if let lastQuery,
           lastQuery.word == word,
           now.timeIntervalSince(lastQuery.date) < Self.debounceInterval {
            return true
        }
        self.lastQuery = (word, now)

        if copyToClipboard {
            Self.writeToClipboard(word)
        }

        var components = URLComponents()
        components.scheme = "goldendict"
        components.host = ""
        components.path = "/" + word
        components.queryItems = [URLQueryItem(name: "target", value: "popup")]
        guard let url = components.url else { return false }
        guard NSWorkspace.shared.urlForApplication(withBundleIdentifier: Self.bundleIdentifier) != nil
                || FileManager.default.fileExists(atPath: Self.fallbackAppPath) else {
            return false
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        NSWorkspace.shared.open(url, configuration: configuration) { _, _ in }
        return true
    }

    private static func writeToClipboard(_ word: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(word, forType: .string)
    }
}
