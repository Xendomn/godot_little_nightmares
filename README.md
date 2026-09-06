# 午夜工坊 · Midnight Workshop

一个可完整通关的原创 3D 恐怖童话小游戏。操控青蓝色布偶，穿过巨大的玩具工作台、守夜工偶巡逻的装配车间，以及通往外界的输送带。

## 开始游戏

- **直接运行：** 双击 `build/MidnightWorkshop.exe`，不需要安装 Godot 或 Blender。
- **编辑工程：** 使用 Godot 4.7.2 打开 `project.godot`，按 F6 运行主场景或 F5 运行工程。
- **命令行：** 在项目目录运行 `godot --path .`。

默认窗口为 1280×720，界面按 1920×1080 排版并随窗口缩放。使用 Forward+ / Vulkan，支持 Windows x64。进度只在本次运行内保留。

## 操作

| 按键 | 动作 |
|---|---|
| A / D | 左右移动 |
| W / S | 在场景纵深方向移动 |
| Space | 跳跃 |
| Shift | 奔跑 |
| Ctrl | 蹲伏；低通道内松开仍会保持蹲伏，直到头顶有空间 |
| E | 拾取／安装保险丝、拉动电闸 |
| 按住 E + A / D | 在箱子旁朝箱子方向推动 |
| Esc | 暂停／继续；暂停菜单可调节音量或从头开始 |

桌底可以遮住守夜工偶的视线；靠近他时奔跑会发出声响。失败后会自动返回当前区域的检查点。

<details>
<summary>卡关时查看路线提示（含谜题答案）</summary>

1. 把积木箱向右推到工作台旁。先跳上箱子，再从箱子跳上桌面，按 E 取得发光保险丝。
2. 向右移动，在低矮金属通道前按住 Ctrl，通过第一道铁门。
3. 在装配车间入口右侧的 FUSE 配电箱前按 E 安装保险丝。
4. 移到靠近镜头的一侧，蹲伏走入第一张装配桌下。等工偶向左经过、背对你后，再向右通过第二张桌子。
5. 在车间右端 POWER 电闸前按 E，立即向右奔跑。
6. 在输送带的金色警示条附近起跳，跨过两个断口；蹲伏穿过低通道，再奔跑跳过第三个断口。工偶会在低通道前短暂停顿。
7. 继续向右抵达 OUTSIDE 投递滑槽。

</details>

## 工程与素材

- `scenes/main.tscn`：完整、可在 Godot 编辑器中调整的关卡、灯光、碰撞与角色节点。
- `scripts/`：角色运动、镜头、交互、怪物、进度、界面与声音，按职责分离。
- `assets/models/`：6 个原创 Blender GLB；`assets/sources/` 保留对应 `.blend` 和预览。
- `assets/audio/`：8 个原创合成 WAV；`assets/fonts/`：Noto Sans SC 与 OFL 许可证。
- `tools/build_scene.gd`：离线场景生成器。重新执行会覆盖 `scenes/main.tscn` 的手工修改，运行游戏本身不需要它。
- `tools/create_assets.py`：Blender 模型与声音的可重现生成脚本。

角色使用独立肢体节点的程序动画，包含待机、步行、奔跑、跳跃、蹲伏与推动。无 C++、外部脚本库、联网服务、付费资源、战斗系统或跨次存档。

## 验证与重新构建

```powershell
godot --headless --path . --script tests/test_progress.gd
godot --headless --path . --fixed-fps 60 --script tests/test_gameplay.gd
godot --headless --path . --fixed-fps 60 --script tests/test_controls.gd
godot --headless --path . --fixed-fps 60 --script tests/test_stealth.gd
```

生成场景或原创模型：

```powershell
blender --background --python tools/create_assets.py
godot --headless --path . --editor --import
godot --headless --path . --script tools/build_scene.gd
```

导出：`godot --headless --path . --export-release "Windows Desktop" build/MidnightWorkshop.exe`。当前导出预设引用 `build/export_templates/templates/` 内的官方 4.7.2 Windows x64 模板。换机器后可下载同版本官方模板，或在 Godot 导出设置中改用已安装的模板。

实际 GPU 窗口的脚本输入验收：`godot --path . --fixed-fps 60 --resolution 1920x1080 --script tests/test_gameplay.gd -- --visual`。该脚本对中段视线进行位置隔离测试；连续潜行路线由独立的 `test_stealth.gd` 验证。

性能测试：`godot --path . --resolution 1920x1080 --script tests/benchmark.gd`。截图及测试日志保存在 `artifacts/`，不随可执行文件导出。

首玩时长以 5–10 分钟为设计目标，尚未做新玩家时长测试；熟悉路线后可更快通关。当前验收为自动输入与渲染截图检查，尚未进行多人主观手感测试。测试机器为 RTX 3070；其他硬件帧率需另测。
