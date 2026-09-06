# Xbox 手柄与方向键验收

2026-09-06，Godot 4.7.2 / Windows / RTX 3070，基线 `6e74d25`。

## 实现

- WASD 与方向键映射到同一组移动动作。左摇杆与十字键支持横向、纵深；A 跳跃、RT 按住奔跑、B 按住蹲伏、X 互动／按住推动、Menu 暂停。
- 左摇杆移动死区 0.22，保留模拟幅度；RT 阈值 0.5；菜单摇杆阈值 0.5，首次连发延迟 0.35 秒、后续间隔 0.12 秒。轴方向精确匹配，重复模拟采样不会立即跳过菜单项。
- 菜单 A 确认／B 返回，覆盖章节选择、暂停、音量、确认弹窗与结尾。确认弹窗默认取消，并显式指定双按钮焦点邻居。界面使用过的游戏按键需释放后才能重新触发，避免确认即跳跃或返回即蹲伏。
- InputHints 自动加载服务跨章节保持最近设备，菜单与弹窗消费事件前也更新提示。HUD、交互、推箱、教学提示使用动作占位符；场景与生成器同步更新。主菜单和结尾仅显示实际支持的确认操作。
- 最近使用的手柄断开会暂停；若处于重生过渡，等待过渡结束再暂停。重新连接不自动继续，键盘随时可操作。存档格式不变。

## 验证结果与复现

`powershell -ExecutionPolicy Bypass -File tools/verify.ps1`：18 套全部通过，无脚本错误。新增原始输入 13 项、控制器界面 23 项、方向键实际位移等价 4 项；既有谜题、蹲伏、六桌绕行、检查点与存档回归保留。原始按钮测试另以设备编号 2 运行通过。

下列测试通过 `InputEventJoypadButton` / `InputEventJoypadMotion` 注入 Xbox 原始事件，复用同一组路线断言，未跳过游戏输入映射：

```powershell
godot --headless --path . --fixed-fps 60 --script tests/test_gameplay.gd -- --controller
godot --headless --path . --fixed-fps 60 --script tests/test_expansion.gd -- --controller
godot --headless --path . --fixed-fps 60 --script tests/test_routes.gd -- --controller
godot --path . --fixed-fps 60 --script tests/test_controller_ui.gd
godot --path . --fixed-fps 60 --script tests/test_routes.gd -- --controller
```

工坊推箱登台、保险丝供电和追逐通过 23 项；新增三章机关／检查点通过 33 项；潜行与钟楼最终追逐通过 7 项。路线包含检查点恢复与特定摆位，并非一次完整人工试玩。

实际 Forward+ 窗口也通过控制器菜单与三章路线，保存了 `artifacts/controller-chapters.png`、`controller-pause.png`、`controller-confirm.png` 及结尾截图。窗口菜单测试覆盖默认取消、主动确认新旅程、音量调整和设备提示。独立审查发现的轴方向、重复采样和菜单设备识别问题已加入回归并修复。

本机 `Input.get_connected_joypads()` 返回空数组；**尚未完成实体 Xbox 手柄的 USB／蓝牙连接和手感验收**。自动注入验证不等同于硬件测试。首次实体测试应检查连接、左右摇杆方向、RT 门槛、A+RT 奔跑跳跃、X 持续推箱、暂停菜单及拔插恢复。本版不包含震动或自定义改键。

Windows 交付使用相同 4.7.2 官方模板重新导出成功，EXE 独立目录启动退出码 0，ZIP 完整性检查通过。当前文件校验和写入 `artifacts/release-v2.json`，日志使用 `artifacts/controller-export*.log`。
