# Snaptra2goldendict

SnapTraTranslator 的本地定制版：划词 / 取词后，直接把单词送入 **GoldenDict-ng** 查词，支持全屏视频场景下的取词。

> 本仓库代码基于 [yelog/SnapTraTranslator](https://github.com/yelog/SnapTraTranslator) 修改定制，原项目版权归原作者所有。

## 功能

- 划词翻译（可自定义快捷键）
- 按住查词热键取词，并调用 GoldenDict-ng 查词
- 仅复制单词（取词后只写入剪贴板，不弹出翻译面板）
- 全屏视频场景取词不会打断全屏
- 历史记录自动保存，支持批量导出

## 安装

从 [Releases](../../releases/latest) 下载 `Snaptra2goldendict.dmg`，打开后把 `Snaptra2goldendict.app` 拖入“应用程序”即可。

首次使用请到“系统设置 → 隐私与安全性”中授予辅助功能 / 屏幕录制等权限。

## 构建

需要 macOS 13+ 与 Xcode。

```bash
xcodebuild -project "SnapTra Translator.xcodeproj" -scheme "SnapTra Translator" -configuration Release build
```

构建产物位于 `DerivedData/.../Build/Products/Release/SnapTra Translator.app`，可自行重命名为 `Snaptra2goldendict.app`。

## 致谢

感谢以下开源项目与作者：

- **[GoldenDict](https://goldendict.org/)** — 经典开源词典软件
- **[GoldenDict-ng](https://github.com/xiaoyifang/goldendict-ng)** — GoldenDict 的现代化维护版本，本项目的主要查词后端
- **[SnapTraTranslator](https://github.com/yelog/SnapTraTranslator)** — 本项目的上游，感谢原作者 yelog 的开源贡献

## 许可证

[MIT](LICENSE)（上游 SnapTraTranslator 无许可证文件，本仓库以 MIT 发布，代码版权与归属见 LICENSE）。
