# 机械道具替换验收

2026-09-06，Godot 4.7.2、Blender 5.2.1、Windows、RTX 3070，Forward+。

四章的 OUTSIDE、DRAIN、BELL、FILL、WINCH、BRAKE、WIND、RELEASE、LOAD、FUSE、POWER 等功能文字占位已替换为 19 件原创实体道具。保留章节装饰标识和中文操作提示。模型使用共享 2K PBR 材质，保留 Blender 源文件、生成器及预览；各件三角形数为 1,436–9,516，低于约定预算。

阀门、绞盘、拉杆、铃铛、钟锤、压板与仪表具有活动部件，配有三种原创机械音效；排水渐变、蒸汽预泄漏和跟随桥面的吊索提供环境反馈。检查点即时复位模型状态、积水和升降台压板；重复无效操作不会重复触发机关声。

验证结果：

- `tools/verify.ps1`：20 套、326 项检查通过，涵盖谜题、四章路线、存档、连续死亡、蹲伏、怪物绕桌、方向键、Xbox 输入与 UI，以及新增道具状态／暂停／重生检查。
- `tests/test_builder.py`：连续重建两次及缺失工作台章节时安全失败，均通过。
- `tests/check_mechanical_assets.py`：19 件 GLB 的活动节点、面数和共享贴图验证通过；Blender 重新导入验证通过。
- `tests/test_routes.gd -- --controller`：实际 Vulkan 窗口下通过潜行、诱敌、蒸汽、三个跳跃及蹲伏追逐路线。使用脚本注入手柄输入，未连接实体手柄人工试玩。
- `tests/capture_mechanical_props.gd`：四章 17 组远景／近景，共 34 张游戏截图，位于 `artifacts/props-*.png`。重点检查阀门、铃铛、滑槽和出口；修正了滑槽被地板遮住、压板下沉及复位不同步的问题。
- Godot 最终资源导入成功，无脚本错误。保留可匹配的既有场景资源和节点标识，减少生成器造成的无关差异。

`tests/benchmark_props.gd` 在 1920×1080 下对四章机关动画进行预热后各采样 300 帧。平均均约 165.09 FPS，P95 帧耗时分别为 6.405／6.419／6.364／6.379 ms；接近显示刷新率上限。此项为代表性机关场景测量，不是全流程最低帧率或其他硬件保证。数据见 `artifacts/props-performance.json`。

Windows 发行文件由现有官方导出模板构建，发行包包含游戏、启动说明及许可证。工程直接打开 `project.godot` 即可运行，无需安装 Blender 或重新生成素材。

最终导出成功；复制 EXE 至独立目录后以 `--headless --quit-after 120` 启动，退出码 0、无错误。`tools/package_release.py` 验证 ZIP 六个文件、解压 CRC 及内外 EXE SHA-256 一致。EXE 为 208,688,304 字节，ZIP 为 136,519,188 字节；校验数据见 `artifacts/release-v2.json`。
