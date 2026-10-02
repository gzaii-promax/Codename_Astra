# 主角模块

## 职责与依赖

`player_character.tscn` 是脚底为原点的 CharacterBody2D，身体碰撞框与独立受击框均宽 1U、高 2U，即 16 × 32 px，中心位于脚底上 1U；世界层 1、角色层 2。`player_character.gd` 处理输入意图、加减速、重力、可变高度跳跃、平台/墙体碰撞；`player_visual.gd` 只显示纹理、翻转、轻微移动偏移与施法蓄力提示。依赖 shared 输入配置、GameUnits 单位基准及 skills 动作控制/执行器；视觉不影响伤害范围。当前 1U=16 个游戏逻辑像素，单位入口见 ../shared/README.md。

## 可调整初值

用户采纳的 Inspector 初值是 move_speed=1.5U/s（24 px/s），min_jump_height=1U（16 px）、max_jump_height=2.5U（40 px）。跳高指起跳脚底到最高点脚底的竖直上升距离，平地、无顶碰撞且不叠加技能竖直位移时测量。持续持键达到最高跳；首次松键按当前已上升距离限制剩余上升速度：尚未达到 1U 时继续升到约 1U，已达到 1U 时结束上升，因此更晚松键可以得到 1U 到 2.5U 之间的高度。松键后重按不恢复本次上升能力；一直持键落地也不自动再次起跳。

工程配套初值为 acceleration=12U/s²（192 px/s²）、deceleration=16U/s²（256 px/s²）、gravity=25U/s²（400 px/s²）、max_fall_speed=25U/s（400 px/s）；这些值是实施选择，尚未得到用户手感验收。起跳速度由跳高与重力推导，并修正物理帧离散积分，正常 60Hz 下短跳约 0.28 s 到顶、长跳约 0.44 s 到顶，不通过直接改位置实现跳高。Inspector 的高度和重力应保持正数，min_jump_height 不得高于 max_jump_height。

coyote_seconds 与 jump_buffer_seconds 均 0.1 s。土狼时间允许短暂离开平台后跳跃，跳跃缓冲允许落地前的短暂输入；缓冲输入在落地前已松键时仍产生短跳。两者不提供无限空中跳跃。

Actions 按物理帧 tick。每阶段的 inertia_scale 只在进入阶段时缩放水平惯性，control_scale 缩放玩家目标移动速度，skill_velocity 的 x 按面朝方向转换；can_jump 决定该阶段能否起跳。角色不根据具体技能名称硬编码动作运动。前摇期间可以转向；进入执行阶段后直到后摇结束，朝向锁定，但仍可按策略向左右移动，保证近战视觉、释放点与实际命中方向一致。

主动取消与受击中断为 ActionController 的独立策略/API。当前未绑定主动取消按键；主角现接入 DamageReceiver 和 Combatant，正伤害调用受击中断，仍遵循各阶段 can_interrupt_hit；成功中断撤销本角色近战窗口，保留冷却。允许跳跃只是允许在动作中起跳，不自动取消动作。死亡/击倒无条件结束动作并撤销本角色已打开的近战窗口，停止输入和新攻击，重力继续使角色落地；独立已发射投射物继续存在。

## 公共接口与扩展

- `request_attack()` / `request_fireball()` 返回动作是否被接受；忙碌或冷却拒绝，不缓存攻击连招。
- `get_action_controller()` 供界面/测试读取；`get_attack_origin()` 提供脚底上 1U（16 px）、面朝方向前 0.5U（8 px）的释放点。技能攻击框的尺寸和动作时序继续由技能定义维护，不随身体尺寸等比缩放。
- `get_combatant()` 提供公共生命、阵营、无敌、零血行为和生命周期配置。场景默认 FRIENDLY、3 个心容器且初始 3 心、无敌关闭、零血死亡。DamageReceiver 使用独立 1U × 2U（16 × 32 px）受击区；HealthBar 位于脚底上 82 px，订阅同一 Combatant 并绘制完整、半颗、空心。普攻 0.5 心、火球 1 心；无旧抗性/增减伤。公共规则与默认值见 ../combat/README.md 和 ../docs/heart-health-v5.md。
- 主角 `_ready()` 从 `CombatConfig.PLAYER_HIT_PROTECTION_SECONDS` 设置 0.5 秒受击保护；心单位与保护共存，暂停冻结、重置清零，参见 ../docs/hit-protection.md。
- `set_fireball_level(1|2)` 只重绑下一次施法定义，正在执行的动作保持开始时的定义。
- `set_control_input(horizontal, jump_requested=false, jump_held=false)` 启用外部输入意图；jump_requested 是单次消费的起跳请求，jump_held 是保持到下次调用的持键状态。旧两参数跳跃调用表示短按；长按用 `set_control_input(0.0, true, true)` 起跳，松开时调用 `set_control_input(0.0, false, false)`。真实键盘分别读取 `Input.is_action_just_pressed("jump")` 和 `Input.is_action_pressed("jump")`，走相同跳跃路径。当前上升期间，外部松键提交与真实 `_input` 松键事件都会锁存到下一物理帧，因此同一物理帧间松开后重按仍会截断本次上升；锁存不会带入下一次跳跃。`clear_control_override()` 恢复真实键盘输入并清除输入锁存。测试、后续回放可以通过同一控制路径驱动真实物理。
- `reset_state(position)` 无条件重置生命/生命周期、动作/冷却、位置与运动状态；外部控制模式保留以方便测试重置，真实训练场使用键盘模式。训练场整体重置同时删除场上效果并恢复敌人。
- `relocate_to(position,facing=1)` 用于正常切房：调用动作控制器的 `finish_for_transition()` 结束当前阶段并保留冷却，撤销本人近战窗口，清空惯性、跳跃缓冲与松键锁存，脚底安置到入口并设置朝向。生命、技能等级、受击保护与外部控制模式保留；地图管理器同时清理场上旧效果。此接口不替代无条件重置。

新增技能先完成 skills 定义/执行器，然后在角色的绑定和输入映射处注册。已有控制器无需理解新行为。若加入墙跳、滑铲、锁定朝向等新移动机制，必须明确与阶段策略的组合并更新行为测试。

## 替换角色素材

静态图通过 Visual 的 texture、texture_region、display_height 配置替换；当前 region=Rect2(348,46,578,1173)，显示高度 2U（32 px）。保留脚底原点和独立碰撞；施法提示与当前释放点对齐。后续 AnimatedSprite2D 可替换 Visual 实现，保留 `update_state(actor,delta)`，无需改伤害逻辑。素材来源和实际限制见 assets/README.md。

## 验证与限制

统一入口 `node tools/check.mjs --scope game` 检查真实主场景中的移动速度、短/中/长跳峰高、真实键盘按松、跳跃缓冲/土狼时间、碰撞与攻击；实际执行状态以最新测试报告为准。没有正式行走、跳跃或攻击动画；当前程序偏移不等同于动画素材。手感待用户反馈。
