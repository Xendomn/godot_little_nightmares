> 首版历史记录。当前扩展版验证见 verification-expansion.md。

# 验证记录 · 2026-09-06

## 环境

- Godot 4.7.2 stable，Blender 5.2.1 LTS。
- Windows x64，NVIDIA GeForce RTX 3070，Vulkan 1.4.329 / Forward+。
- 新建非 Git 工程；所有实现与源素材保留在项目目录。

## 自动验收

| 套件 | 结果 | 覆盖 |
|---|---|---|
| test_progress.gd | 12 项通过 | 保险丝顺序、重复操作、检查点进度恢复 |
| test_gameplay.gd | 23 项通过 | 实际输入推箱与两段登台跳跃、拾取、蹲伏通道、安装、电闸、视线遮挡、三个追逐断口、重生与结尾 |
| test_controls.gd | 6 项通过 | Escape 暂停与恢复、冻结运动、防隔墙拾取、头顶检测、重开取消旧死亡过渡 |
| test_stealth.gd | 路线通过 | 从车间前部蹲伏进入桌底，等待工偶向左经过，再连续抵达右端 |

以上最终测试均以退出码 0 完成。固定帧率无界面测试会快于音频线程的真实时间；测试清理阶段等待 100 ms，最终 gameplay / controls 日志无音频资源泄漏警告。

实际 GPU 窗口的脚本输入验收也已运行至通关画面，见 `artifacts/rendered-gameplay.log` 及 `01-workbench.png`、`02-assembly.png`、`03-chase.png`、`04-ending.png`。该测试对中段视野检测进行独立摆位，并非一次没有摆位的完整人工游玩；连续潜行另由真实输入路线测试覆盖。

## 渲染与性能

最终版本以 1920×1080 渲染，在每处定点预热 150 帧后采样 240 帧：

| 位置 | 平均 FPS |
|---|---:|
| 工作台区域 x=8 | 165.03 |
| 装配车间 x=37 | 165.10 |
| 输送带 x=67 | 165.09 |

定点测试冻结玩家和 AI、保留场景渲染，接近本机刷新率上限；这不是整场游玩的最低帧率保证。原始结果为 `artifacts/benchmark.json`。菜单中文字体、三处场景截图已经目视检查。

## 交付与边界

- `build/MidnightWorkshop.exe`：Windows x64 release，嵌入 PCK，123,799,632 bytes。
- `build/MidnightWorkshop-Windows.zip`：53,439,588 bytes，包含 EXE、中文操作说明及字体／Godot 许可证。
- 使用官方同版本模板导出成功；从 build 目录运行独立 EXE 的无界面启动检查通过，见 `artifacts/export-smoke.log`。Release 模板不执行外部 `--script` 测试参数，因此完整输入验收针对工程运行，独立包验证范围为启动。
- 独立复审的四个问题均已修复，详见 `docs/review.md` 的 Resolution review。
- 原创模型／声音的可重现生成与尺寸、节点、WAV 验证，见 `docs/assets-report.md`。
- 尚未进行新玩家时长与多人手感测试，5–10 分钟是首玩设计目标。无跨次存档、战斗、手柄或联网。
