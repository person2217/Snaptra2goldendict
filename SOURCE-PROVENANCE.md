# 源码与应用备份来源

- 2026-11-11 从当前使用的 GoldenDict-Lite 本地源码目录建立独立 Git 历史。
- 初始提交包含 Package.swift、Sources、Tests、Resources、构建脚本和 Codex
  Run 配置；整理仅增加发布说明、忽略规则及版权来源，不修改应用行为源码。
- 原型时期的 README 保存在 `docs/original-prototype-readme.zh-CN.md`，仅供历史
  参考。当前版本和验证范围以根目录 README 及 Release 清单为准。
- OCRService、OCRLanguages、SelectedTextService、SelectedTextProbeExecutor 及
  快捷键／GoldenDict 桥接的部分实现来自或改编自 yelog/SnapTraTranslator 和
  person2217/Snaptra2goldendict 的定制代码。上游作者 yelog（杨玉杰）保留其版权。
- 本仓库既有 `LICENSE` 对 person2217 发布的修改采用 MIT 声明；此分支沿用该
  文件并保留其上游版权说明，不额外替上游代码声明新的许可证。
- 图标资源来自本地现有项目，按当前文件原样保存，不另行生成或替换。
- Release 应用 ZIP 来自现用 `GoldenDict 取词.app`，版本 0.1／build 1，Bundle ID
  `local.goldendict.lookuphelper`，保留原有本地 ad-hoc 签名。
- 初始备份的现用主程序 SHA-256：
  `63d934145cff729afa655ed2d45bc22210a3def9550d00c851fa2142544addc8`。
- 当前源码通过独立检出重建后，构建结果单独记录。未将重建包替代现用应用备份，
  也不声称两者字节一致。用户设置、授权、词典和运行日志不属于公开源码快照。
