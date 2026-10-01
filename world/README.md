# 训练场模块

## 职责

`training_arena.tscn` 是主场景，包含 Player、TrainingDummy、PeriodicEnemy、HUD。`training_arena.gd` 创建 gray box 几何、输入配置、R 重置与 F2 等级调试；`training_dummy.gd/.tscn` 提供无限生命受击目标；`periodic_enemy.gd/.tscn` 提供固定周期近战敌人。公共矩形地形创建在 shared/graybox_solid.gd。

当前采用 shared/GameUnits 的 1 U=16 px。gray box 世界外框 32 × 16 U（512 × 256 px），包含厚 1 U 的墙、顶和地板，位于 Rect2(224,200,512,256)。逻辑画布仍为 960 × 540，它与地图大小分别维护。地板上沿 y=440，主角/稻草人/敌人脚底初始分别为 (272,440)/(544,440)/(656,440)。`TrainingArena` 暴露 ARENA_ORIGIN、ARENA_WIDTH/HEIGHT、FLOOR_Y 与三个 SPAWN 常数，场景资源保存同样的初始位置，运行与重置复用这些位置。

低台阶 Rect2(352,424,64,8) 比地面高 1 U，高平台 Rect2(432,408,48,8) 高 2 U；都是普通实心碰撞，没有单向平台或下落穿透机制。网格间隔 1 U。公共地形几何与显示仍使用同一矩形，灰盒背景先于地形和角色绘制，确保墙/地板可见。灰色几何与网格用于测试，尚无正式地图美术。用户采纳的尺寸与边界见 ../docs/scale-movement-v4.md。

## 稻草人与接口

稻草人受击区宽 1 U、高 2 U（16 × 32 px），中心在脚底上 1 U（16 px）；占位外观高 32 px，横杆允许超出身体受击区。没有实体阻挡玩家，无 AI、生命条或死亡。无 Combatant 的 receiver 默认为中立，仍遵循攻击携带的四种目标规则。稻草人在 accepted signal 中使用 receiver.last_damage 累计最终伤害和显示浮动数字；last_hit.damage 保留攻击基数。`total_damage`、`hit_count`、`last_hit` 可读取，`get_receiver()` 给测试使用，`reset_stats()` 清零并发 `stats_changed`。屏幕提供短暂闪色。

当前累计伤害不是 DPS：统计时间窗、有效战斗时长、多目标与分技能统计需在后续定义，不能用首版显示值当作每秒伤害。

`reset_training()` 无条件恢复主角与敌人的生命/生命周期、位置/动作/冷却和敌人攻击时钟，删除已发布火球和攻击效果，清空稻草人统计。F2 在 1/2 级火球间切换，不重置正在施放的动作。

地图房间名和目标标签经 Localization.text() 读取 `arena.room`、`arena.target`、`arena.enemy`，使用随语言配置的字体，语言切换信号触发重绘。暂停菜单和语言设置归 ui/localization，世界模块不保存语言，也不定义译文。

## 固定周期敌人

`PeriodicEnemy extends Node2D` 固定在场景位置，默认面向左，每 1.5 秒尝试开始一次近战动作；第一次也等待完整间隔。攻击没有目标搜索、转向、追击、巡逻或寻路；只有处在面向一侧攻击范围内的受击区才会被实际命中。时间间隔从动作开始计算，动作未结束或技能冷却未完成时本次尝试失败，不累积排队攻击。菜单暂停会同时暂停时钟和动作。

敌人通过公共 `ActionController` 和 `SkillExecutors.melee` 执行 `skills/definitions/enemy_attack.tres`：伤害 10、前摇 0.30 秒、执行 0.12 秒、后摇 0.25 秒、冷却 0.67 秒、近战范围 72 × 48 px。伤害目标规则与来源由公共技能/战斗模块生成；敌人不另写一套扣血公式。`attack_interval`、`attack_enabled`、`facing_direction` 可在 Inspector 配置。关闭攻击立即取消当前动作及本人尚在执行的近战窗口，重新开启后等待完整间隔。

场景下 `Combatant` 默认敌方阵营、最大生命 100、非无敌、零血量行为为死亡；`DamageReceiver` 是 28 × 60 px 的公共受击区；`HealthBar` 读取同一生命组件。角色没有实体碰撞，不阻挡主角或改变现有地形测试。红色像素角色通过 `_draw()` 绘制占位外观，受伤短暂闪色；击倒显示黄色倒地姿态，死亡显示暗色尸体，空血条和状态仍可见。

敌人沿用公共 `CombatConfig.DEFAULT_HIT_PROTECTION_SECONDS=0`，不进行受击保护判定，可连续接受有效伤害；其他新角色默认同样为零。稻草人没有 `Combatant`，继续接受每个有效命中并统计，不增加保护计时。主角的 0.5 秒保护不改变敌人攻击周期或技能接触规则。

敌人受到正数伤害时调用动作控制器的 `cancel("hit")`，由当前阶段的 `can_interrupt_hit` 决定是否中断；成功中断同时撤销本人近战窗口，保留技能冷却和攻击周期。击倒或死亡立即取消动作与本人已生成的近战窗口；已发射的独立投射物不由该逻辑撤销。恢复至正常状态后重新等待完整攻击间隔。`reset_state(spawn_position)` 恢复位置、配置的初始朝向、生命、动作和攻击时钟，保留 `attack_enabled`。公开 `get_combatant()`、`get_receiver()`、`get_action_controller()` 和 `get_attack_origin()`，供技能与自动验收使用。

## 扩展与验证

替换地图时复用 Player 场景与 DamageReceiver，不改变公共技能控制器。普通有生命单位复用 Combatant 的生命/阵营/受击结算，敌人模块只负责出招时机和动作表现；稻草人继续收集既定伤害，不按普通敌人死亡。后续 AI 只改变攻击请求与移动决策，继续使用公共技能、受击和血条组件。

游戏统一检测真实启动、地形/主角物理、目标受击、火球、敌人攻击/死亡与重置，详见 tests/README.md；执行结果以最新实际报告为准，文档中的行为约定不等于测试已通过。手感、平台难度与视觉验收由用户反馈。
