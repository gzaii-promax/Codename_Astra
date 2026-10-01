# ERR-20261001-HEALTH-TEST-FIXTURE：独立生命测试清理未初始化输入

- status: resolved
- channel: automated_test
- category: test
- first_seen: 2026-10-01
- related_run_ids: `20261001T150420167Z-31a7e343`、`20261001T150849473Z-eb7e5b91`、`20261001T151216094Z-01f05a8d`
- code_state: 生命/阵营/定时敌人开发工作树，尚未提交

## 原始证据与影响

项目根目录以获准的沙箱外环境运行 `node tools/check.mjs --scope game`。

报告 `artifacts/test-runs/20261001T150420167Z-31a7e343/report.json` 共 14 项检查，12 项符合预期；lint 和 gut 判为 fail。`game.xml` 与独立 JUnit 读取证明 77 项用例均执行、999 个断言，无失败、错误或跳过；该结果仍不能覆盖引擎日志里的错误。

- `logs/lint.log`：`Class global scope has more than 20 public methods (functions) (max-public-methods)`。原测试文件将 24 项用例集中，临时 disable 注释位置无效。
- `logs/gut.log`：`ERROR: The InputMap action "move_left" doesn't exist`，并涉及 move_right/jump/basic_attack/fireball。调用位置为 `tests/game/test_health_combat.gd:39 after_each`；独立组件用例尚未实例化训练场，输入尚未由 InputSetup 建立。
- GUT 子进程 exit_code=0，但入口依据引擎日志正确判 fail，未将所有断言通过误报为整轮验收通过。

## 原因与修复

工具版本、格式、导入、启动及原有用例均已执行，错误定位为新增测试设施，不是业务伤害或生命行为失败。

1. 清理只释放 `InputMap.has_action(action)` 已存在的输入，不制造不存在的动作错误。
2. 将独立规则用例与真实场景用例拆成 `test_health_combat.gd` 和 `test_health_scene.gd`，移除 lint disable 注释；全部原有 53 项与新增 24 项名称保留。
3. 按受击阶段规则新增一项真实 ACTIVE 近战中断回归，总计 78 项；未降低预期或删去失败用例。

## 复验

第一次修复后复跑相同公共入口，运行 `20261001T150849473Z-eb7e5b91`：输入清理错误消失，GUT 和 JUnit 通过 78 项用例；整轮仍因新增图形探针 `_run` 超过 6 个 return 的 lint 约束判 fail（13/14 项检查通过）。原证据见该轮 `logs/lint.log`。

将探针的单位准备、单图捕获与报告保存分成职责明确的函数，保留所有错误退出分支且不禁用 lint；每种语言都重新设置主角默认 DEATH 行为，只在击倒截图前切换 KNOCKDOWN。新增真实稻草人结算伤害回归后，契约总计 79 项。下一轮仍使用相同入口，待核查完整报告、JUnit 和原始日志后关闭。

最终运行 `20261001T151216094Z-01f05a8d`：14/14 项检查全部 pass，79 项用例、1020 个断言，JUnit failures/errors/skipped 均为 0；原 53 项名称全部保留。已读取完整报告与原始日志，输入不存在错误和两处 lint 错误均不再复现，所有引擎日志无脚本/解析/运行错误。报告位于 `artifacts/test-runs/20261001T151216094Z-01f05a8d/report.json`，原失败证据继续保留。

关闭依据为相同入口对修复后的原失败项、受影响回归和本轮完整契约均验证通过，不改变正式 lint 阈值，也不把单独断言通过当作整轮通过。
