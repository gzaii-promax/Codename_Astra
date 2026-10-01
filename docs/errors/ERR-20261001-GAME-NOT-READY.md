# ERR-20261001-GAME-NOT-READY：首版测试准备期间项目与测试契约未齐备

- status: resolved
- channel: automated_test
- category: resource/configuration
- first_seen: 2026-10-01
- related_run_ids: `20261001T080531081Z-e8d40c0f`、`20261001T081939342Z-2ec2602b`、`20261001T082039693Z-ea5f3c3e`
- related_error_ids: `ERR-GAME-MANIFEST`、`ERR-GAME-SOURCES`
- code_state: 首版并行开发中；尚未完成游戏场景和测试契约。

## 复现与原始证据

在项目根目录运行 `node tools/check-game.mjs`（公共 `--scope game` 尚在整合）。

报告：`artifacts/test-runs/20261001T080531081Z-e8d40c0f/report.json`。
首要报错：`ENOENT: no such file or directory, open '.../tests/manifest.json'`。
依赖该契约的后续检查均记录 `blocked`，未运行的退出码为空；没有误报通过。

## 预期与实际

- 预期：真实项目与非空测试清单齐备，执行全套游戏验收并保存证据。
- 实际：测试入口创建后立即执行，而场景和测试文件仍在并行开发；12 项均阻塞。
- 影响：本轮只证明阻塞结果被记录，不能证明游戏功能或手感。

## 原因与处理

这是开发顺序造成的资源尚未齐备，不是依赖安装失败。固定工具链此前已验证；进入真实运行仍需再次验证版本。
项目和测试契约齐备后，使用公共入口 `node tools/check.mjs --scope game` 复跑；后续修复与结果追加在本记录。

## 验证结果

项目与非空契约齐备后，运行 `20261001T081939342Z-2ec2602b` 完成 12/12 检查、30 个真实游戏测试通过，131 断言、0 failures/errors/skipped。
`20261001T082039693Z-ea5f3c3e` 再验证快照 hash 与快照 lint/format 一致性，12/12 检查通过。
初始缺文件阻塞不再复现；后续新增回归测试继续使用相同公共入口，不把这些旧结果视为最终改动的证据。
