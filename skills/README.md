# 技能与动作模块

## 职责与结构

此模块将技能参数、等级差异、运行阶段和技能行为分开。输入映射与角色移动由主角模块负责；受击协议由 `../combat/` 提供。没有技能树 UI、消耗系统或解锁条件。

| 文件 | 职责 |
| --- | --- |
| `skill_definition.gd` | Inspector 可见的基础参数、等级解析与最终值检查 |
| `skill_level_override.gd` | 等级差异，未填写的字段继承前一等级 |
| `phase_policy.gd` | 每个阶段的移动、跳跃及中断约束 |
| `action_controller.gd` | 通用阶段推进、冷却、启动条件与中断 |
| `skill_executors.gd` | 首版普攻和火球执行器；动作进入执行阶段时调用一次 |
| `melee_strike.gd` | 近战执行期间持续扫描受击区域，同一目标每次攻击只命中一次 |
| `fireball.gd` | 火球的方向、移动、扫掠命中、寿命/距离清理和可替换占位表现 |
| `definitions/*.tres` | 可直接在 Godot Inspector 编辑的首版技能配置 |

## 属性语义

`SkillDefinition` 默认值如下；正式技能资源的覆盖值见后表。

| 属性 | 默认值 | 含义与单位 |
| --- | --- | --- |
| `id` / `display_name` / `damage_type` | `skill` / `Skill` / `physical` | 稳定标识、显示名、伤害类别 |
| `damage` / `knockback` | `10` / `0` | 单次伤害；击退速度，像素/秒，目前接收但尚不施加 |
| `windup_seconds` / `active_seconds` / `recovery_seconds` | `0.1` / `0.1` / `0.1` | 前摇、执行、后摇秒数；`0` 明确表示没有该阶段 |
| `cooldown_seconds` | `0.3` | 从启动时计算的冷却秒数；取消不退还冷却 |
| `melee_reach` / `melee_height` | `48` / `42` | 从攻击点向面朝方向延伸的矩形尺寸，像素 |
| `projectile_speed` / `projectile_lifetime` / `projectile_range` | `430` / `2` / `900` | 像素/秒、秒、像素；达到寿命或距离任一限制即移除 |
| `level_overrides` | 空列表 | `SkillLevelOverride` 资源；每等级唯一，按等级升序累积应用 |

`windup_policy`、`active_policy`、`recovery_policy` 各自是一份 `PhasePolicy` 资源。默认 `control_scale = 1`、`inertia_scale = 1`、`skill_velocity = (0, 0)`；`can_jump`、`can_cancel_player`、`can_interrupt_hit` 均为 `true`。比例在 `0..1`；技能位移单位为像素/秒，其 X 方向由主角按面朝方向转换。角色负责执行移动规则，控制器只提供策略。

`control_scale` 控制玩家输入产生的目标水平速度比例；`inertia_scale` 表示开始动作时水平惯性保留比例。具体加速和惯性衰减由主角模块记录，避免把相同比例误解成相同手感。主动取消与受击中断独立配置。

数值不能为 `null`、负数或非有限值；尺寸、投射物速度、寿命与距离必须大于零。资源的 `null` policy、未知覆盖字段、错误类型、重复等级、低于 1 的等级均产生可读取的解析错误，控制器拒绝启动。没有后摇使用 `recovery_seconds = 0`；等级覆盖未填字段表示继承；未配置/类型错误属于配置错误，不能混成“没有阶段”。

## 首版配置（暂定，等待试玩反馈）

| 参数 | 普通攻击 | 火球术 |
| --- | --- | --- |
| `id` | `basic_attack` | `fireball` |
| 伤害 | `20` | `35`，伤害类型 `fire` |
| 前摇 / 执行 / 后摇 | `0.08 / 0.12 / 0.17` 秒 | `0.5 / 0.08 / 0.22` 秒 |
| 冷却 | `0.37` 秒 | `0.9` 秒 |
| 三阶段输入控制比例 | `0.55 / 0.45 / 0.75` | `0.25 / 0.25 / 0.5` |
| 三阶段惯性比例 | `0.8 / 0.65 / 0.8` | `0.35 / 0.35 / 0.5` |
| 三阶段主动取消 | `false / false / true` | `false / false / true` |
| 三阶段跳跃 | 均 `true` | `false / false / true` |
| 三阶段受击中断 | 均 `true` | 均 `true` |
| 额外参数 | 攻击矩形 `54 × 44` 像素 | 速度 `430`；寿命 `2` 秒；距离 `900` 像素 |

两个技能三阶段技能位移均为 `(0, 0)`。火球二级只通过 `values = {"windup_seconds": 0.2}` 缩短前摇，伤害仍为 `35`；首版主角使用一级，二级配置用于验证等级扩展，尚无升级 UI。

## 启动、阶段与行为接口

主角创建 `ActionController` 子节点后调用：

1. `bind_action(action_id: StringName, definition: SkillDefinition, executor: Callable, level: int = 1)` 注册。执行器接收 `(caster: Node, resolved_definition: SkillDefinition)`。
2. `request_action(action_id, caster) -> bool` 尝试启动。正在出招、未装备、冷却中、定义无效或执行器无效时返回 `false`。
3. 主角每个物理帧调用一次 `tick(delta)`，控制器不会自动再计时。先更新全部技能冷却，再推进 `WINDUP → ACTIVE → RECOVERY → IDLE`；零秒阶段立即跳过，大 `delta` 会继续消耗后续阶段时间。
4. `get_movement_policy()` 返回当前阶段字典；空闲时返回不限制移动的默认策略。
5. `cancel(&"player")` 检查主动取消；`cancel(&"hit")` 检查受击中断。未知原因拒绝取消。返回值表示是否实际结束动作。
6. `reset_state()` 为训练场重置无条件清空冷却与当前动作，不检查阶段中断许可。非空闲时发出取消完成事件，空闲时只清理引用。场景重置另行删除已发布火球和近战窗口。

可读取 `phase`（`Phase.IDLE/WINDUP/ACTIVE/RECOVERY`）、`phase_remaining`、`active_definition`、`active_action_id`；通过 `get_definition(action_id)`、`get_cooldown_remaining(action_id)` 查看绑定后的最终属性和冷却。这些运行对象视为只读，不用于写回基础资源。

事件为 `phase_changed(phase)`、`activated(action_id, definition, caster)`、`completed(action_id, cancelled)`。执行器只在进入 `ACTIVE` 时调用一次。动作取消结束角色动作，已经发射的火球继续存在；已经生成的近战窗口按自身 `active_seconds` 清理。后者未来如需要“取消立即撤销命中窗口”须补行为契约与回归测试。

`SkillExecutors.melee/fireball` 只要求发动者为已进入场景树的 `Node2D`、提供 `facing_direction`（负值向左）与 `get_attack_origin() -> Vector2`。实体加入 `current_scene`，测试没有当前场景时加入发动者父节点。火球期望出生点为攻击点向前偏移 18 像素，但生成前会从角色中心 X、攻击点 Y 组成的内部锚点向该位置扫掠场景实体。若有墙阻挡，就从内部锚点发射，由火球后续的物理扫掠撞墙销毁，不能越过薄墙出生。近战位置随攻击点移动，方向在启动时固定。

`Fireball` 默认碰撞 layer `8`、mask `5`（场景 `1` 加受击区 `4`）。每物理帧对移动线段做真实物理 ray query，遇到第一个场景实体/受击区即消失；受击区调用统一 `receive_hit`。投射物不穿透，无论是否接收伤害都在接触时销毁。`spent` 防止重复命中；首版碰撞使用中心线，视觉外缘不是额外命中半径。火球和近战窗口在已经进入删除队列时不再处理物理帧，避免训练场重置后出现延迟伤害。

## 等级与新技能扩展

`resolve_level(level) -> SkillDefinition` 深拷贝基础资源，按等级累积覆盖，返回独立最终值；基础资源和其他角色等级不受修改。`resolution_errors` 保留配置诊断，`get_resolved_attributes()` 提供 ID、等级、时序、移动规则与最终数值，后续调试面板可直接读取。

等级 `values` 支持本模块数值字段，以及如 `windup_policy.control_scale`、`active_policy.can_cancel_player`、`recovery_policy.skill_velocity` 的路径。未声明的机制不通过任意拼写悄悄接受：新增属性须定义含义/单位/默认值，扩展白名单与校验，同步文档和测试。

新增已有机制技能时，新增 `.tres`、独立执行器（可放在新文件）并在主角装备映射调用 `bind_action`。无需修改控制器和 receiver。首版以近战扫描与独立火球验证不同执行行为共用同一阶段/冷却/命中框架；全新机制需要公共改动时说明影响并做回归，不能只凭架构声明认为扩展验证已通过。

## 测试与遗留事项

固定入口、报告读取和错误处理见 `../docs/testing.md`、`../docs/errors/README.md`。每次技能代码、参数或规则变化，同步此文档并立即执行相关测试。当前测试证据以 `../artifacts/test-runs/latest.json` 所指本轮报告为准。

自动测试应覆盖：等级变化不污染基础资源；阶段边界/零秒/大时间步；执行一次；冷却与中断；配置错误拒绝；不同技能执行器复用控制器；近战距离与单次命中；火球方向、墙体拦截、贴墙发射、单次伤害、寿命与距离清理；已加入删除队列的攻击不再造成伤害。操作手感由用户独立反馈，数值仅为可试玩基准。
