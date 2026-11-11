import XCTest
import AppKit
import CoreGraphics
import Carbon
import Vision
@testable import GoldenDictLite

final class LookupTests: XCTestCase {
    func testOptionQRequiresCorrectKeyAndModifiers() throws {
        let shortcut = try XCTUnwrap(SelectedTextLookupShortcut.parse("option+q"))
        let source = CGEventSource(stateID: .hidSystemState)
        let event = try XCTUnwrap(CGEvent(keyboardEventSource: source, virtualKey: 12, keyDown: true))
        event.flags = .maskAlternate
        XCTAssertTrue(shortcut.matches(event))
        event.flags = .maskControl
        XCTAssertFalse(shortcut.matches(event))
        event.flags = [.maskAlternate, .maskShift]
        XCTAssertFalse(shortcut.matches(event))
        XCTAssertEqual(SelectedTextLookupShortcut.serialized(keyCode: 12, flags: .maskAlternate), "option+q")
    }
    @MainActor func testLeftAndRightControlAreDistinguished() {
        let left = NSEvent.ModifierFlags(rawValue: NSEvent.ModifierFlags.control.rawValue | UInt(NX_DEVICELCTLKEYMASK))
        let right = NSEvent.ModifierFlags(rawValue: NSEvent.ModifierFlags.control.rawValue | UInt(NX_DEVICERCTLKEYMASK))
        XCTAssertTrue(Model.isPhysicalKeyPressed("左侧 Control", flags: left, fallback: .control))
        XCTAssertFalse(Model.isPhysicalKeyPressed("左侧 Control", flags: right, fallback: .control))
        XCTAssertFalse(Model.isPhysicalKeyPressed("左侧 Control", flags: [], fallback: .control))
    }
    @MainActor func testEverySingleModifierKeyMappingAndPressRelease() {
        let cases: [(String, UInt16, UInt, NSEvent.ModifierFlags)] = [
            ("左侧 Shift", 56, UInt(NX_DEVICELSHIFTKEYMASK), .shift),
            ("右侧 Shift", 60, UInt(NX_DEVICERSHIFTKEYMASK), .shift),
            ("左侧 Control", 59, UInt(NX_DEVICELCTLKEYMASK), .control),
            ("右侧 Control", 62, UInt(NX_DEVICERCTLKEYMASK), .control),
            ("左侧 Option", 58, UInt(NX_DEVICELALTKEYMASK), .option),
            ("右侧 Option", 61, UInt(NX_DEVICERALTKEYMASK), .option),
            ("左侧 Command", 55, UInt(NX_DEVICELCMDKEYMASK), .command),
            ("右侧 Command", 54, UInt(NX_DEVICERCMDKEYMASK), .command),
            ("Fn", 63, NSEvent.ModifierFlags.function.rawValue, .function)
        ]
        for (name, code, mask, fallback) in cases {
            XCTAssertEqual(Model.modifierCodes[name], code, name)
            let pressed = NSEvent.ModifierFlags(rawValue: mask | fallback.rawValue)
            XCTAssertTrue(Model.isPhysicalKeyPressed(name, flags: pressed, fallback: fallback), name)
            XCTAssertFalse(Model.isPhysicalKeyPressed(name, flags: [], fallback: fallback), name)
        }
    }
    func testConfiguredHoverCombinationAndSelectionConflictInputs() throws {
        let encoded = try XCTUnwrap(SelectedTextLookupShortcut.serialized(keyCode: 49, flags: [.maskControl, .maskAlternate]))
        XCTAssertEqual(encoded, "option+control+space")
        let shortcut = try XCTUnwrap(SelectedTextLookupShortcut.parse(encoded))
        let event = try XCTUnwrap(CGEvent(keyboardEventSource: nil, virtualKey: 49, keyDown: true))
        event.flags = [.maskControl, .maskAlternate]
        XCTAssertTrue(shortcut.matches(event))
        event.flags = .maskAlternate
        XCTAssertFalse(shortcut.matches(event))
    }
    @MainActor func testContinuousTimerOnlyRunsWhileHeldAndEnabled() {
        let model = Model()
        model.integration = false
        model.continuousTranslation = false
        model.beginHover()
        XCTAssertFalse(model.isContinuousTimerRunning)
        model.continuousTranslation = true
        model.updateContinuousTimer()
        XCTAssertTrue(model.isContinuousTimerRunning)
        model.continuousTranslation = false
        model.updateContinuousTimer()
        XCTAssertFalse(model.isContinuousTimerRunning)
        model.continuousTranslation = true
        model.updateContinuousTimer()
        model.endHover()
        XCTAssertFalse(model.isContinuousTimerRunning)
        model.updateContinuousTimer()
        XCTAssertFalse(model.isContinuousTimerRunning)
    }
    func testAllSnapTraLanguagesAreRecognizedBySystemVision() throws {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        let supported = Set(try request.supportedRecognitionLanguages())
        XCTAssertEqual(OCRLanguages.options.count, 14)
        XCTAssertEqual(Set(OCRLanguages.options.map(\.id)).count, 14)
        for language in OCRLanguages.options {
            XCTAssertTrue(supported.contains(language.id), "Unsupported language: \(language.name) (\(language.id))")
        }
    }
    @MainActor func testDebugRegionOnlyAppearsForCurrentHeldLookup() {
        XCTAssertTrue(Model.shouldShowDebugRegion(enabled: true, held: true, requestGeneration: 3, currentGeneration: 3))
        XCTAssertFalse(Model.shouldShowDebugRegion(enabled: true, held: false, requestGeneration: 3, currentGeneration: 3))
        XCTAssertFalse(Model.shouldShowDebugRegion(enabled: false, held: true, requestGeneration: 3, currentGeneration: 3))
        XCTAssertFalse(Model.shouldShowDebugRegion(enabled: true, held: true, requestGeneration: 2, currentGeneration: 3))
    }
    @MainActor func testShortcutFeedbackReportsConflictsAndFailures() {
        func check(_ trusted: Bool, _ selection: SelectedTextLookupShortcutStatus, _ hover: SelectedTextLookupShortcutStatus, conflict: Bool = false) -> (message: String, error: Bool) {
            Model.shortcutFeedback(integration: true, selectedEnabled: true, mode: "combination", recording: false,
                                   accessibility: trusted, globalMonitorAvailable: true,
                                   selection: selection, hover: hover, conflict: conflict)
        }
        XCTAssertTrue(check(false, .needsAccessibility, .needsAccessibility).message.contains("辅助功能"))
        XCTAssertTrue(check(true, .listening, .disabled, conflict: true).message.contains("冲突"))
        XCTAssertTrue(check(true, .eventTapUnavailable, .listening).message.contains("划词"))
        XCTAssertTrue(check(true, .listening, .eventTapUnavailable).message.contains("取词"))
        XCTAssertFalse(check(true, .listening, .listening).error)
    }
    @MainActor func testCommandQIsReservedFromLookupShortcuts() {
        XCTAssertTrue(Model.isReservedQuitShortcut(keyCode: 12, flags: Int(NSEvent.ModifierFlags.command.rawValue)))
        XCTAssertFalse(Model.isReservedQuitShortcut(keyCode: 12, flags: Int(NSEvent.ModifierFlags.option.rawValue)))
    }
    @MainActor func testOnlyStatusMenuExitPermitsTermination() {
        XCTAssertEqual(ApplicationLifetime.terminationDecision(explicitStatusMenuExit: false), .terminateCancel)
        XCTAssertEqual(ApplicationLifetime.terminationDecision(explicitStatusMenuExit: true), .terminateNow)
    }
    func testDebugBoxCoordinatesUseVisionBottomLeftOrigin() {
        let box = CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.1)
        let rect = DebugOCRBorderView.convert(box, in: CGSize(width: 500, height: 200))
        XCTAssertEqual(rect.minX, 50, accuracy: 0.001)
        XCTAssertEqual(rect.minY, 140, accuracy: 0.001)
        XCTAssertEqual(rect.width, 150, accuracy: 0.001)
        XCTAssertEqual(rect.height, 20, accuracy: 0.001)
    }
    func testSelectsWordUnderCursorAndRejectsDistantPoint() {
        let word = RecognizedWord(text: "hello", boundingBox: CGRect(x: 0.2, y: 0.3, width: 0.2, height: 0.15))
        XCTAssertEqual(OCRService.selectWord(from: [word], normalizedPoint: CGPoint(x: 0.3, y: 0.35))?.text, "hello")
        XCTAssertNil(OCRService.selectWord(from: [word], normalizedPoint: CGPoint(x: 0.8, y: 0.8)))
    }
    func testRealVisionOCRRecognizesEnglishWord() async throws {
        let image = NSImage(size: NSSize(width: 600, height: 150), flipped: false) { rect in
            NSColor.white.setFill(); rect.fill()
            let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 68, weight: .bold), .foregroundColor: NSColor.black]
            ("hello" as NSString).draw(at: NSPoint(x: 50, y: 35), withAttributes: attributes)
            return true
        }
        var rect = CGRect(origin: .zero, size: image.size)
        let cgImage = try XCTUnwrap(image.cgImage(forProposedRect: &rect, context: nil, hints: nil))
        let words = try await OCRService().recognizeWords(in: cgImage, language: "en-US")
        XCTAssertTrue(words.contains(where: { $0.text.lowercased() == "hello" }), "Recognized: \(words.map(\.text))")
    }
}
