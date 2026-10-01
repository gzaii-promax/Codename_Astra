# ERR-20261001-TEST-SCENE-PARENT：测试 fixture 不能成为 current_scene

- status: resolved
- channel: automated_test
- category: test
- first_seen: 2026-10-01
- related_run_ids: `20261001T081735485Z-8f836a34`、`20261001T081939342Z-2ec2602b`、`20261001T082039693Z-ea5f3c3e`
- related_error_ids: `ERR-GAME-GUT`、`ERR-GAME-JUNIT`、`ERR-GAME-FORMAT`
- code_state: 首版并行开发中的 30 个测试首次完整执行；报告保存该轮文件 SHA-256。

## 复现与证据

命令：项目根目录 `node tools/check.mjs --scope game`，固定 Godot 4.7.2、GUT 9.7.1。
报告：`artifacts/test-runs/20261001T081735485Z-8f836a34/report.json`；原始日志见同目录 `logs/gut.log`、`logs/format.log` 与 `game.xml`。

JUnit 记录 30 tests、142 assertions、11 failures、0 errors/skipped。
11 个失败共同包含 `Condition "p_scene && p_scene->get_parent() != root" is true.`。
版本、lint、项目 import 和正常主场景运行均通过，故先排除缺少依赖与引擎启动故障。

## 原因与修复假设

测试通过 GUT `add_child_autofree` 把 fixture 放在测试节点下，却把它设为 `SceneTree.current_scene`。
Godot 要求 current_scene 是 SceneTree.root 的直接子节点；这是测试 fixture 的接入错误，未发现对应业务代码故障。
改为 `get_tree().root.add_child(fixture)` 并继续用 GUT `autofree(fixture)` 管理清理，保留所有原断言；结束时恢复原 current_scene。

另一个失败为 `test_combat_physics.gd` 格式尚未完成时被首次快照捕获；已用固定 gdformat 格式化，不更改测试预期。

修复后立即复跑全部公共游戏入口，结果追加在本记录；未获得复跑结果前不得标为 resolved。

## 修复验证

使用相同入口复跑：`20261001T081939342Z-2ec2602b` 为 pass，12/12 检查、30 tests、131 assertions、0 failures/errors/skipped。
原先 11 个 unexpected engine error 消失，所有原业务断言保留；format 通过。原始 GUT/JUnit 日志在该 run 目录保存。
随后 runner 将 lint/format 和 SHA-256 统一到同一测试快照；`20261001T082039693Z-ea5f3c3e` 同样全部检查通过。该错误由测试生命周期修正关闭，没有以屏蔽引擎错误解决。
