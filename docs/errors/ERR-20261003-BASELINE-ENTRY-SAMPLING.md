# ERR-20261003-BASELINE-ENTRY-SAMPLING：入口机制断言误用浮点严格相等

- status: resolved
- channel: automated_test
- category: test
- first_seen: 2026-10-03
- run_id: `20261003T123700495Z-5b3e9b9e`
- checkout: `/private/tmp/astra-baseline-01a101be`
- code_state: `codex/baseline-01a101be`，base `a3401f6e62e2c11cb2f4cd30af1836afb32ae4fe` 加测试基线未提交修改；精确状态见报告快照/源码哈希。

## 原始证据与影响

统一入口 `node tools/check.mjs --scope game`，固定 Godot 4.7.2 / GUT 9.7.1。报告 `artifacts/test-runs/20261003T123700495Z-5b3e9b9e/report.json`：14 检查执行齐全，12 通过；GUT/JUnit 判失败。134 个 case 中唯一失败 `test_map_entering_each_entrance_is_safe_and_does_not_bounce_back`；原始 `game.xml`、`logs/gut.log` 与 `logs/junit.log` 保留。

新增的“安全入口应保持原位置”断言严格比较 Vector2。引擎落地后观测 `(80,239.9992)` / `(432,239.9992)`，入口配置为 `(80,240)` / `(432,240)`；房间身份、入口独立设计预期和真实碰撞均符合原有要求。其他用例通过，没有依赖缺失、导入/运行错误或超时证据。

## 原因与修复

先查公共采样错误记录 `ERR-20261002-SCALE-TEST-SAMPLING`、`ERR-20261002-SPEED-STEP-SAMPLING`。本次触发不同：新的机制断言使用严格浮点相等，而物理碰撞产生不足 0.001 px 的稳定落地差异。修复逐轴比较实际入口前后位置，并使用本 case 已有的 0.1 px 坐标容差，同时保留身份不变、真实落地和独立入口坐标检查。生产数值、场景、JSON 布局和原有容差均不改。

修复后立即同入口复跑全部 game case：`20261003T123953536Z-9cb1d87a` 的 report、原始 JUnit 与日志已读取，14/14 检查、134 tests / 2841 assertions，0 failures/errors/skipped，166 项源码哈希。原入口失败项通过；技术问题关闭，用户手感仍待独立反馈。随后补充速度机制的正负方向/实际位移断言及台阶采样字段命名，不改坐标；这些最终文件由本轮后续完整报告和主 agent 整合验收确认。
