# ERR-20261002-WORKSPACE-CLASS-CACHE：工作区旧类缓存导致直接启动失败

- status: resolved
- channel: automated_test
- category: environment
- first_seen: 2026-10-02
- code_state: `codex/scale-movement-v4` 未提交的已验收业务；通过快照 `20261001T171024428Z-05e42084`。

## 复现与证据

在项目根目录用固定 Godot 4.7.2 直接执行 `--headless --path <工作区> --quit-after 10`，设置独立 `ASTRA_SETTINGS_PATH`。原始 `artifacts/scale-live-startup/before-import.log` 显示 exit0，但含 `Identifier "GameUnits" not declared in the current scope`、未识别 `Combatant` / `PeriodicEnemy` 及后续解析错误，按错误日志认定启动失败。工作区 `.godot/global_script_class_cache.cfg` 未包含这些新增类；同一业务在独立快照导入后已完整通过，不能把快照成功替代工作区实际启动。

## 原因与修复验证

工作区保留旧版本的可再生 Godot 类缓存。使用相同固定引擎执行 `--headless --path <工作区> --editor --import` 刷新，`import.log` exit0、stderr 为空、无引擎错误。随后相同工作区执行 `--headless --path <工作区> --quit-after 120`，`after-import.log` exit0、无错误，主场景完成启动检查。未改业务规则、玩家设置或 HOME。

四份 UID 元数据采用通过快照导入生成且已在该轮使用的原文件：新单位、新尺度用例、新图形探针及此前缺失的生命场景用例；原件与工作区逐字节相同，附加哈希在 `generated-uid-evidence.json`。它们与运行前报告的 114 项源码哈希范围区分，原报告未改写。

新增 `class_name` 或切换含新增类的分支后，应先用项目固定编辑器导入工程，再使用 Play.command / tools/play.mjs。导入与实际工作区启动均已验证，本次环境问题关闭；这不是用户手感结论。
