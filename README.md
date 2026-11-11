# GoldenDict 取词

用于把鼠标下的 OCR 文字或选中文字送到 GoldenDict-ng 悬浮窗查询的 macOS
菜单栏应用。此分支保存独立的 GoldenDict 取词程序；仓库的 `main` 与
`sync/1.3.11-beta.3` 分支继续保留 SnapTra Translator 的源码和历史。

## 当前备份版本

版本 **0.1，build 1**，Bundle ID 为 `local.goldendict.lookuphelper`。
`goldendict-lite-v0.1-build1-20261111` 标签保存 2026-11-11 整理的源码快照。
Release 的应用 ZIP 直接来自当时正在使用的 `/Applications/GoldenDict 取词.app`，
保留原有签名；源码独立重建仅用于验证可构建性。构建清单分别记录两份产物，
不声称源码重建与现用应用字节相同。

**已知问题：Ctrl 取词有时会重复发音，仍在排查。此备份版本不包含该问题的修复。**
本程序负责识别和发送查询，没有独立的语音播放功能；通常听到的自动发音由
GoldenDict-ng 取得词典音频后播放。连续取词及重复查询可能触发再次播放，
还需区分查询重复和播放器异步任务重复。

## 安装与使用

适用于 Apple Silicon（arm64）、macOS 14.0 或更新版本，需要另行安装并保留
GoldenDict-ng。本备份使用本地 ad-hoc 签名，未进行 Developer ID 签名或公证。

1. 下载 Release 中的 `GoldenDict-Lookup-0.1-build1-macOS-arm64.zip` 并解压。
2. 如需替换应用，先通过菜单栏的“退出”正常停止旧版，再把解压的
   `GoldenDict 取词.app` 放入“应用程序”。不要覆盖或重签正在运行的应用包。
3. 在设置中确认屏幕录制及辅助功能权限、取词触发键和识别语言。权限由系统
   管理，移动或替换应用后可能需要重新确认。
4. 按住所选修饰键并把指针放在单词上；连续翻译开启时，按住并移动鼠标可持续
   取词。也可先选择文字，再按划词查询快捷键。

首次使用的默认触发键是右侧 Option；用户已有的左侧 Ctrl 等设置保存在本机，
不随源码或 Release 上传。启用集成后，通过
`goldendict:///<文字>?target=popup` 交给 GoldenDict-ng 查询。设置中还可控制
复制到剪贴板、菜单栏／Dock 图标、登录启动和 OCR 区域显示。

## 构建

需要完整 Xcode、支持 Swift 6 工具版本的编译器和 macOS SDK。项目是 SwiftPM
可执行程序，Swift 源码以 Swift 5 语言模式编译，无第三方包依赖。

```sh
./script/build_and_run.sh --build-only
```

应用生成在 `dist/GoldenDictLite.app`。省略参数会构建并打开应用；请先正常退出
已有取词程序，避免重复监听快捷键。脚本中的版本和 Bundle ID 与本备份相同。
`.codex/environments/environment.toml` 已提供对应 Run 入口。

测试位于 `Tests/GoldenDictLiteTests`。部分测试会写入 `@AppStorage`，完整测试应在
隔离的偏好设置环境中执行，避免影响日用设置。本次备份仅记录实际完成的构建、
包内容、签名和恢复验证，不把它写成新的完整功能验收。

## 离线恢复与回退

Release 附有源码 bundle、构建／验证清单和 SHA-256 校验文件。在附件所在目录：

```sh
git clone GoldenDict-Lookup-source.bundle recovered-source
git -C recovered-source switch goldendict-lite
```

恢复旧应用时，正常退出当前版本，再用本备份 ZIP 中的应用替换。Release 不包含
用户设置、系统授权、词典或 GoldenDict-ng 本体；如需保留特定设置，应另做本地
备份。升级后的设置应在回退前另存。

## 来源

OCR、选中文字及快捷键的部分实现来自或改编自
[yelog/SnapTraTranslator](https://github.com/yelog/SnapTraTranslator) 及本仓库的
SnapTra 定制代码，保留上游作者 yelog（杨玉杰）的来源说明。精简程序另行实现
取词调度、设置界面和 GoldenDict URL 桥接，详见 [SOURCE-PROVENANCE.md](SOURCE-PROVENANCE.md)。
`LICENSE` 沿用本仓库对个人修改的 MIT 声明，上游代码保留其原有版权。
