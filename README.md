# 午夜工坊 · Midnight Workshop

原创 3D 恐怖童话小游戏：无面织物精灵穿过四个相连章节，躲开畸形缝纫师，寻找工坊外的晨光。Windows 键鼠／Xbox 手柄、单人、无血腥。

## 开始游戏

- 双击 `build/MidnightWorkshop.exe`，或解压 `build/MidnightWorkshop-Windows.zip` 后运行。
- Godot 4.7.2 打开 `project.godot`，按 F5。主场景为 `scenes/main.tscn`。
- 命令行：`godot --path .`。默认窗口 1280×720，界面按 1920×1080 缩放，Forward+ / Vulkan。

## 操作与进度

| 动作 | 键盘 | Xbox 手柄 |
|---|---|---|
| 左右、有限纵深移动 | WASD 或方向键 | 左摇杆／十字键 |
| 跳跃 | Space | A |
| 奔跑；近处会被听见 | 按住 Shift | 按住 RT |
| 蹲伏；低通道自动保持蹲伏 | 按住 Ctrl | 按住 B |
| 互动／推箱、洗衣车或线轴箱 | E／按住 E 并左右移动 | X／按住 X 并左右移动 |
| 暂停／继续 | Esc | Menu |
| 菜单确认／返回 | Enter／Esc | A／B |

菜单使用方向键、左摇杆或十字键选择；音量滑块左右调整。提示跟随最近使用的设备切换。游玩时正在使用的手柄断开会暂停，重连后需要主动继续，键盘始终可用。支持 Windows 下 Godot 识别的 Xbox 手柄；本版不含震动、自定义改键或多人分配。实体手柄验收状态见 `docs/controller-verification.md`。

每章三个检查点，失败自动重生。检查点和已解锁章节保存至 Godot `user://campaign.json`，主菜单可继续旅程或选择已解锁章节。存档写入使用临时文件与备份，主档损坏时尝试恢复备份。音量独立保存在 `user://settings.cfg`。开始新旅程需确认，会清除章节进度，保留音量。

## 四个章节

| 章节 | 主要玩法 |
|---|---|
| 午夜工坊 | 推箱登台取保险丝、装配车间潜行供电、输送带追逐 |
| 染洗间 | 排水、洗衣车压住升降台、桌底潜行、限时蒸汽通道 |
| 悬线库 | 线轴配重、双绞盘悬桥、反复摇铃诱敌 |
| 钟楼 | 八秒摆锤制动、上弦升降台、放开钟锤后的最终追逐 |

<details>
<summary>路线提示（含谜题答案）</summary>

- 工坊：把箱子推到工作台边，连续两跳登台拿保险丝。蹲过低通道，装入配电箱。沿靠镜头一侧蹲到桌底，等守卫向左经过再走。拉电闸后奔跑跳过三处断口，中间低通道需蹲伏。
- 染洗间：E 排水，过水槽；推洗衣车到黄色 LOAD 框。移到升降台靠后的空位，E 灌水，等台面上升后向右走。沿桌底跟在守卫后面通过，蒸汽熄灭再过。
- 悬线库：推线轴箱压住配重板，等踏板降下。依次操作第一、第二绞盘；在出口区摇铃，蹲进第一张桌子，等守卫走向左侧铃声，再沿桌底向右离开。
- 钟楼：制动杆前按 E，八秒内跑过两个摆锤。站上升降台靠后侧按 E 上弦；到上层释放钟锤。跑过三个断口，在 CTRL 低通道蹲伏，最后奔向发光出口。

</details>

## 工程与原创素材

- `scenes/main.tscn`：持久化章节管理器，只加载当前一章。
- `scenes/chapters/`：四个独立可编辑关卡；`scenes/actors/`：共用角色、镜头、界面、声音。
- `resources/levels/`：章节顺序、场景地址、镜头边界和检查点定义。
- `scripts/campaign/`：存档与切换；`scripts/chapters/`：机关、平台、危险区。
- `assets/models/`：原创 GLB。主角 19,296 三角形、12 段动画；怪物 32,044 三角形、7 段动画。
- `assets/sources/`：Blender 源文件、新版角色预览；`assets/textures/characters/`：原创 2K 布料纹理。
- `assets/audio/`：14 个原创合成 WAV，含三章氛围、怪物空间呼吸、布料和重脚步。

角色使用 Skeleton3D、AnimationPlayer、AnimationTree 和轻量 SpringBone 布料摆动。蹲伏通过骨骼完成，不缩放整个模型。第三方来源见 `docs/asset-sources.md`，新版角色细节见 `docs/character-v2-report.md`。

## 验证与重建

```powershell
powershell -ExecutionPolicy Bypass -File tools/verify.ps1
python tests/test_builder.py
```

18 套无界面验证的日志保存在 `artifacts/`，存档测试使用隔离文件。蹲伏与绕桌修复记录见 `docs/crouch-navigation-verification.md`。窗口路线与性能检查：

```powershell
godot --path . --resolution 1920x1080 --script tests/test_routes.gd
godot --path . --resolution 1920x1080 --script tests/test_campaign_ui.gd
godot --path . --resolution 1920x1080 --script tests/benchmark_expansion.gd
godot --path . --fixed-fps 60 --script tests/test_crouch_render.gd
godot --path . --fixed-fps 60 --script tests/test_controller_ui.gd
godot --path . --fixed-fps 60 --script tests/test_routes.gd -- --controller
blender --background --python-exit-code 1 --python tests/check_crouch_mesh.py
```

重建素材与场景会覆盖相应手工修改，须依次执行：

```powershell
blender --background --python tools/create_assets.py
blender --background --python tools/create_characters_v2.py
python tools/create_expansion_audio.py
godot --headless --path . --editor --import --quit
godot --headless --path . --script tools/build_scene.gd
godot --headless --path . --script tools/build_expansion.gd
```

旧素材生成器会覆盖角色，之后必须运行 v2 生成器。运行现有工程无需 Blender 或重新生成。

Windows 导出：`godot --headless --path . --export-release "Windows Desktop" build/MidnightWorkshop.exe`。预设引用 `build/export_templates/templates/` 的 4.7.2 官方 Windows x64 模板；换机器后需安装对应模板或调整预设。

RTX 3070 上四章 1080p 代表场景含移动、动画、AI，平均约 165 FPS，接近刷新率上限。这不是整场最低帧率保证，也不代表其他硬件。当前采用脚本输入通关与渲染截图验收，尚未做新玩家时长和多人主观手感测试。详情见 `docs/verification-expansion.md`。
