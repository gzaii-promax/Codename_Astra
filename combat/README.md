# 公共战斗模块

## 职责和边界

此模块提供统一的心伤害数据、目标许可和生命状态，不依赖主角、敌人、稻草人或某种技能。技能产生 `HitData`；`DamageReceiver` 先判定命中能否生效，通过后将完整心伤害交给 `Combatant`。角色控制、AI、剧情和心容器绘制由其他模块处理。旧一般减伤、类型抗性、自伤减伤、同阵营减伤及相关公式已删除；本轮不引入新的增伤/减伤公式。未实现暴击、护盾、正式反弹技能与击退响应，`knockback` 仍为保留参数。

## 心容器与伤害单位

`max_health`、只读 `current_health`、`HitData.damage`、`DamageReceiver.last_damage`、生命与受伤事件的数值都以“心”为单位。一个完整心容器容纳两个半心；普通命中可配置 `0.5` 心，强化命中可配置 `1`、`2`、`3` 或更多心。伤害必须有限、非负且严格为 `0.5` 的倍数，非法值拒绝，不四舍五入；`0` 心伤害合法，仍报告一次接受命中，不扣心。

`Combatant` 内部以整数半心存储生命，公开 getter 与事件保持心单位的 `float` 接口，避免重复半心扣除产生浮点漂移。`max_health` 默认 `3`，必须为正整数容器；最大允许 `4503599627370495` 个容器，以保证半心值可精确表示并可安全存储。Inspector 推荐范围 `1..100000`，允许更大合法值。伤害没有额外游戏上限；转换为整数半心前先裁到当前生命，巨大过量伤害也不会使生命存储溢出。

当前角色配置由各角色场景/模块提供：主角 `3` 心上限，普通攻击 `0.5` 心、火球术 `1` 心；定时敌人 `3` 心上限、每击 `0.5` 心；稻草人 `10` 心上限，归零立即回满。

## 文件与接口

- `hit_data.gd`：`HitData extends RefCounted`，一次命中的数据。`source` 是唯一当前伤害归属者；`set_source(actor)` 更换归属，直接赋值 `source` 也调用相同身份缓存逻辑。`skill_id` 默认空；`damage` 默认 `0` 心；`damage_type` 默认 `physical`，仅分类，不改变扣心；`origin` 默认 `(0, 0)`；`direction` 默认右；`knockback` 默认 `0`，单位为像素/秒。伤害按上述半心规则校验，击退须有限且非负，位置与方向须为有限向量，伤害类型不可为空。`is_valid_damage(amount)` 是伤害/恢复与技能共用的严格半心校验入口。
- `damage_receiver.gd`：`DamageReceiver extends Area2D`。目标提供 `CollisionShape2D`。`enabled` 默认 `true`，`combatant_path` 默认 `../Combatant`；`get_combatant()` 解析此路径。`receive_hit(hit) -> bool` 表示是否接受本次命中，只有通过许可、状态检查和扣心后才发 `hit_received(hit)`。接受时 `last_damage = hit.damage`，拒绝时为 `0`；`hit_received` 中的 `HitData.damage` 保持完整攻击值。
- `combatant.gd`：`Combatant extends Node`，通常作为 actor 的 `Combatant` 子节点。事件为 `health_changed(current, maximum)`、`state_changed(state)`、`faction_changed(faction)`、`damaged(hit, amount)`。`damaged.amount` 与 receiver 的 `last_damage` 均记录完整接受伤害，包括过量伤害；生命最低为零，不因统计量产生负生命。UI 只响应事件，不自行修改生命。

碰撞位约定：场景实体 `1`，主角 `2`，受击区域 `4`，火球 `8`；稻草人实体可使用 `16`。这些数字是 bitmask 值。Receiver 默认 `collision_layer = 4`、`collision_mask = 0`、`monitoring = false`、`monitorable = true`；由攻击查询接触目标，不使用 receiver 的主动监测。

## 阵营、目标规则和默认值

`Combatant.Faction` 为平等的 `FRIENDLY`、`ENEMY`、`NEUTRAL`，默认 `NEUTRAL`。仅比较阵营相同或不同，不引入关系矩阵。中立默认可受伤；同为中立的单位属于同阵营。角色剧情转阵营修改 `faction`，同步发阵营变化事件。命中时读取仍在世来源的当前阵营；来源消失后保留最后捕获身份与阵营，不自动转为环境伤害。

`HitData.TargetPolicy` 与 `damage_type` 独立；每次攻击可选择不同规则。

| 规则 | 不同阵营 | 同阵营其他单位 | 当前来源本人 |
| --- | --- | --- | --- |
| `OTHER_FACTIONS`，默认 | 允许 | 拒绝 | 拒绝 |
| `OTHER_FACTIONS_AND_SELF` | 允许 | 拒绝 | 允许 |
| `ALL` | 允许 | 允许 | 允许 |

所有允许目标直接承受相同完整心伤害，不因自己/友方或伤害分类减伤。规则 2 判本人优先于判同阵营。`ALL` 适合无主环境和需要伤害所有单位的攻击；中立身份本身不会替攻击改规则。`set_environment()` 显式清空来源、设置 `is_environment = true` 与 `ALL`；有环境标识但非 `ALL` 是无效配置。普通角色放置的陷阱继续用角色归属。删除旧减伤枚举后 `ALL` 枚举值为 `2`；不得继续使用旧规则值 `3` 或旧减伤属性。

兼容没有 `Combatant` 的物理 fixture：receiver 视为 `NEUTRAL`，仅报告命中与完整伤害；没有 `Combatant` 的发动者以及未填写来源的旧手造数据默认归属 `FRIENDLY`。此兼容路径不将未知来源视为 `ALL`。正式可战斗角色提供 `Combatant` 并显式指定阵营；训练稻草人也已接入生命与回满规则。

反弹的归属入口是 `hit.set_source(reflector)`，后续阵营与自伤全部按反弹者计算，不保留另一套原始来源。更换归属不会重新计算攻击值或叠加反弹者攻击属性；正式反弹接触行为不在本轮实现。

## 扣心与生命状态

1. 拒绝空数据、非法半心值、无效配置、禁用 receiver 与不符合目标规则的攻击。
2. 绑定 `Combatant` 时，拒绝无敌、击倒、死亡或无效生命配置。
3. 直接调用 `Combatant.apply_damage(hit, hit.damage) -> bool` 应用完整心伤害；所有伤害分类、允许的自伤和友伤使用相同扣心规则。
4. 接受命中后发事件，角色响应受击、中断，UI 更新心容器，统计保留完整伤害。

生命默认当前与最大都是 `3` 心；`invulnerable = false`，`zero_health_behavior = DEATH`。`validate() -> Array[String]` 可读取配置错误，错误配置拒绝伤害与恢复。

`LifeState` 为 `ACTIVE`、`DOWNED`、`DEAD`，默认正常。生命从正数首次降到零时，`ZeroHealthBehavior.DEATH` 转死亡，`KNOCKDOWN` 转击倒；已击倒/死亡目标不能被补刀，也不重复触发零血行为。死亡不由 UI 或 `current_health == 0` 推导。

`ZeroHealthBehavior.REFILL` 在同一次伤害应用中立即回满并保持 `ACTIVE`，不发死亡/击倒状态事件；`health_changed` 报告回满后的生命。本次完整攻击仍只记一次 `damaged` 与 `hit_received`，之后可继续受击。若 `10` 心稻草人剩 `0.5` 心时接受 `3` 心伤害，立即回到 `10` 心，统计仍增加 `3` 心。

- `reset_state()`：训练重置取消恢复计时，恢复最大生命与正常状态；保留阵营、无敌和零血配置。
- `force_death()`：剧情死亡入口，绕过无敌与零血行为（包括 `REFILL`），清零生命、取消恢复计时；已死亡时不重复发事件。
- `recover(positive_health) -> bool`：仅击倒单位可起身，恢复血量须有限、严格为正的 `0.5` 倍数；恢复值裁到最大生命，不复活死亡单位。
- `assist_recover(helper: Combatant, positive_health) -> bool`：同阵营、非本人、正常状态帮助者才可解除击倒。距离与交互由后续角色/交互模块判断，本轮不新增交互按键。
- `schedule_recovery(delay, positive_health) -> bool`：仅击倒单位可显式开启恢复计时，恢复值使用相同半心规则；秒数有限且非负，零秒立即恢复。默认没有自动恢复，也没有预设恢复时间/血量。死亡、重置、起身都会取消计时。

## 扩展方法

新增角色时添加 `Combatant`、receiver 和碰撞形状，配置整数心容器上限与零血行为，并连接生命/状态/受伤事件。统一生命只由 `Combatant` 更新，不能在 `hit_received` 回调重复扣心；统计使用 receiver 的 `last_damage`。强化攻击通过合法半心伤害值表达；新机制不得恢复旧百分比减伤公式。新增命中字段须明确默认值、单位、校验和接收者，修改此文档并回归已有攻击。

## 验证与当前状态

固定测试入口与证据读取方法见 `../docs/testing.md`。实际结果以 `../artifacts/test-runs/latest.json` 指向的本轮报告为准，模块代码落盘不能视为测试通过。自动测试应覆盖三种规则与三阵营、自己/队友区别、所有允许目标的相同心伤害、严格半心与整数容器校验、强化和零伤害、过量伤害统计、稻草人反复回满、归属切换、动态阵营、环境、无敌剧情死亡、击倒不可补刀、半心帮助/计时恢复、死亡取消恢复，以及近战/火球真实碰撞回归。

玩法手感由用户反馈。范围不包括敌人 AI、正式剧情与交互操作、护盾或完整伤害成长公式。投射物命中不接受伤害目标后是否穿过仍由技能接触规则决定，不由目标许可自动改变。
