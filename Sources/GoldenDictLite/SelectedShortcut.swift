import AppKit
import Carbon
import Combine
import Foundation
import OSLog

struct SelectedTextLookupShortcut: Equatable {
    let keyCode: UInt16
    let modifiers: CGEventFlags

    static func parse(_ value: String) -> SelectedTextLookupShortcut? {
        let parts = value.lowercased().split(separator: "+").map(String.init)
        guard let key = parts.last, let keyCode = keyCodes[key] else { return nil }

        var modifiers: CGEventFlags = []
        for modifier in parts.dropLast() {
            switch modifier {
            case "option", "alt": modifiers.insert(.maskAlternate)
            case "control", "ctrl": modifiers.insert(.maskControl)
            case "command", "cmd", "⌘": modifiers.insert(.maskCommand)
            case "shift", "⇧": modifiers.insert(.maskShift)
            default: return nil
            }
        }
        guard !modifiers.isEmpty else { return nil }
        return SelectedTextLookupShortcut(keyCode: keyCode, modifiers: modifiers)
    }

    func matches(_ event: CGEvent) -> Bool {
        guard event.getIntegerValueField(.keyboardEventKeycode) == Int64(keyCode) else { return false }
        let relevantFlags = event.flags.intersection([.maskAlternate, .maskControl, .maskCommand, .maskShift])
        return relevantFlags == modifiers
    }

    static func serialized(keyCode: UInt16, flags: CGEventFlags) -> String? {
        guard let key = keyCodes.first(where: { $0.value == keyCode })?.key else { return nil }
        let relevantFlags = flags.intersection([.maskAlternate, .maskControl, .maskCommand, .maskShift])
        guard !relevantFlags.isEmpty else { return nil }

        var parts: [String] = []
        if relevantFlags.contains(.maskCommand) { parts.append("command") }
        if relevantFlags.contains(.maskAlternate) { parts.append("option") }
        if relevantFlags.contains(.maskControl) { parts.append("control") }
        if relevantFlags.contains(.maskShift) { parts.append("shift") }
        parts.append(key)
        return parts.joined(separator: "+")
    }

    static func displayName(for value: String) -> String {
        value.split(separator: "+").map { part in
            switch part.lowercased() {
            case "command", "cmd": return "⌘"
            case "option", "alt": return "⌥"
            case "control", "ctrl": return "⌃"
            case "shift": return "⇧"
            default: return part.uppercased()
            }
        }.joined(separator: " ")
    }

    private static let keyCodes: [String: UInt16] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7,
        "c": 8, "v": 9, "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16,
        "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23,
        "=": 24, "9": 25, "7": 26, "-": 27, "8": 28, "0": 29,
        "o": 31, "u": 32, "[": 33, "i": 34, "p": 35, "l": 37, "j": 38,
        "'": 39, "k": 40, ";": 41, "\\": 42, ",": 43, "/": 44, "n": 45,
        "m": 46, ".": 47, "space": 49,
    ]
}

enum SelectedTextLookupShortcutStatus: Equatable {
    case disabled
    case listening
    case needsAccessibility
    case invalidShortcut
    case eventTapUnavailable
}

@MainActor
final class SelectedTextLookupShortcutMonitor {
    var onTrigger: (() -> Void)?
    var onRelease: (() -> Void)?
    private var isPressed = false
    var onStatusChanged: ((SelectedTextLookupShortcutStatus) -> Void)?
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "SnapTraTranslator",
        category: "SelectedTextLookupShortcut"
    )

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var shortcut: SelectedTextLookupShortcut?

    func start(shortcut: String, isEnabled: Bool, hasAccessibilityPermission: Bool) {
        stop()
        guard isEnabled else { return }
        guard hasAccessibilityPermission else {
            onStatusChanged?(.needsAccessibility)
            Self.logger.notice("Shortcut disabled: accessibility permission unavailable")
            return
        }
        guard let parsedShortcut = SelectedTextLookupShortcut.parse(shortcut) else {
            onStatusChanged?(.invalidShortcut)
            return
        }
        self.shortcut = parsedShortcut

        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { _, type, event, userInfo in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<SelectedTextLookupShortcutMonitor>
                    .fromOpaque(userInfo)
                    .takeUnretainedValue()
                return MainActor.assumeIsolated {
                    monitor.handleTapEvent(type: type, event: event)
                }
            },
            userInfo: context
        ) else {
            self.shortcut = nil
            onStatusChanged?(.eventTapUnavailable)
            Self.logger.error("Could not create the selected-text shortcut event tap")
            return
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0) else {
            self.shortcut = nil
            CFMachPortInvalidate(eventTap)
            onStatusChanged?(.eventTapUnavailable)
            return
        }
        self.eventTap = eventTap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        onStatusChanged?(.listening)
        Self.logger.info("Shortcut listener active: \(shortcut, privacy: .public)")
    }

    func stop() {
        if isPressed { isPressed = false; onRelease?() }
        shortcut = nil
        onStatusChanged?(.disabled)
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }
    }

    private func handleTapEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if isPressed { isPressed = false; DispatchQueue.main.async { [weak self] in self?.onRelease?() } }
            if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard let shortcut else { return Unmanaged.passUnretained(event) }
        if type == .flagsChanged, isPressed {
            let relevant = event.flags.intersection([.maskAlternate, .maskControl, .maskCommand, .maskShift])
            if !relevant.isSuperset(of: shortcut.modifiers) {
                isPressed = false
                DispatchQueue.main.async { [weak self] in self?.onRelease?() }
            }
            return Unmanaged.passUnretained(event)
        }
        if type == .keyUp, onRelease != nil,
           event.getIntegerValueField(.keyboardEventKeycode) == Int64(shortcut.keyCode), isPressed {
            isPressed = false
            DispatchQueue.main.async { [weak self] in self?.onRelease?() }
            return nil
        }
        guard type == .keyDown, shortcut.matches(event) else { return Unmanaged.passUnretained(event) }
        guard event.getIntegerValueField(.keyboardEventAutorepeat) == 0 else { return nil }
        if onRelease != nil { isPressed = true }
        DispatchQueue.main.async { [weak self] in self?.onTrigger?() }
        return nil
    }
}

