import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: Model
    @State private var tab = 0
    private func t(_ zh: String, _ en: String) -> String {
        let english = model.appLanguage == "en" || (model.appLanguage == "auto" && !(Locale.preferredLanguages.first?.hasPrefix("zh") ?? false))
        return english ? en : zh
    }
    private var divider: some View { Divider().padding(.horizontal, 14).opacity(0.5) }
    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0, content: content)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.background).shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.quaternary, lineWidth: 0.5))
    }
    private func row(_ title: String, _ subtitle: String, _ value: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13)).foregroundStyle(.primary)
                Text(subtitle).font(.system(size: 11)).foregroundStyle(.tertiary)
            }
            Spacer()
            Toggle("", isOn: value).labelsHidden().toggleStyle(.switch).controlSize(.small)
        }.padding(.horizontal, 14).padding(.vertical, 10)
    }
    private func permission(_ icon: String, _ title: String, _ granted: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon).frame(width: 20).foregroundStyle(.secondary)
                Text(title).font(.system(size: 13))
                Spacer()
                Text(granted ? t("已授权", "Granted") : t("需要授权", "Required"))
                    .font(.system(size: 11, weight: .medium)).foregroundStyle(granted ? Color.green : Color.orange)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill((granted ? Color.green : Color.orange).opacity(0.1)))
            }.padding(.horizontal, 14).padding(.vertical, 12).contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
    private func key(_ name: String, _ symbol: String) -> some View {
        Button { model.trigger = name } label: {
            Text(symbol).font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(model.trigger == name ? Color.accentColor : .primary)
                .padding(.vertical, 6).padding(.horizontal, 10)
                .background(RoundedRectangle(cornerRadius: 8).fill(model.trigger == name ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08)))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(model.trigger == name ? Color.accentColor.opacity(0.5) : Color.secondary.opacity(0.2), lineWidth: 1))
        }.buttonStyle(.plain).help(name).accessibilityLabel(name)
    }
    private var keys: some View {
        VStack(spacing: 8) {
            HStack { key("左侧 Shift", "⇧"); Spacer(); Text(t("快捷键选择", "Hotkey")).font(.system(size: 12, weight: .semibold)); Spacer(); key("右侧 Shift", "⇧") }
            HStack(spacing: 6) {
                key("Fn", "Fn"); key("左侧 Control", "⌃"); key("左侧 Option", "⌥"); key("左侧 Command", "⌘")
                Spacer(minLength: 8)
                key("右侧 Command", "⌘"); key("右侧 Option", "⌥"); key("右侧 Control", "⌃")
            }
        }.padding(.horizontal, 14).padding(.vertical, 12)
    }
    private var general: some View {
        ScrollView {
            VStack(spacing: 20) {
                card {
                    permission("rectangle.dashed.badge.record", t("屏幕录制", "Screen Recording"), model.screenGranted) { model.requestScreen() }
                    divider
                    permission("figure.wave", t("辅助功能", "Accessibility"), model.accessibilityGranted) { model.requestAccessibility() }
                }
                card {
                    HStack {
                        Text(t("快捷键类型", "Shortcut Type")).font(.system(size: 13))
                        Spacer()
                        Picker("", selection: $model.hotkeyMode) {
                            Text(t("单键", "Single key")).tag("single")
                            Text(t("组合键", "Combination")).tag("combination")
                        }.pickerStyle(.segmented).labelsHidden().frame(width: 180)
                    }.padding(.horizontal, 14).padding(.vertical, 10)
                    if model.hotkeyMode == "single" { keys }
                    else {
                        HStack {
                            Text(t("取词快捷键", "Lookup Shortcut")).font(.system(size: 13, weight: .medium))
                            Spacer()
                            Button(model.recordingHover ? t("请按组合键…", "Press shortcut…") : model.hoverShortcut) {
                                model.recording = false; model.recordingHover = true; model.configureShortcuts()
                            }
                        }.padding(.horizontal, 14).padding(.vertical, 10)
                    }
                    Text(model.shortcutMessage)
                        .font(.system(size: 11))
                        .foregroundStyle(model.shortcutHasError ? Color.orange : Color.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14).padding(.bottom, 10)
                    divider
                    row(t("连续翻译", "Continuous Translation"), t("按住快捷键移动鼠标时持续查词", "Keep looking up words while moving the pointer"), $model.continuousTranslation)
                    divider
                    row(t("GoldenDict 集成", "GoldenDict Integration"), t("在 GoldenDict-ng 中查询取到的单词", "Look up captured words in GoldenDict-ng"), $model.integration)
                    divider
                    row(t("划词查询", "Selected-Text Lookup"), t("在 GoldenDict-ng 中查询选中的文本", "Look up selected text in GoldenDict-ng"), $model.selectedEnabled)
                    if model.selectedEnabled {
                        HStack {
                            Text(t("划词查询快捷键", "Selection Shortcut")).font(.system(size: 13, weight: .medium))
                            Spacer()
                            Button(model.recording ? t("请按组合键…", "Press shortcut…") : model.selectedShortcut) { model.recordingHover = false; model.recording = true; model.configureShortcuts() }
                        }.padding(.horizontal, 14).padding(.vertical, 8)
                    }
                    divider
                    row(t("复制到剪贴板", "Copy to Clipboard"), t("同时将取到的文字复制到剪贴板", "Also copy the captured text"), $model.copy)
                    divider
                    row(t("调试 OCR 区域", "Show OCR Region"), t("按下快捷键时显示捕获区域", "Show the capture region when the shortcut is held"), $model.debugRegion)
                    divider
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t("识别语言", "Recognition Language")).font(.system(size: 13))
                            Text(t("选择要识别的文字语言", "Choose the language of the text")).font(.system(size: 11)).foregroundStyle(.tertiary)
                        }
                        Spacer()
                        Picker("", selection: $model.language) {
                            ForEach(OCRLanguages.options) { language in
                                Text(verbatim: language.name).tag(language.id)
                            }
                        }.labelsHidden().frame(width: 120)
                    }.padding(.horizontal, 14).padding(.vertical, 10)
                }
                Text(model.status).font(.system(size: 11)).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
            }.padding(16)
        }
    }
    private var system: some View {
        ScrollView {
            VStack(spacing: 20) {
                card {
                    row(t("登录时启动", "Launch at Login"), t("登录时自动启动", "Start automatically when you log in"), Binding(get: { model.loginEnabled }, set: { model.setLogin($0) }))
                    divider
                    row(t("显示菜单栏图标", "Show Menu Bar Icon"), t("在状态栏显示应用图标", "Display app icon in the status bar"), $model.showMenuBar)
                    divider
                    HStack {
                        VStack(alignment: .leading, spacing: 2) { Text(t("菜单栏图标样式", "Menu Bar Icon Style")).font(.system(size: 13)); Text(t("选择自动、黑色或白色渲染", "Choose automatic, black, or white")).font(.system(size: 11)).foregroundStyle(.tertiary) }
                        Spacer()
                        Picker("", selection: $model.iconStyle) { Text(t("自动", "Auto")).tag("auto"); Text(t("黑色", "Black")).tag("black"); Text(t("白色", "White")).tag("white") }.labelsHidden().frame(width: 120)
                    }.padding(.horizontal, 14).padding(.vertical, 10)
                    divider
                    row(t("显示 Dock 图标", "Show Dock Icon"), t("在 Dock 栏显示应用图标", "Display app icon in the Dock"), $model.showDock)
                    divider
                    HStack {
                        VStack(alignment: .leading, spacing: 2) { Text(t("应用语言", "App Language")).font(.system(size: 13)); Text(t("更改应用的显示语言", "Change the display language")).font(.system(size: 11)).foregroundStyle(.tertiary) }
                        Spacer()
                        Picker("", selection: $model.appLanguage) { Text(t("自动", "Automatic")).tag("auto"); Text("简体中文").tag("zh"); Text("English").tag("en") }.labelsHidden().frame(width: 120)
                    }.padding(.horizontal, 14).padding(.vertical, 10)
                }
            }.padding(16)
        }
    }
    var body: some View {
        TabView(selection: $tab) {
            general.tabItem { Label(t("通用", "General"), systemImage: "gear") }.tag(0)
            system.tabItem { Label(t("系统", "System"), systemImage: "gearshape.2") }.tag(1)
        }
        .frame(width: 520, height: 630)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { DispatchQueue.main.async { model.start(); model.refreshPermissions() } }
        .onDisappear {
            // If the user closed the only window, keep a way to reopen settings.
            DispatchQueue.main.async { if !model.showMenuBar { model.showMenuBar = true } }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in model.refreshPermissions() }
        .onChange(of: model.integration) { _, _ in model.configureShortcuts() }
        .onChange(of: model.selectedEnabled) { _, _ in model.configureShortcuts() }
        .onChange(of: model.trigger) { _, _ in model.endHover(); model.configureShortcuts() }
        .onChange(of: model.hotkeyMode) { _, _ in model.endHover(); model.configureShortcuts() }
        .onChange(of: model.debugRegion) { _, enabled in if !enabled { model.hideDebugRegion() } }
        .onChange(of: model.continuousTranslation) { _, _ in model.updateContinuousTimer() }
        .onChange(of: model.showDock) { _, value in
            if !value && !model.showMenuBar { model.showMenuBar = true }
            NSApp.setActivationPolicy(value ? .regular : .accessory)
        }
        .onChange(of: model.showMenuBar) { _, value in if !value && !model.showDock { model.showDock = true } }
    }
}
