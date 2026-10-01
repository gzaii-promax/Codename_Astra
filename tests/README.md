# 首版自动验收模块

## Agent 开始与结束步骤

1. 读取 `AGENTS.md`、`docs/testing.md`、`tests/manifest.json` 和 `docs/errors/README.md`，再检查最新报告的 scope 与代码 hash。
2. 项目根目录执行 `node tools/check.mjs --scope game`；本机按 ENV-0004 使用获准的沙箱外环境。新建或修改测试流程后立即执行。
3. 读取 stdout JSON 的 `report_path`，核对 12 个检查全部执行、34 个预期测试均出现，且 JUnit 没有失败/错误/跳过；核对源码 hash、原始日志、Git 状态和报告时间。
4. 失败先查公共错误目录，分类依赖/环境/配置/代码/测试问题；记录假设与修复证据，再复跑。交接提供 `run_id`、状态、报告路径、原始日志与开放错误。

## 职责与接口

| 文件 | 内容 | 采用的实际接口 |
| --- | --- | --- |
| `game/test_actions.gd` | 等级/配置合法性、阶段边界、单次激活、零时长、大 tick、冷却、取消、不同技能绑定与重置 | `SkillDefinition`、`PhasePolicy`、`ActionController` |
| `game/test_combat_physics.gd` | 真正物理世界中的扫掠命中、左右方向、遮挡、寿命/射程、近战范围/单次命中、接收器校验 | `Fireball`、`MeleeStrike`、`SkillExecutors`、`DamageReceiver` |
| `game/test_player_scene.gd` | 主场景节点/输入、落地/移动/跳跃/墙体、主角动作命中真实稻草人、等级切换、训练重置、逆向输入/重置当帧/贴左右墙发射回归 | `TrainingArena`、`PlayerCharacter`、`TrainingDummy` |
| `manifest.json` | 审核后的完整预期 case 名称，拒绝空执行或漏执行 | runner 和 JUnit 对照 |

## 验收基线与可证明范围

- 首版普通攻击 20 伤害；火球术 35 伤害，一级前摇 0.5 秒、二级 0.2 秒。升级不改变伤害；这些是首版可调整的技术基线。
- 动作属性测试使用公开 API 驱动受控时间；物理测试使用实际引擎 physics frames，覆盖超高速火球越过目标、墙体先于目标、每次近战窗口至多命中一次。
- Player 集成加载正式场景，并额外通过 Input.action_press 验证输入映射到实际移动。测试只断言基础可操作性、阻挡、受击与时序，不判断好不好玩。
- fixture target 通过真实 DamageReceiver 和 CollisionShape2D 接收攻击；另外真实 TrainingDummy 在正式场景中验证统计与伤害来源。不是用伪造命中替代物理命中。
- 当前自动检查不覆盖像素视觉质量、动画观感、音效、实际键盘硬件、导出包、跨平台兼容或手感；这些不由 headless 成功推定。

## 扩展与维护

- 新行为测试应来自需求和可观察结果；新增不同技能的同控制器用例用于验证现有机制的组合能力。
- 修改技能规则时维护技能模块文档和相关测试预期。新增 case 手动维护 manifest；不要用重新生成清单消除漏测警报。
- 超时、故意失败与报告读取能力由工具链自检验证，不混入游戏通过数量。游戏正常验收不接受预期之外的失败或超时。
