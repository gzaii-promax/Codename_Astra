# ERR-20261001-ACTION-FACING-RESET：动作朝向与重置效果的集成边界

- status: resolved
- channel: code_review
- category: code
- first_seen: 2026-10-01
- code_state: 首版整合中，尚未创建 Git 提交。
- related_run_ids: `20261001T082354982Z-128d723b`

## 触发与证据

独立 agent 阅读实际代码指出两处集成缺口：Player 每帧更新朝向/攻击原点，但 MeleeStrike 的 facing 在施放时锁存，执行期反向输入会使图像/原点与攻击方向不一致；训练场 R 仅 queue_free 效果，在真正删除前没有主动停止物理逻辑。

这两处来自可复核的实现路径，尚不能用静态发现声称运行时已复现。不是缺依赖：此前实际 import/startup 与业务断言已运行，问题是方向/生命周期组合缺少明确限制。

## 预期与修复

普通攻击进入执行期后，图像、释放点和命中方向应一致；重置统计后旧效果不应再次造成伤害。

Player 现在只允许待机/前摇转向，执行/后摇期间锁方向但保留水平控制。训练场删除效果前立即停止其 physics_process，效果节点同时应拒绝已排队删除状态。由测试 agent 添加相应回归，再追加实际报告后关闭。

## 自动回归证据

项目根目录执行 `node tools/check.mjs --scope game`，运行 `20261001T082354982Z-128d723b`：12/12 检查、34 tests、153 assertions、0 failures/errors/skipped。
报告和 JUnit 位于 `artifacts/test-runs/20261001T082354982Z-128d723b/report.json` 与 `game.xml`。

- `test_reverse_input_during_melee_keeps_facing_and_attack_origin_consistent`：8 个断言通过。真实主角进入 ACTIVE 后反向输入，朝向、攻击原点与 MeleeStrike 一致；动作结束恢复转向。
- `test_reset_disables_old_effects_before_next_physics_hit`：7 个断言通过。把真实火球和近战效果生成在下一物理帧可以命中真实稻草人的位置，调用 reset 后立即检查 physics 停止和排队删除，再验证 6 个 physics frames 后统计保持 0。
- 原移动、跳跃、普通攻击、火球命中和训练重置全部回归通过，原始 GUT 日志没有引擎错误或警告。

这些结果验证修复后的技术边界，不由此推定原版本已经运行时复现，也不替代用户手感审核。
