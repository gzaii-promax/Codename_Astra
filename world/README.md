# 训练场模块

## 职责

`training_arena.tscn` 是主场景，包含 Player、TrainingDummy、PeriodicEnemy、HUD。`training_arena.gd` 创建 gray box 几何、输入配置、R 重置与 F2 等级调试；`training_dummy.gd/.tscn` 提供无限生命受击目标；`periodic_enemy.gd/.tscn` 提供固定周期近战敌人。公共矩形地形创建在 shared/graybox_solid.gd。

逻辑画布 960 × 540，地板上沿 y=430，主角脚底初始 (150,430)，目标脚底 (645,430)。两个平台分别是 Rect2(275,366,145,18)、Rect2(760,350,120,18)，左右墙宽 20 px。平台当前是普通实心碰撞，没有单向平台或下落穿透机制。灰色几何与网格用于测试，尚无正式地图美术。

## 稻草人与接口

稻草人受击区 28 × 60 px，中心在脚底上 32 px；没有实体阻挡玩家，无 AI、生命条或死亡。无 Combatant 的 receiver 默认为中立，仍遵循攻击携带的四种目标规则。稻草人在 accepted signal 中使用 receiver.last_damage 累计最终伤害和显示浮动数字；last_hit.damage 保留攻击基数。`total_damage`、`hit_count`、`last_hit` 可读取，`get_receiver()` 给测试使用，`reset_stats()` 清零并发 `stats_changed`。屏幕提供短暂闪色。

当前累计伤害不是 DPS：统计时间窗、有效战斗时长、多目标与分技能统计需在后续定义，不能用首版显示值当作每秒伤害。

`reset_training()` 无条件恢复主角与敌人的生命/生命周期、位置/动作/冷却和敌人攻击时钟，删除已发布火球和攻击效果，清空稻草人统计。F2 在 1/2 级火球间切换，不重置正在施放的动作。

地图房间名和目标标签经 Localization.text() 读取 `arena.room`、`arena.target`、`arena.enemy`，使用随语言配置的字体，语言切换信号触发重绘。暂停菜单和语言设置归 ui/localization，世界模块不保存语言，也不定义译文。

## 固定周期敌人

`PeriodicEnemy extends Node2D` 固定在场景位置，默认面向左，每 1.5 秒尝试开始一次近战动作；第一次也等待完整间隔。攻击没有目标搜索、转向、追击、巡逻或寻路；只有处在面向一侧攻击范围内的受击区才会被实际命中。时间间隔从动作开始计算，动作未结束或技能冷却未完成时本次尝试失败，不累积排队攻击。菜单暂停会同时暂停时钟和动作。

敌人通过公共 `ActionController` 和 `SkillExecutors.melee` 执行 `skills/definitions/enemy_attack.tres`：伤害 10、前摇 0.30 秒、执行 0.12 秒、后摇 0.25 秒、冷却 0.67 秒、近战范围 72 × 48 px。伤害目标规则与来源由公共技能/战斗模块生成；敌人不另写一套扣血公式。`attack_interval`、`attack_enabled`、`facing_direction` 可在 Inspector 配置。关闭攻击立即取消当前动作及本人尚在执行的近战窗口，重新开启后等待完整间隔。

场景下 `Combatant` 默认敌方阵营、最大生命 100、非无敌、零血量行为为死亡；`DamageReceiver` 是 28 × 60 px 的公共受击区；`HealthBar` 读取同一生命组件。角色没有实体碰撞，不阻挡主角或改变现有地形测试。红色像素角色通过 `_draw()` 绘制占位外观，受伤短暂闪色；击倒显示黄色倒地姿态，死亡显示暗色尸体，空血条和状态仍可见。

敌人受到正数伤害时调用动作控制器的 `cancel("hit")`，由当前阶段的 `can_interrupt_hit` 决定是否中断；成功中断同时撤销本人近战窗口，保留技能冷却和攻击周期。击倒或死亡立即取消动作与本人已生成的近战窗口；已发射的独立投射物不由该逻辑撤销。恢复至正常状态后重新等待完整攻击间隔。`reset_state(spawn_position)` 恢复位置、配置的初始朝向、生命、动作和攻击时钟，保留 `attack_enabled`。公开 `get_combatant()`、`get_receiver()`、`get_action_controller()` 和 `get_attack_origin()`，供技能与自动验收使用。

## 扩展与验证

替换地图时复用 Player 场景与 DamageReceiver，不改变公共技能控制器。普通有生命单位复用 Combatant 的生命/阵营/受击结算，敌人模块只负责出招时机和动作表现；稻草人继续收集既定伤害，不按普通敌人死亡。后续 AI 只改变攻击请求与移动决策，继续使用公共技能、受击和血条组件。

游戏统一检测真实启动、地形/主角物理、目标受击、火球、敌人攻击/死亡与重置，详见 tests/README.md；执行结果以最新实际报告为准，文档中的行为约定不等于测试已通过。手感、平台难度与视觉验收由用户反馈。
