# ERR-20261002-HEART-TEST-FIXTURE：半心验收测试解析与HUD刷新时机

- status: resolved
- channel: automated_test
- category: test
- first_seen: 2026-10-02（Asia/Shanghai）
- related_run_ids: `20261001T173347518Z-c4d50c4e`、`20261001T173738107Z-511a5081`
- related_error_ids: `ERR-GAME-GUT`、`ERR-GAME-JUNIT`
- code_state: `32c3e3cf026fb3b4589316948641135db64aa662` 加未提交的心血量改造

## 复现上下文与原始证据

在 `/Users/hanguo/.codex/worktrees/heart-health-v5/Godot-project` 按已采纳 ENV-0004 沙箱外执行环境运行 `node tools/check.mjs --scope game`。固定版本为 Godot `4.7.2.stable.official.ed1daf0bf`、Python `3.12.14`、gdtoolkit `4.5.0`、GUT `9.7.1`；每轮 `ASTRA_SETTINGS_PATH` 独立，不修改 HOME。

首轮完整证据：`artifacts/test-runs/20261001T173347518Z-c4d50c4e/report.json`、`game.xml` 与 `logs/gut.log` / `logs/gut.engine.log`。14 项检查全部执行，12 项通过；gut / junit fail，整轮退出 1。JUnit 实际执行 96 项、1640 个断言、1 failure、0 errors、0 skipped；契约仍为 101 项，缺少新文件的 5 个半心用例，未降低契约或把缺失判为通过。122 个报告源码哈希与当时工作树一致。

1. 原始错误：`SCRIPT ERROR: Parse Error: Cannot infer the type of "remaining" variable because the value doesn't have a set type.`，触发 `test_heart_units.gd` 中从 Dictionary 的 attack/count 计算临时 remaining。引擎随后报告无法载入脚本，5 个用例没有实际执行。
2. 唯一实际断言失败：`test_dummy_overkill_refills_without_carry_and_training_reset_clears_statistics` 首个中文 HUD 仍显示累计 0 心 / 0 次，预期是 50000.5 心 / 1 次。受击生命、完整伤害、HealthBar 大半心数字及浮字断言已执行且通过。

## 原因与修复假设

工具版本、lint、format、import、主场景和真实进程语言恢复均通过；错误定位为新增测试设施。

- 对包含 Variant 的临时算式补 `remaining: float` 明确类型，不改伤害、容器或回满预期。
- HUD 由实际 `_process` 刷新；语言未改变时没有语言切换信号，命中后同一帧立即读取属于测试时机错误。HealthBar 大值三语检查先在同一帧完成，然后还原 10 容器配置，等待真实帧读取 HUD。这样仍检查实际三语 50000.5 心文本，也不让一帧绘制十万个容器。

## 当前结论

两处测试修复已落盘，准备使用同入口完整复跑。首次失败报告与日志保留，尚不关闭问题；只有全部 101 项真实执行、JUnit 无失败/错误/跳过、完整检查和日志通过后才能标记 resolved。

## 修复验证与关闭依据

同入口完整复跑 `20261001T173738107Z-511a5081`，14/14 检查全部 pass；JUnit 实际 101 项、1811 个断言，failures/errors/skipped 均为 0，全部 case 有正数断言且名称与契约一致。5 个半心用例已实际载入执行；大额 HUD 三语保留 50000.5 心，HealthBar 与浮字也保留半心。

完整报告：`artifacts/test-runs/20261001T173738107Z-511a5081/report.json`，JUnit 为同目录 `game.xml`。已读取每项检查、所有原始日志并重新核对 122 个源码 SHA-256，全部与当时工作树一致；新测试脚本、UID、manifest 与新图形探针及 UID 均在哈希中。所有日志无脚本/解析/运行错误、失败断言或警告；首次报告仍保留。

关闭两处测试设施错误；业务预期和 101 项契约未降低。图形审核与用户手感不由该轮 headless 通过推定。
