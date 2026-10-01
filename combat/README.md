# 公共战斗模块

## 职责和边界

此模块提供统一的命中数据、目标许可、加算减伤和生命状态，不依赖主角、敌人、稻草人或某种技能。技能产生 `HitData`；`DamageReceiver` 先判定命中能否生效，通过后结算伤害；`Combatant` 应用生命变化和零血行为。角色控制、AI、剧情和血条表现由其他模块处理。未实现暴击、护盾、正式反弹技能与击退响应，`knockback` 仍为保留参数。

## 文件与接口

- `hit_data.gd`：`HitData extends RefCounted`，一次命中的数据。`source` 是唯一当前伤害归属者；`set_source(actor)` 更换归属，直接赋值 `source` 也调用相同的身份缓存逻辑。`skill_id` 默认空；`damage` 默认 `0`；`damage_type` 默认 `physical`；`origin` 默认 `(0, 0)`；`direction` 默认右；`knockback` 默认 `0`，单位为像素/秒。伤害与击退必须有限且非负，位置与方向必须为有限向量，伤害类型不可为空。
- `damage_receiver.gd`：`DamageReceiver extends Area2D`。目标提供 `CollisionShape2D`。`enabled` 默认 `true`，`combatant_path` 默认 `../Combatant`；`get_combatant()` 解析此路径。`receive_hit(hit) -> bool` 表示是否接受本次命中，只有通过许可、状态检查和结算后才发 `hit_received(hit)`。`last_damage` 保存本次结算伤害，拒绝时为 `0`。允许命中但减伤达到 100% 时返回 `true`，`last_damage` 与 `damaged.amount` 为零；`hit_received` 中的 HitData.damage 保留攻击基数，不会按目标改写。
- `combatant.gd`：`Combatant extends Node`，通常作为 actor 的 `Combatant` 子节点。事件为 `health_changed(current, maximum)`、`state_changed(state)`、`faction_changed(faction)`、`damaged(hit, amount)`。`damaged.amount` 为本次结算伤害，过量伤害不变为负生命。伤害结算仍只有 receiver 执行，血条不会自行修改生命。

碰撞位约定：场景实体 `1`，主角 `2`，受击区域 `4`，火球 `8`；稻草人实体可使用 `16`。这些数字是 bitmask 值。Receiver 默认 `collision_layer = 4`、`collision_mask = 0`、`monitoring = false`、`monitorable = true`；由攻击查询接触目标，不使用 receiver 的主动监测。

## 阵营、目标规则和默认值

`Combatant.Faction` 为平等的 `FRIENDLY`、`ENEMY`、`NEUTRAL`，默认 `NEUTRAL`。仅比较阵营相同或不同，不引入关系矩阵。中立默认可受伤；同为中立的单位属于同阵营。角色剧情转阵营修改 `faction`，同步发阵营变化事件。命中时读取仍在世来源的当前阵营；来源消失后保留最后捕获的身份与阵营，不自动转为环境伤害。

`HitData.TargetPolicy` 与 `damage_type` 独立；每次攻击可选择不同规则。

| 规则 | 不同阵营 | 同阵营其他单位 | 当前来源本人 |
| --- | --- | --- | --- |
| `OTHER_FACTIONS`，默认 | 允许，无额外减伤 | 拒绝 | 拒绝 |
| `OTHER_FACTIONS_AND_SELF` | 允许，无额外减伤 | 拒绝 | 允许，追加 `self_reduction` |
| `ALL_WITH_SAME_FACTION_REDUCTION` | 允许，无额外减伤 | 允许，追加 `same_faction_reduction` | 同样追加 `same_faction_reduction` |
| `ALL` | 允许，无额外减伤 | 允许，无额外减伤 | 允许，无额外减伤 |

`self_reduction`、`same_faction_reduction` 默认均 `0.5`，单位是比例，须为有限的 `0..1`。规则 2 判本人优先于判同阵营。规则 4 适合无主环境和需要伤害所有单位的中立攻击；中立身份本身不会替攻击改规则。`set_environment()` 显式清空来源、设置 `is_environment = true` 与 `ALL`；有环境标识但非 `ALL` 是无效配置。普通角色放置的陷阱继续用角色归属。

兼容首版没有 `Combatant` 的稻草人与物理 fixture：receiver 视为 `NEUTRAL`，仅报告命中与结算量；没有 `Combatant` 的发动者以及未填写来源的旧手造数据默认归属 `FRIENDLY`。此兼容路径不将未知来源视为 `ALL`。正式可战斗角色应提供 `Combatant` 并显式指定阵营。

反弹的归属入口是 `hit.set_source(reflector)`，后续阵营与自伤全部按反弹者计算，不保留另一套原始来源。更换归属不会重新计算攻击基数或叠加反弹者攻击属性；正式反弹的接触行为不在本轮实现。

## 结算与生命状态

1. 拒绝空数据、无效配置、禁用 receiver 与不符合目标规则的攻击。
2. 绑定 `Combatant` 时，拒绝无敌、击倒、死亡或无效生命配置；不进入伤害类型计算。
3. 根据 `damage_type` 查询 `resistances`，将类型抗性、`general_reduction` 与适用的自伤/同阵营减伤加算。总减伤限制为 `0..1`；最终伤害为 `damage × (1 − 总减伤)`。例如 100 火焰伤害、20% 火焰抗性、规则 2 的 50% 自伤减伤，最终为 30。抗性键使用技能的伤害类型标识；未配置抗性默认为 0。
4. 通过 `Combatant.apply_damage(hit, amount) -> bool` 应用已结算伤害，再由角色和血条响应事件。

生命默认 `max_health = 100`、当前生命初始化为最大生命；`invulnerable = false`、`general_reduction = 0`、`resistances = {}`、`zero_health_behavior = DEATH`。最大生命必须有限且大于零；各减伤和抗性为有限 `0..1`。`validate() -> Array[String]` 可读取配置错误，错误配置拒绝伤害与恢复。

`LifeState` 为 `ACTIVE`、`DOWNED`、`DEAD`，默认正常。生命从正数首次降到零时，`ZeroHealthBehavior.DEATH` 转死亡，`KNOCKDOWN` 转击倒；已击倒/死亡目标不会被补刀，也不会重复触发零血行为。死亡不由 UI 或 `current_health == 0` 推导。

- `reset_state()`：训练重置取消恢复计时，恢复最大生命与正常状态；保留阵营、无敌和零血配置。
- `force_death()`：剧情死亡入口，绕过无敌与零血行为，清零生命、取消恢复计时；已死亡时不重复发事件。
- `recover(positive_health) -> bool`：仅击倒单位可起身，恢复血量须有限且大于零，上限为最大生命；不会复活死亡单位。
- `assist_recover(helper: Combatant, positive_health) -> bool`：同阵营、非本人、正常状态的帮助者才可解除击倒。距离与交互由后续角色/交互模块判断，本轮不新增交互按键。
- `schedule_recovery(delay, positive_health) -> bool`：仅击倒单位可显式开启恢复计时；秒数有限且非负，零秒立即恢复。默认没有自动恢复，也没有预设恢复时间/血量。死亡、重置、起身都会取消计时。

## 扩展方法

新增角色时添加 `Combatant`、receiver 和碰撞形状，并连接生命/状态/受伤事件。统一生命只由 `Combatant` 更新，不能再在 `hit_received` 回调中重复扣血；统计使用 receiver 的 `last_damage`。传统训练稻草人可继续保持无生命的统计单位。新增命中字段须同时明确默认值、单位、校验和接收者，修改此文档并回归已有攻击。

## 验证与当前状态

固定测试入口与证据读取方法见 `../docs/testing.md`。实际结果以 `../artifacts/test-runs/latest.json` 指向的本轮报告为准，模块代码落盘不能视为测试通过。自动测试应覆盖四种规则与三阵营、自己/队友区别、50% 默认值、加算抗性、总减伤封顶、当前归属切换、动态阵营、环境、无敌剧情死亡、击倒不可补刀、帮助/计时恢复、死亡取消恢复，以及近战/火球真实碰撞回归。

玩法手感由用户反馈。范围不包括敌人 AI、正式剧情与交互操作、护盾或完整伤害成长公式。投射物命中不接受伤害的目标后是否穿过仍由技能接触规则决定，不由目标许可自动改变。
