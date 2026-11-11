import AppKit
import SwiftUI
import Vision
import ScreenCaptureKit
import ApplicationServices
import ServiceManagement
import Carbon

@MainActor final class Model: ObservableObject {
    static let shared = Model()
    @AppStorage("trigger") var trigger = "右侧 Option"
    @AppStorage("hotkeyMode") var hotkeyMode = "single"
    @AppStorage("hoverKeyCode") var hoverKeyCode = 49
    @AppStorage("hoverFlags") var hoverFlags = Int(NSEvent.ModifierFlags.control.rawValue | NSEvent.ModifierFlags.option.rawValue)
    @AppStorage("hoverShortcut") var hoverShortcut = "⌃ ⌥ SPACE"
    @AppStorage("continuousTranslation") var continuousTranslation = true
    @Published var recordingHover = false
    @AppStorage("integration") var integration = true
    @AppStorage("selectedEnabled") var selectedEnabled = true
    @AppStorage("selectedShortcut") var selectedShortcut = "⌥ Q"
    @AppStorage("selectedKeyCode") var selectedKeyCode = 12
    @AppStorage("selectedFlags") var selectedFlags = Int(NSEvent.ModifierFlags.option.rawValue)
    @Published var recording = false
    @AppStorage("language") var language = "en-US"
    @AppStorage("showMenuBar") var showMenuBar = true
    @AppStorage("showDock") var showDock = false
    @AppStorage("iconStyle") var iconStyle = "auto"
    @AppStorage("appLanguage") var appLanguage = "auto"
    @AppStorage("debugRegion") var debugRegion = false
    @Published var loginEnabled = SMAppService.mainApp.status == .enabled
    private var debugPanel: NSPanel?
    private var debugHostingView: NSHostingView<DebugOCRBorderView>?
    @AppStorage("copy") var copy = false
    @Published var status = "就绪"
    @Published var shortcutMessage = ""
    @Published var shortcutHasError = false
    private var selectionListenerStatus: SelectedTextLookupShortcutStatus = .disabled
    private var hoverListenerStatus: SelectedTextLookupShortcutStatus = .disabled
    private let ocr = OCRService()
    private let selection = SelectedTextService()
    private var monitor: Any?
    private var localMonitor: Any?
    private let selectionMonitor = SelectedTextLookupShortcutMonitor()
    private let hoverMonitor = SelectedTextLookupShortcutMonitor()
    private var timer: Timer?
    private var running = false
    private var held = false
    private var hoverGeneration: UInt64 = 0
    private var previousPoint: CGPoint?
    private var lastWord = ""
    private var lastDate = Date.distantPast
    static let modifierCodes: [String: UInt16] = ["左侧 Shift":56, "右侧 Shift":60, "左侧 Control":59, "右侧 Control":62, "左侧 Option":58, "右侧 Option":61, "左侧 Command":55, "右侧 Command":54, "Fn":63]
    func setLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginEnabled = SMAppService.mainApp.status == .enabled
            status = loginEnabled == enabled ? "登录启动设置已更新" : "请在系统设置中确认登录启动"
        } catch { loginEnabled = SMAppService.mainApp.status == .enabled; status = "登录启动设置失败：\(error.localizedDescription)" }
    }
    func showRegion(_ rect: CGRect, wordBoxes: [CGRect] = []) {
        if debugPanel == nil {
            let panel = NSPanel(contentRect: rect, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
            panel.level = .statusBar; panel.ignoresMouseEvents = true
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            let view = NSHostingView(rootView: DebugOCRBorderView(wordBoxes: []))
            panel.contentView = view; debugHostingView = view; debugPanel = panel
        }
        debugHostingView?.rootView = DebugOCRBorderView(wordBoxes: wordBoxes)
        debugPanel?.setFrame(rect, display: true); debugPanel?.orderFrontRegardless()
    }
    func hideDebugRegion() { debugPanel?.orderOut(nil) }
    func start() {
        guard monitor == nil else { return }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self else { return event }
            if event.type == .flagsChanged {
                self.handle(event)
                return event
            }
            guard self.recording || self.recordingHover else { return event }
            if event.keyCode == 53 {
                self.recording = false; self.recordingHover = false; self.configureShortcuts()
                return nil
            }
            let flags = event.modifierFlags.intersection([.command,.option,.control,.shift])
            guard !flags.isEmpty, let serialized = SelectedTextLookupShortcut.serialized(keyCode: event.keyCode, flags: CGEventFlags(rawValue: UInt64(flags.rawValue))) else {
                self.shortcutMessage = "设置失败：请按修饰键加字母、数字或空格。"; self.shortcutHasError = true; return nil
            }
            let candidateFlags = Int(flags.rawValue)
            let commandQ = event.keyCode == 12 && flags == .command
            let collides = self.integration && self.selectedEnabled && self.hotkeyMode == "combination" &&
                (self.recordingHover ? (Int(event.keyCode) == self.selectedKeyCode && candidateFlags == self.selectedFlags) : (Int(event.keyCode) == self.hoverKeyCode && candidateFlags == self.hoverFlags))
            if commandQ || collides {
                self.recording = false; self.recordingHover = false; self.configureShortcuts()
                self.shortcutHasError = true
                self.shortcutMessage = commandQ ? "设置失败：⌘Q 用于隐藏到状态栏，不能作为取词快捷键。" : "设置失败：取词和划词不能使用同一个组合键，已保留原快捷键。"
                return nil
            }
            let display = SelectedTextLookupShortcut.displayName(for: serialized)
            if self.recordingHover {
                self.hoverKeyCode = Int(event.keyCode); self.hoverFlags = Int(flags.rawValue); self.hoverShortcut = display
            } else {
                self.selectedKeyCode = Int(event.keyCode); self.selectedFlags = Int(flags.rawValue); self.selectedShortcut = display
            }
            self.recording = false; self.recordingHover = false
            self.configureShortcuts()
            return nil
        }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            Task { @MainActor in self?.handle(event) }
        }
        if monitor == nil { status = "快捷键监听失败，请检查辅助功能权限" }
        selectionMonitor.onTrigger = { [weak self] in Task { await self?.lookupSelection() } }
        hoverMonitor.onTrigger = { [weak self] in self?.beginHover() }
        hoverMonitor.onRelease = { [weak self] in self?.endHover() }
        configureShortcuts()
    }
    func configureShortcuts() {
        configureSelectionShortcut()
        configureHoverShortcut()
        updateShortcutFeedback()
    }
    func updateShortcutFeedback() {
        let report = Self.shortcutFeedback(
            integration: integration, selectedEnabled: selectedEnabled, mode: hotkeyMode,
            recording: recording || recordingHover, accessibility: AXIsProcessTrusted(),
            globalMonitorAvailable: monitor != nil, selection: selectionListenerStatus,
            hover: hoverListenerStatus,
            conflict: selectedEnabled && hoverKeyCode == selectedKeyCode && hoverFlags == selectedFlags,
            reserved: (selectedEnabled && Self.isReservedQuitShortcut(keyCode: selectedKeyCode, flags: selectedFlags)) ||
                (hotkeyMode == "combination" && Self.isReservedQuitShortcut(keyCode: hoverKeyCode, flags: hoverFlags))
        )
        shortcutMessage = report.message; shortcutHasError = report.error
    }
    static func shortcutFeedback(integration: Bool, selectedEnabled: Bool, mode: String,
                                 recording: Bool, accessibility: Bool, globalMonitorAvailable: Bool,
                                 selection: SelectedTextLookupShortcutStatus, hover: SelectedTextLookupShortcutStatus,
                                 conflict: Bool, reserved: Bool = false) -> (message: String, error: Bool) {
        if recording { return ("正在录制快捷键，按 Esc 可取消。", false) }
        if !integration { return ("GoldenDict 集成已关闭，快捷键暂不查询。", false) }
        if reserved { return ("快捷键未生效：⌘Q 保留用于隐藏到状态栏，请重新设置。", true) }
        if !accessibility { return ("设置未生效：缺少辅助功能权限，请授权后重试。", true) }
        if mode == "single" && !globalMonitorAvailable { return ("取词快捷键未生效：无法启动全局按键监听。", true) }
        if mode == "combination" && conflict { return ("取词快捷键未生效：与划词快捷键冲突，请更改其中一个。", true) }
        if selectedEnabled && selection != .listening {
            return (selection == .invalidShortcut ? "划词快捷键未生效：快捷键无效。" : "划词快捷键未生效：系统拒绝创建监听器，请检查辅助功能权限或快捷键冲突。", true)
        }
        if mode == "combination" && hover != .listening {
            return (hover == .invalidShortcut ? "取词快捷键未生效：快捷键无效。" : "取词快捷键未生效：系统拒绝创建监听器，请检查辅助功能权限或快捷键冲突。", true)
        }
        return ("快捷键设置已应用。", false)
    }
    static func isReservedQuitShortcut(keyCode: Int, flags: Int) -> Bool {
        keyCode == 12 && flags == Int(NSEvent.ModifierFlags.command.rawValue)
    }
    func configureHoverShortcut() {
        if hotkeyMode == "combination" && Self.isReservedQuitShortcut(keyCode: hoverKeyCode, flags: hoverFlags) {
            hoverMonitor.stop(); hoverListenerStatus = .invalidShortcut; return
        }
        let flags = CGEventFlags(rawValue: UInt64(hoverFlags))
        guard let shortcut = SelectedTextLookupShortcut.serialized(keyCode: UInt16(hoverKeyCode), flags: flags) else { hoverMonitor.stop(); hoverListenerStatus = .invalidShortcut; return }
        let conflict = selectedEnabled && integration && hoverKeyCode == selectedKeyCode && hoverFlags == selectedFlags
        hoverMonitor.onStatusChanged = { [weak self] state in self?.hoverListenerStatus = state }
        hoverMonitor.start(shortcut: shortcut, isEnabled: integration && hotkeyMode == "combination" && !recording && !recordingHover && !conflict, hasAccessibilityPermission: AXIsProcessTrusted())
    }
    func configureSelectionShortcut() {
        if selectedEnabled && Self.isReservedQuitShortcut(keyCode: selectedKeyCode, flags: selectedFlags) {
            selectionMonitor.stop(); selectionListenerStatus = .invalidShortcut; return
        }
        let flags = CGEventFlags(rawValue: UInt64(selectedFlags))
        guard let shortcut = SelectedTextLookupShortcut.serialized(keyCode: UInt16(selectedKeyCode), flags: flags) else { selectionMonitor.stop(); selectionListenerStatus = .invalidShortcut; return }
        selectionMonitor.onStatusChanged = { [weak self] state in self?.selectionListenerStatus = state }
        selectionMonitor.start(shortcut: shortcut, isEnabled: integration && selectedEnabled && !recording && !recordingHover, hasAccessibilityPermission: AXIsProcessTrusted())
    }
    static func isPhysicalKeyPressed(_ key: String, flags: NSEvent.ModifierFlags, fallback: NSEvent.ModifierFlags) -> Bool {
        let masks: [String: Int32] = ["左侧 Shift": NX_DEVICELSHIFTKEYMASK, "右侧 Shift": NX_DEVICERSHIFTKEYMASK, "左侧 Control": NX_DEVICELCTLKEYMASK, "右侧 Control": NX_DEVICERCTLKEYMASK, "左侧 Option": NX_DEVICELALTKEYMASK, "右侧 Option": NX_DEVICERALTKEYMASK, "左侧 Command": NX_DEVICELCMDKEYMASK, "右侧 Command": NX_DEVICERCMDKEYMASK]
        return masks[key].map { flags.rawValue & UInt($0) != 0 } ?? flags.contains(fallback)
    }
    func handle(_ event: NSEvent) {
        if hotkeyMode == "single", !recording, !recordingHover, event.type == .flagsChanged, event.keyCode == Self.modifierCodes[trigger] {
            let flag: NSEvent.ModifierFlags
            switch trigger { case let x where x.contains("Shift"): flag = .shift; case let x where x.contains("Control"): flag = .control; case let x where x.contains("Option"): flag = .option; case let x where x.contains("Command"): flag = .command; default: flag = .function }
            let down = Self.isPhysicalKeyPressed(trigger, flags: event.modifierFlags, fallback: flag)
            if down {
                let others = event.modifierFlags.intersection([.shift, .control, .option, .command]).subtracting(flag)
                if others.isEmpty { beginHover() }
            } else { endHover() }
        }
    }
    func beginHover() {
        guard !held else { return }
        held = true; hoverGeneration &+= 1; previousPoint = nil
        lookupUnderPointer()
        updateContinuousTimer()
    }
    func endHover() {
        held = false; timer?.invalidate(); timer = nil
        hideDebugRegion()
    }
    var isContinuousTimerRunning: Bool { timer?.isValid == true }
    func updateContinuousTimer() {
        timer?.invalidate(); timer = nil
        guard held && continuousTranslation else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.held, self.continuousTranslation else { return }
                self.lookupUnderPointer()
            }
        }
    }
    static func shouldShowDebugRegion(enabled: Bool, held: Bool, requestGeneration: UInt64, currentGeneration: UInt64) -> Bool {
        enabled && held && requestGeneration == currentGeneration
    }
    func lookupUnderPointer() {
        guard integration, !running else { return }
        let point = NSEvent.mouseLocation
        let requestGeneration = hoverGeneration
        if let old = previousPoint, hypot(old.x-point.x, old.y-point.y) < 5 { return }
        previousPoint = point
        running = true
        Task {
            defer { running = false }
            guard CGPreflightScreenCaptureAccess() else { status = "需要屏幕录制权限"; return }
            guard let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }),
                  let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { status = "无法找到鼠标所在屏幕"; return }
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                guard let display = content.displays.first(where: { $0.displayID == number.uint32Value }) else { status = "无法读取屏幕"; return }
                let width = min(520.0, screen.frame.width), height = min(140.0, screen.frame.height)
                let x = max(screen.frame.minX, min(point.x-width/2, screen.frame.maxX-width))
                let y = max(screen.frame.minY, min(point.y-height/2, screen.frame.maxY-height))
                let rect = CGRect(x:x,y:y,width:width,height:height)
                let config = SCStreamConfiguration()
                config.sourceRect = CGRect(x: rect.minX-screen.frame.minX, y: screen.frame.maxY-rect.maxY, width:width, height:height)
                config.width = Int(width*screen.backingScaleFactor); config.height = Int(height*screen.backingScaleFactor)
                config.showsCursor = false
                let ownPID = ProcessInfo.processInfo.processIdentifier
                let excluded = content.windows.filter { $0.owningApplication?.processID == ownPID }
                let image = try await SCScreenshotManager.captureImage(contentFilter: SCContentFilter(display: display, excludingWindows: excluded), configuration: config)
                if Self.shouldShowDebugRegion(enabled: debugRegion, held: held, requestGeneration: requestGeneration, currentGeneration: hoverGeneration) { showRegion(rect) }
                let words = try await ocr.recognizeWords(in: image, language: language)
                if Self.shouldShowDebugRegion(enabled: debugRegion, held: held, requestGeneration: requestGeneration, currentGeneration: hoverGeneration) { showRegion(rect, wordBoxes: words.map(\.boundingBox)) }
                let normalized = CGPoint(x:(point.x-rect.minX)/width, y:(point.y-rect.minY)/height)
                if let word = OCRService.selectWord(from: words, normalizedPoint: normalized) { send(word.text) }
                else { status = "鼠标下未识别到单词" }
            } catch { status = "取词失败：\(error.localizedDescription)" }
        }
    }
    func lookupSelection() async {
        guard integration else { return }
        guard AXIsProcessTrusted() else { status = "需要辅助功能权限"; return }
        if let result = await selection.currentSelectionSnapshot(mouseLocation: NSEvent.mouseLocation) {
            let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty { send(text); return }
        }
        status = "未读取到选中文本"
    }
    func send(_ text: String) {
        if text == lastWord && Date().timeIntervalSince(lastDate) < 1 { return }
        lastWord = text; lastDate = Date()
        status = GoldendictBridge.shared.lookup(word: text, copyToClipboard: copy) ? "已发送：\(text)" : "未找到 GoldenDict-ng"
    }
    @Published private(set) var accessibilityGranted = AXIsProcessTrusted()
    @Published private(set) var screenGranted = CGPreflightScreenCaptureAccess()
    func refreshPermissions() {
        let ax = AXIsProcessTrusted(), screen = CGPreflightScreenCaptureAccess()
        let changed = accessibilityGranted != ax
        if changed { accessibilityGranted = ax }
        if screenGranted != screen { screenGranted = screen }
        if changed { configureShortcuts() }
    }
    func requestAccessibility() { let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String; _ = AXIsProcessTrustedWithOptions([key:true] as CFDictionary) }
    func requestScreen() { _ = CGRequestScreenCaptureAccess() }
}

final class LiteAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in Model.shared.start() }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        ApplicationLifetime.shouldTerminate()
    }
}
@main struct LiteApp: App {
    @NSApplicationDelegateAdaptor(LiteAppDelegate.self) var delegate
    @StateObject var model = Model.shared
    func statusBarImage(style: String) -> NSImage {
        let source = Bundle.main.url(forResource: "StatusBarIcon", withExtension: "png").flatMap(NSImage.init(contentsOf:)) ?? NSImage(systemSymbolName: "text.magnifyingglass", accessibilityDescription: nil)!
        let size = NSSize(width: 18, height: 18)
        if style == "auto" { let image = (source.copy() as? NSImage) ?? source; image.size = size; image.isTemplate = true; return image }
        let image = NSImage(size: size)
        image.lockFocus(); let rect = NSRect(origin: .zero, size: size)
        source.draw(in: rect); (style == "black" ? NSColor.black : NSColor.white).setFill(); rect.fill(using: .sourceAtop)
        image.unlockFocus(); image.isTemplate = false
        return image
    }
    var body: some Scene {
        MenuBarExtra(isInserted: Binding(
            get: { model.showMenuBar },
            set: { value in
                guard value != model.showMenuBar else { return }
                DispatchQueue.main.async {
                    if value != model.showMenuBar { model.showMenuBar = value }
                }
            }
        )) {
            Text(model.status)
            OpenSettingsMenuButton()
            Button("退出") { ApplicationLifetime.quitFromStatusMenu() }
        } label: {
            Image(nsImage: statusBarImage(style: model.iconStyle))
        }
        Settings { SettingsView(model:model).onAppear { NSApp.activate(ignoringOtherApps:true) } }
        Window("GoldenDict 取词设置", id:"settings") { SettingsView(model:model).onAppear { model.start(); NSApp.setActivationPolicy(model.showDock ? .regular : .accessory) } }
            .commands {
                CommandGroup(replacing: .appTermination) {
                    Button("隐藏到状态栏") { ApplicationLifetime.hideToMenuBar() }
                        .keyboardShortcut("q", modifiers: .command)
                }
            }
    }
}
