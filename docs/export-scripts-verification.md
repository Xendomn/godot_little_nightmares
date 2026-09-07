# 一键导出脚本验证记录

2026-09-07；macOS 15.7.9 / Apple M4，Godot 4.7.2.stable，系统 Bash 3.2，临时 PowerShell 7.5.3。

## 结果

| 检查 | 结果 |
|---|---|
| Bash 语法 | `/bin/bash -n tools/export_macos.command` 通过 |
| macOS 模拟流程 | `python3 tests/test_export_macos.py`：6 个测试组通过，含 17 个失败分支 |
| PowerShell 语法 | 两份 PS1 经 PowerShell AST 解析，无语法错误 |
| Windows 模拟流程 | `pwsh -NoProfile -File tests/test_export_windows.ps1`：21 个场景通过 |
| macOS 真实导出 | `bash tools/export_macos.command` 完成资源导入、Release 导出及 ZIP 打包，退出 0 |
| 架构与签名 | Universal 包含 arm64、x86_64；原始应用和归档解压后的应用签名检查通过 |
| ZIP 内容 | 解压后 Info.plist、可执行文件、PCK 与导出原件逐字节一致 |
| 原生启动 | 从临时目录以 `arch -arm64` 启动新应用，使用临时 `MIDNIGHT_SAVE_PATH`，退出 0、无引擎错误 |
| 游戏回归 | `bash tools/verify.sh`：全部 25 套通过 |
| 独立代码复查 | 修正 Windows 回滚的逐项错误处理后，无遗留高优先级发现 |

## 失败场景与修复

两份脚本覆盖缺少 Godot、版本不符、缺少模板、导入或导出非零退出、退出 0 但日志报错、缺少日志、缺少产物、打包失败，以及发布失败后恢复旧产物。测试同时验证共享锁、重复运行、空格和中文路径、从工程外调用；PowerShell 还验证显式参数与环境变量的优先级。

macOS 真实执行发现并修复了两项模拟工具未充分表达的问题：`lipo` 要求输入文件位于 `-verify_arch` 之前；系统 `unzip` 在 C.UTF-8 环境下可能错误显示中文条目名。回归测试已覆盖参数顺序和中文应用名称。ZIP 验证改用 `ditto` 解压、内容比较及签名复核。

Windows ZIP 在模拟测试中校验全部条目大小，并以流式 SHA-256 比较归档内程序与待发布程序。Windows 回滚会逐项尝试恢复；恢复失败时保留备份并报告位置。

## 复现与范围

脚本自身不下载或安装依赖，使用既有导出预设。PowerShell 验证运行时临时下载自 [微软官方 7.5.3 发布](https://github.com/PowerShell/PowerShell/releases/tag/v7.5.3)，下载文件 SHA-256 与官方发布 API 的摘要一致：`f4fac5c72e8c09ba3b6fb8667f21b1d73556047819857fce7883268d02369cde`；未安装到系统目录。

根据本次要求，**未在 Mac 上运行 PowerShell 的真实 Windows 导出**。Windows PowerShell 5.1 本机执行和 Windows 程序实机运行未验证。脚本采用 5.1 兼容语法，当前动态测试使用 macOS PowerShell 7.5.3；其中模拟 Godot 通过原生进程边界返回 stdout、stderr 和退出码。

日志位于 `artifacts/`：`export-macos-mock-tests.log`、`export-windows-mock-tests.log`、`export-macos-real-console.log`、`export-macos-script-launch-console.log`、`export-scripts-game-verification.log`。真实导出的分阶段日志另存于独立的 `export-macos.*` 目录。
