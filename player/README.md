# 主角模块

## 职责与依赖

`player_character.tscn` 是脚底为原点的 CharacterBody2D，碰撞 22 × 54 px，世界层 1、角色层 2。`player_character.gd` 处理输入意图、加减速、重力、跳跃、平台/墙体碰撞；`player_visual.gd` 只显示纹理、翻转、轻微移动偏移与施法蓄力提示。依赖 shared 输入配置及 skills 动作控制/执行器；视觉不影响伤害范围。

## 可调整初值

Inspector 的 move_speed=210 px/s，acceleration=1600 px/s²，deceleration=2000 px/s²，gravity=1150 px/s²，jump_speed=450 px/s，max_fall_speed=700 px/s；coyote_seconds 与 jump_buffer_seconds 均 0.1 s。土狼时间允许短暂离开平台后跳跃，跳跃缓冲允许落地前的短暂输入；两者不提供无限空中跳跃。

Actions 按物理帧 tick。每阶段的 inertia_scale 只在进入阶段时缩放水平惯性，control_scale 缩放玩家目标移动速度，skill_velocity 的 x 按面朝方向转换；can_jump 决定该阶段能否起跳。角色不根据具体技能名称硬编码动作运动。前摇期间可以转向；进入执行阶段后直到后摇结束，朝向锁定，但仍可按策略向左右移动，保证近战视觉、释放点与实际命中方向一致。

主动取消与受击中断已作为 ActionController 的独立策略/API 保留，并有自动行为测试；当前没有绑定主动取消按键，主角也没有受伤链路。允许跳跃只是允许在动作中起跳，不自动取消动作。加入取消输入或真实敌人时需接入这些接口并补玩家可观察的回归。

## 公共接口与扩展

- `request_attack()` / `request_fireball()` 返回动作是否被接受；忙碌或冷却拒绝，不缓存攻击连招。
- `get_action_controller()` 供界面/测试读取；`get_attack_origin()` 提供脚底上 28 px、面朝方向前 15 px 的释放点。
- `set_fireball_level(1|2)` 只重绑下一次施法定义，正在执行的动作保持开始时的定义。
- `set_control_input(horizontal, jump_requested)` 启用外部输入意图；跳跃单次消费。`clear_control_override()` 恢复真实键盘输入。测试、后续回放可以通过同一控制路径驱动真实物理。
- `reset_state(position)` 无条件重置动作/冷却、位置与运动状态；外部控制模式保留以方便测试重置，真实训练场原本使用键盘模式。

新增技能先完成 skills 定义/执行器，然后在角色的绑定和输入映射处注册。已有控制器无需理解新行为。若加入墙跳、滑铲、锁定朝向等新移动机制，必须明确与阶段策略的组合并更新行为测试。

## 替换角色素材

静态图通过 Visual 的 texture、texture_region、display_height 配置替换；当前 region=Rect2(348,46,578,1173)，显示高度 58 px。保留脚底原点和独立碰撞。后续 AnimatedSprite2D 可替换 Visual 实现，保留 `update_state(actor,delta)`，无需改伤害逻辑。素材来源和实际限制见 assets/README.md。

## 验证与限制

统一入口 `node tools/check.mjs --scope game` 检查真实主场景中的移动/跳跃/碰撞与攻击。没有正式行走、跳跃或攻击动画；当前程序偏移不等同于动画素材。手感待用户反馈。
