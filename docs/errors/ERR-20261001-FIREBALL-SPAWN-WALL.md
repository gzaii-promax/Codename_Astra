# ERR-20261001-FIREBALL-SPAWN-WALL：火球释放偏移跳过薄墙

- status: resolved
- channel: code_review、automated_test
- category: code
- first_seen: 2026-10-01
- code_state: 首版未提交工作树；`SkillExecutors.fireball` 原生成点为 `get_attack_origin() + direction * 18`
- related_run_ids: `20261001T082354982Z-128d723b`

## 复现上下文与原始证据

主 agent 独立审查发现：训练场右墙 X 为 `940..960`；主角贴墙后中心 X 可为 `929`；攻击点额外前移 `15`，火球出生点再前移 `18`，最终 X 为 `962`。墙宽 `20`，火球已经在墙另一侧出生；此前火球只扫描出生点之后的运动线段，因此不会扫描释放前跨过的墙。

工具为 `tools/toolchain.json` 固定 Godot 4.7.2，工作目录为项目根目录。此记录首先依据具体坐标与代码路径，尚未将静态审查冒充已执行测试。没有依赖缺失、缓存权限或环境变动的证据；问题位于技能生成位置与物理查询范围。

## 预期与实际

- 预期：贴墙施法时，墙能够拦截火球；薄墙后目标不受伤害。
- 实际（代码路径）：偏移出生点超出墙的厚度，后续射线从墙外开始，跳过障碍。
- 影响：任何比角色攻击点与火球前置偏移之和更薄的障碍均可能被绕过；左/右方向均需要回归。

## 修复尝试

2026-10-01：保持无遮挡时的原发射偏移。在生成阶段，先从 `(caster.global_position.x, attack_origin.y)` 内部锚点到期望发射点对 world layer `1` 执行真实物理射线，启用 `hit_from_inside`，排除发动者自身。如果途中存在障碍，则火球出生于内部锚点，由下一物理帧沿完整移动线段撞墙销毁。技能执行器仍不依赖具体 Player 类型。

同轮补充：`Fireball` 与 `MeleeStrike` 在 `_physics_process` 开头检查 `is_queued_for_deletion()`，已排队删除的攻击不再命中目标；训练场重置还会由世界模块禁用攻击物理处理并删除节点。该保护与贴墙原因独立，使用重置/删除队列回归验证。

本模块 `gdformat`、`gdlint` 已立即复跑并通过。测试 agent 添加真实物理的左右贴墙与重置回归，并用公共 `node tools/check.mjs --scope game` 执行，运行 `20261001T082354982Z-128d723b`。

## 修复验证

- 完整报告：`artifacts/test-runs/20261001T082354982Z-128d723b/report.json`，总体 `pass`；预期 12 项检查全部执行并通过，无缺失。
- 原始 GUT JUnit：`artifacts/test-runs/20261001T082354982Z-128d723b/game.xml`；34 个测试、153 个断言、零失败、零错误、零跳过。
- `test_fireball_cannot_spawn_beyond_right_wall`：3 个断言通过，右墙外 receiver 无伤害，火球无法越墙存活。
- `test_fireball_cannot_spawn_beyond_left_wall`：4 个断言通过，左墙外 receiver 无伤害，火球无法越墙存活。
- `test_reset_disables_old_effects_before_next_physics_hit`：7 个断言通过，重置禁用并删除旧攻击，下一物理帧没有延迟命中。
- 其他技能、战斗、移动与场景回归通过；lint、format、资源导入及 120 帧主场景启动通过。原始命令日志在同轮 `logs/`，可由报告逐项定位。
- 模块 agent 独立读取报告和原始 XML，并核对 `skill_executors.gd`、`fireball.gd`、`melee_strike.gd` 当前 SHA-256 与报告完全一致，避免引用修改前结果。

## 当前结论

左右贴墙、重置及必要回归均通过，按上述运行关闭技术问题。此结论仅覆盖执行的障碍拦截与重置行为；操作手感由用户独立反馈。
