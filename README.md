# 午夜工坊 · Midnight Workshop

原创 3D 环境解谜恐怖童话游戏：无面织物精灵穿过四个相连章节，躲开畸形缝纫师，寻找工坊外的晨光。支持 Windows 与 Apple Silicon macOS 本机游玩，单人、无血腥。

## 开始游戏

- Windows：双击 `build/MidnightWorkshop.exe`，或解压 `build/MidnightWorkshop-Windows.zip` 后运行。
- macOS（Apple Silicon）：导出后双击 `build/MidnightWorkshop.app`。首次从源码使用请按下方「macOS 导出与运行」操作；运行导出的应用无需安装 Godot 或 Blender。
- Godot 4.7.2 打开 `project.godot`，按 F5。主场景为 `scenes/main.tscn`。
- 命令行：`godot --path .`。默认窗口 1280×720，界面按 1920×1080 缩放，Forward+；Windows 使用 Vulkan，本次 macOS 实测使用 Metal。

## 操作与进度

| 动作 | 键盘 | Xbox 手柄 |
|---|---|---|
| 左右、有限纵深移动 | WASD 或方向键 | 左摇杆／十字键 |
| 跳跃 | Space | A |
| 奔跑；近处会被听见 | 按住 Shift | 按住 RT |
| 蹲伏；低通道自动保持蹲伏 | 按住 Ctrl | 按住 B |
| 互动／推箱、洗衣车或线轴箱 | E／按住 E 并左右移动 | X／按住 X 并左右移动 |
| 拾取／放置小物件 | E | X |
| 爬梯／松手 | E 进入，W/S 攀爬，Space 松手 | X 进入，左摇杆上下，A 松手 |
| 暂停／继续 | Esc | Menu |
| 菜单确认／返回 | Enter／Esc | A／B |

菜单使用方向键、左摇杆或十字键选择；音量滑块左右调整。提示跟随最近使用的设备切换。游玩时正在使用的手柄断开会暂停，重连后需要主动继续，键盘始终可用。支持 Windows 下 Godot 识别的 Xbox 手柄；本版不含震动、自定义改键或多人分配。实体手柄验收状态见 `docs/controller-verification.md`。

macOS 的 `Ctrl` 指 **Control（⌃）**，不是 Command（⌘）；其余键盘操作相同。macOS 实体手柄尚未验收，自动输入测试不代表 USB／蓝牙硬件兼容性。

每章六组连续机关、九个稳定 ID 检查点，失败自动重生。检查点和已解锁章节保存至 Godot `user://campaign.json`，主菜单可继续旅程或选择已解锁章节。存档写入使用临时文件与备份，主档损坏时尝试恢复备份。音量独立保存在 `user://settings.cfg`。开始新旅程需确认，会清除章节进度，保留音量。

macOS 的 `user://` 位于 `~/Library/Application Support/Godot/app_userdata/午夜工坊 · Midnight Workshop/`，包含 `campaign.json`（及备份）和 `settings.cfg`。

## 四个章节

| 章节 | 主要玩法 |
|---|---|
| 午夜工坊 | 藏匿保险丝、配电切换、反转输送带、压机限位、双路供电、落闸追逐 |
| 染洗间 | 进排水、浮箱定位、连通水槽、阀轮回运、压力旁路、水轮蒸汽 |
| 悬线库 | 双配重、上下托盘、插销回收、竖井货运、铃声诱敌、三段悬桥 |
| 钟楼 | 缺齿传动、离合分流、双组制动、快慢轴、钟面校准、晨光逃生 |

每章首次游玩目标为 15–20 分钟；这属于设计目标，尚未用真人盲测确认。暂停菜单可主动逐级查看三条提示，HUD 只显示当前目标。搬运时不能跑跳或爬梯，需要利用往返货篮；物件可以从插槽取回重复使用。按住互动键时，左右移动既能推也能拉。

存档已升级为 v2，记录机关、松散物件、插槽和搬运状态。首次读取旧版存档会保留已解锁章节和当前章节，将旧文件存为 `campaign.json.v1.bak`，从该章入口开始，并显示迁移提示。

## 工程与原创素材

- `scenes/main.tscn`：持久化章节管理器，只加载当前一章。
- `scenes/chapters/full/`：四章与 24 个独立房间场景；旧章节保留为回归测试场景；`scenes/actors/`：共用角色、镜头、界面、声音。
- `resources/levels/`：章节顺序、场景地址、镜头边界和检查点定义。
- `scripts/campaign/`：存档与切换；`scripts/puzzles/`：完整章节、机关条件、搬运与场景搭建；`campaign_content.gd` 是房间数据源。
- `assets/models/`：原创 GLB。主角 19,296 三角形、12 段动画；怪物 32,044 三角形、7 段动画。
- `assets/sources/`：Blender 源文件、新版角色预览；`assets/textures/characters/`：原创 2K 布料纹理。
- `assets/audio/`：14 个原创合成 WAV，含三章氛围、怪物空间呼吸、布料和重脚步。

角色使用 Skeleton3D、AnimationPlayer、AnimationTree 和轻量 SpringBone 布料摆动。蹲伏通过骨骼完成，不缩放整个模型。第三方来源见 `docs/asset-sources.md`，新版角色细节见 `docs/character-v2-report.md`。

## 验证与重建

Windows：

```powershell
powershell -ExecutionPolicy Bypass -File tools/verify.ps1
python tests/test_builder.py
```

macOS（先按下方说明安装 Godot 并导入资源）：

```bash
bash tools/verify.sh
# Godot 不在 PATH 时，可指定完整路径（支持路径中的空格）：
GODOT="/Applications/Godot.app/Contents/MacOS/Godot" bash tools/verify.sh
```

脚本兼容 macOS 自带 Bash 3.2，可从任意工作目录通过完整脚本路径调用。失败返回非零状态，检查引擎日志和标准输出／错误；只有全部通过才生成 `artifacts/verification-results.json`。重建验证 `python3 tests/test_builder.py` 会重新生成场景，应在临时工程副本中运行。

33 套无界面验证的日志保存在 `artifacts/`，存档测试使用隔离文件。蹲伏与绕桌修复记录见 `docs/crouch-navigation-verification.md`。机关实物更新见 `docs/mechanical-props-verification.md`。道路碰撞、梯子衔接及中文提示修复见 [验证记录](docs/room-repairs-verification.md)。压力板、机关反馈和连续通关验证见 [通关引导修复记录](docs/puzzle-guidance-verification.md)。窗口路线与性能检查：

```powershell
godot --path . --resolution 1920x1080 --script tests/test_routes.gd
godot --path . --resolution 1920x1080 --script tests/test_campaign_ui.gd
godot --path . --resolution 1920x1080 --script tests/benchmark_full_campaign.gd
godot --path . --fixed-fps 60 --script tests/test_full_routes.gd
godot --path . --fixed-fps 60 --script tests/test_crouch_render.gd
godot --path . --fixed-fps 60 --script tests/test_controller_ui.gd
godot --path . --fixed-fps 60 --script tests/test_routes.gd -- --controller
blender --background --python-exit-code 1 --python tests/check_crouch_mesh.py
```

重建素材与场景会覆盖相应手工修改，须依次执行：

```powershell
blender --background --python tools/create_assets.py
blender --background --python tools/create_characters_v2.py
blender --background --python tools/create_mechanical_props.py
python tools/create_expansion_audio.py
python tools/create_prop_audio.py
blender --background --python tools/create_expansion_kit.py
blender --background --python assets/sources/expansion/create_interaction_animations.py
godot --headless --path . --editor --import --quit
godot --headless --path . --script tools/build_prop_scenes.gd
godot --headless --path . --script tools/build_scene.gd
godot --headless --path . --script tools/build_expansion.gd
godot --headless --path . --script tools/build_full_campaign.gd
```

新增 23 件 Blender 原创机械道具、角色搬运／攀爬动画、CC0 木材贴图和七个机械音效；[素材来源与复现说明](docs/production/expansion-assets.md)。LIMBO、INSIDE 官方截图仅作视觉参考，不进入游戏导出。新关卡验证见 [扩充验收记录](docs/production/full-campaign-verification.md)。

旧素材生成器会覆盖角色，之后必须运行 v2 生成器。运行现有工程无需 Blender 或重新生成。

四章的功能文字占位已替换为 19 件原创机械道具，包括阀门、铃铛、绞盘、配电箱、压板、推车和各章出口。道具提供活动部件、共享 PBR 材质、机械音效及检查点状态恢复；模型与 Blender 源文件见 `assets/models/props/`、`assets/sources/props/`，详细清单见 `docs/mechanical-assets.md`。

## 一键导出

脚本检查已安装的 **Godot 4.7.2.stable** 和导出模板，自动导入资源、导出 Release、校验程序并生成 ZIP。无需 Python 或 Blender，不联网下载依赖，也不会自动启动游戏。可从任意目录用完整脚本路径运行，路径支持空格和中文。

### macOS

准备下节说明的 Godot 和 Standard 导出模板，确保以下文件存在：

```text
~/Library/Application Support/Godot/export_templates/4.7.2.stable/macos.zip
```

双击 `tools/export_macos.command`，或在工程根目录运行：

```bash
bash tools/export_macos.command
# 手动指定编辑器路径：
GODOT="/Applications/Godot.app/Contents/MacOS/Godot" bash tools/export_macos.command
```

默认先查找 PATH 中的 `godot`，再尝试 `/Applications/Godot.app`；设置 `GODOT` 后严格使用指定位置。架构检查使用 `lipo`，需要可用的 Apple Command Line Tools（或 Xcode）；缺少工具时按脚本提示准备。其他打包工具为 macOS 自带的 `codesign`、`ditto`、`unzip`。

输出：`build/MidnightWorkshop.app`（Universal）与 `build/MidnightWorkshop-macOS.zip`。ZIP 会解压复核程序和 PCK 内容，并再次校验应用签名。

### Windows PowerShell

准备 Godot 4.7.2 Standard Windows 编辑器，并将同版模板中的 `windows_release_x86_64.exe` 放在：

```text
build/export_templates/templates/windows_release_x86_64.exe
```

若已通过 Godot 的模板管理器安装，可从标准目录复制：

```powershell
New-Item -ItemType Directory -Path build/export_templates/templates -Force | Out-Null
Copy-Item "$env:APPDATA/Godot/export_templates/4.7.2.stable/windows_release_x86_64.exe" build/export_templates/templates/
```

在 PowerShell 中运行，或右键脚本选择“使用 PowerShell 运行”：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/export_windows.ps1
# 编辑器不在 PATH 时：
powershell -NoProfile -ExecutionPolicy Bypass -File tools/export_windows.ps1 -GodotPath "C:\Tools\Godot\Godot.exe"
```

脚本采用 Windows PowerShell 5.1 兼容语法，也可使用 PowerShell 7。路径选择顺序为 `-GodotPath`、环境变量 `GODOT`、PATH 中的 `godot`。上述执行策略选项只作用于本次进程。

输出：`build/MidnightWorkshop.exe`（x64、内嵌 PCK）与 `build/MidnightWorkshop-Windows.zip`。ZIP 包含程序、README、素材来源和许可文件，并校验压缩包内程序的 SHA-256。

### 失败处理与验证

每次运行使用独立临时目录和日志目录。只有导出、程序校验及打包全部成功后才替换正式产物；失败返回非零退出码，保留上一份构建。若文件占用或权限问题使回滚也失败，脚本会保留恢复文件并打印位置。

日志位于 `artifacts/export-macos.*` 或 `artifacts/export-windows-*`。两份脚本共享 `build/.export.lock` 防止同时导出；若进程被强制终止，请先确认没有导出进程运行，再删除遗留锁文件重试。

Windows 脚本按 UTF-8 接收 Godot 输出，`console.log` 和汇总 `engine.log` 使用带 BOM 的 UTF-8；控制台汇总会去除 ANSI 颜色控制字符。脚本结束时恢复调用方编码，无需修改系统区域设置。历史乱码日志无法通过修改文件编码完整恢复，请重新运行生成；各阶段的 `*-engine.log` 保留 Godot 原始日志。

导出脚本不默认运行全部游戏测试。开发验证分别执行：

```bash
python3 tests/test_export_macos.py
bash tools/verify.sh
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests/test_export_windows.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tools/verify.ps1
```

脚本测试只使用临时工程和模拟 Godot，不执行真实导出。平台实测范围见 [导出脚本验证记录](docs/export-scripts-verification.md)。手动导出仍可使用原有 `--export-release` 命令。

## macOS 导出与运行

目标为 **Apple Silicon（M 系列）本机使用**，使用官方 Universal 模板（包含 `arm64`，在 M 系列 Mac 原生运行，无需 Rosetta），最低系统版本设为 macOS 13.0（Metal）；当前实测环境为 macOS 15.7.9 / Apple M4。最低版本声明不等于逐版本验收，Intel、其他系统版本和实体手柄未实测。结果见 [macOS 验证记录](docs/macos-verification.md)。

1. 下载 [Godot 4.7.2 Standard macOS 版](https://godotengine.org/download/archive/4.7.2-stable/)，将 `Godot.app` 放入 `/Applications`。本工程无需 .NET 或 Blender。
2. 打开 Godot，在「编辑器 → 管理导出模板（Editor → Manage Export Templates）」安装 **4.7.2.stable** 模板。也可从同一官方页面下载 Standard 的 `.tpz`，在模板管理器选择「从文件安装」。模板版本必须与编辑器一致；本预设使用标准模板位置，不依赖 Windows 的自定义模板目录。
3. 在终端进入项目根目录，执行：

```bash
export PATH="/Applications/Godot.app/Contents/MacOS:$PATH"
godot --version  # 应为 4.7.2.stable
godot --headless --path . --editor --import --quit
bash tools/verify.sh
mkdir -p build
godot --headless --path . --export-release "macOS" build/MidnightWorkshop.app
open build/MidnightWorkshop.app
```

官方 4.7.2 模板仅提供 Universal 二进制，因此不要把预设架构直接改成 `arm64`，否则会报缺少 `godot_macos_release.arm64`；包内的 Intel 架构不属于本次验收范围。

工程已启用 Apple Silicon 导出必需的 `渲染 → 纹理 → VRAM 压缩 → 导入 ETC2 ASTC`；同时保留 Windows 使用的纹理格式。更改该设置后必须重新导入资源。

也可在编辑器打开 `project.godot`，按 F5 运行；导出时选择「项目 → 导出 → macOS → 导出项目」，保存为 `build/MidnightWorkshop.app`，取消「导出调试」。`.app` 是包含可执行文件和游戏资源的应用包，复制时保留整个包。

预设使用内置 **ad-hoc 临时签名**，Bundle ID 为 `local.midnightworkshop.game`，无需开发者证书；公证关闭，适用于这里的本机使用范围。下载或转移来的未公证应用可能被 Gatekeeper 拦截，应只对可信来源按系统提示在「系统设置 → 隐私与安全性」允许打开；无需关闭系统安全保护。公开分发需另行配置 Developer ID 签名和公证，参见 [Godot 官方 macOS 导出说明](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_macos.html)。

若提示找不到 `godot`，检查应用路径或直接使用 `/Applications/Godot.app/Contents/MacOS/Godot` 替代命令。若提示缺少模板，回到模板管理器安装匹配版本。导出后可用以下命令检查架构、签名并查看启动日志：

```bash
file build/MidnightWorkshop.app/Contents/MacOS/*
codesign --verify --deep --strict --verbose=2 build/MidnightWorkshop.app
"./build/MidnightWorkshop.app/Contents/MacOS/午夜工坊 · Midnight Workshop" --verbose
```

RTX 3070 上四章 1080p 代表场景含移动、动画、AI，平均约 165 FPS，接近刷新率上限。这不是整场最低帧率保证，也不代表其他硬件。当前采用脚本输入通关与渲染截图验收，尚未做新玩家时长和多人主观手感测试。详情见 `docs/verification-expansion.md`。
