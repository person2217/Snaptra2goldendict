import Foundation

/// The same source-language choices shown by the local SnapTra Translator.
/// IDs use the corresponding Vision language identifiers supported by macOS.
struct OCRLanguage: Identifiable {
    let id: String
    let name: String
}

enum OCRLanguages {
    static let options: [OCRLanguage] = [
        .init(id: "zh-Hans", name: "简体中文"),
        .init(id: "zh-Hant", name: "繁體中文"),
        .init(id: "en-US", name: "English"),
        .init(id: "ja-JP", name: "日本語"),
        .init(id: "ko-KR", name: "한국어"),
        .init(id: "fr-FR", name: "Français"),
        .init(id: "de-DE", name: "Deutsch"),
        .init(id: "es-ES", name: "Español"),
        .init(id: "it-IT", name: "Italiano"),
        .init(id: "pt-BR", name: "Português"),
        .init(id: "ru-RU", name: "Русский"),
        .init(id: "ar-SA", name: "العربية"),
        .init(id: "th-TH", name: "ไทย"),
        .init(id: "vi-VT", name: "Tiếng Việt"),
    ]
}
