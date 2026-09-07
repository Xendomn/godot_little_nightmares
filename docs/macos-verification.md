# Apple Silicon macOS 验证

2026-09-07，Apple M4 / macOS 15.7.9 / Godot `4.7.2.stable.official.ed1daf0bf`。目标是 Apple Silicon 本机导出与运行。

## 兼容性修复与导出

- 原工程的 GDScript、资源路径、输入映射和 `user://` 存档可在 macOS 运行，无需修改游戏逻辑。
- 实际导出发现缺少 ETC2/ASTC 导入配置，Godot 明确拒绝 arm64／Universal 导出。已在 `project.godot` 启用 `textures/vram_compression/import_etc2_astc=true`，重新导入后通过；Windows 预设及 S3TC/BPTC 配置保留。
- 官方 4.7.2 的 `macos.zip` 仅含 Universal 模板。直接选择 `arm64` 会报缺少 `godot_macos_release.arm64`，因此最终预设采用 `universal`，包含 arm64 与 x86_64；本次只验收 arm64。参见 [官方架构说明](https://docs.godotengine.org/en/4.7/classes/class_editorexportplatformmacos.html#class-editorexportplatformmacos-property-binary-format-architecture)。
- 使用 [Godot 官方 4.7.2 Standard 模板](https://godotengine.org/download/archive/4.7.2-stable/) 中的 `macos.zip`，安装到 Godot 标准 `export_templates/4.7.2.stable/` 目录。
- 导出产物为 `build/MidnightWorkshop.app`，Bundle ID `local.midnightworkshop.game`，版本 `2.0.0`，内置 ad-hoc 签名、公证关闭。最低系统版本声明为 13.0，与本次使用的 Metal 后端要求一致；这不代表已测试所有 13.0 及以上系统版本。

## 验证结果

| 检查 | 结果 |
|---|---|
| 新入口 `bash tools/verify.sh` | 20 套全部通过，326 条 `PASS:`，无引擎／脚本错误 |
| Bash 3.2 验证入口的失败处理 | 非零退出、引擎日志报错、stderr 报错、缺日志、旧日志、缺 Godot 均拒绝成功；路径含空格、从工程外调用正常 |
| 原生窗口测试 | `test_campaign_ui.gd`、`test_gameplay.gd -- --visual`、`test_routes.gd`、`test_crouch_render.gd` 全部通过 |
| 正式导出 | `--export-release macOS build/MidnightWorkshop.app` 退出码 0，无导出错误 |
| 架构 | `lipo -archs` 返回 `x86_64 arm64` |
| 签名 | `codesign --verify --deep --strict` 通过，签名为 ad-hoc |
| 独立发布版启动 | 用 `ditto` 复制整个 `.app` 到临时独立目录，从该目录用 `arch -arm64` 运行包内程序，Metal 3.2／Forward+ 启动，120 帧后退出码 0 |
| 导出资源包测试 | 匹配版本 Godot 加载应用内原始 PCK；四章加载、原始键盘输入、暂停、环境音播放状态及隔离检查点写入通过 |
| 跨进程恢复 | 第二个进程加载同一 PCK 并继续旅程，恢复钟楼检查点 2，通过后删除测试存档 |
| 图片检查 | 检查四章导出资源截图，中文、模型、材质和界面可见，无明显缺失 |

326 是日志中 `PASS:` 的统计数；部分原有套件只以退出状态及失败汇总报告结果，因此其 `checks` 为 0 不等于没有测试。

独立发布版启动没有传 `--path`：官方 release 模板禁用路径覆盖，该参数会导致拒绝启动。尝试让 release 模板执行外部验证脚本时启动超时，因此进一步的自动输入／存档测试使用同版本 Godot 加载**原始导出 PCK**，没有改动应用包。这两类验证分别记录，不能将资源包测试描述为在发布版可执行文件中完成了全部操作。

## 复现与证据

首次运行先按 README 安装匹配模板，然后在工程根目录执行：

```bash
export PATH="/Applications/Godot.app/Contents/MacOS:$PATH"
godot --headless --path . --editor --import --quit
bash tools/verify.sh
godot --path . --fixed-fps 60 --script tests/test_campaign_ui.gd
godot --path . --fixed-fps 60 --script tests/test_gameplay.gd -- --visual
godot --path . --fixed-fps 60 --script tests/test_routes.gd
godot --path . --fixed-fps 60 --script tests/test_crouch_render.gd
mkdir -p build
godot --headless --path . --export-release macOS build/MidnightWorkshop.app
codesign --verify --deep --strict --verbose=2 build/MidnightWorkshop.app
lipo -archs "build/MidnightWorkshop.app/Contents/MacOS/午夜工坊 · Midnight Workshop"
arch -arm64 "build/MidnightWorkshop.app/Contents/MacOS/午夜工坊 · Midnight Workshop" --quit-after 120
```

本次本地证据保存在被 Git 忽略的 `artifacts/`，不随源码或应用分发：

- `verification-results.json`、`verify-*.log`：最终工程完整回归。
- `macos-visual-*.log`：原生图形测试日志。
- `macos-export-before-fix.log`、`macos-export-arm64-template-error.log`：两次导出失败的原始证据。
- `macos-export.log`、`macos-standalone-launch.log`：最终导出及独立发布版启动。
- `macos-pack-write.log`、`macos-pack-resume.log`：导出 PCK 的 18 项初次检查、5 项第二进程检查；临时驱动为 `macos-export-smoke.gd`，使用独立的 `user://macos-export-smoke.json`。
- `macos-export-chapter-0.png` 至 `macos-export-chapter-3.png`：四章截图。
- `macos-release.json`：环境、可执行文件和 PCK 的大小及 SHA-256。

## 验证边界

没有进行 Intel、其他 macOS 版本、实体手柄 USB／蓝牙、完整人工通关、人工听音和性能基准验收。输入由测试脚本注入，音频检查只确认资源与播放状态。窗口自动化工具超时，不能据此声称完成了 Finder 双击和人工键盘操作验收。原 Windows RTX 3070 的性能数字不适用于本机。此次不包含 Developer ID、公证、App Store 或公开分发流程。
