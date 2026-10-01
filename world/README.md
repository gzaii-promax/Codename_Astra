# 训练场模块

## 职责

`training_arena.tscn` 是主场景，包含 Player、TrainingDummy、HUD。`training_arena.gd` 创建 gray box 几何、输入配置、R 重置与 F2 等级调试；`training_dummy.gd/.tscn` 提供无限生命受击目标。公共矩形地形创建在 shared/graybox_solid.gd。

逻辑画布 960 × 540，地板上沿 y=430，主角脚底初始 (150,430)，目标脚底 (645,430)。两个平台分别是 Rect2(275,366,145,18)、Rect2(760,350,120,18)，左右墙宽 20 px。平台当前是普通实心碰撞，没有单向平台或下落穿透机制。灰色几何与网格用于测试，尚无正式地图美术。

## 稻草人与接口

稻草人受击区 28 × 60 px，中心在脚底上 32 px；没有实体阻挡玩家，无 AI、生命条或死亡。DamageReceiver 只接受有效且非自身来源的 HitData；accepted signal 由稻草人统计。`total_damage`、`hit_count`、`last_hit` 可读取，`get_receiver()` 给测试使用，`reset_stats()` 清零并发 `stats_changed`。屏幕提供短暂闪色与浮动伤害数字。

当前累计伤害不是 DPS：统计时间窗、有效战斗时长、多目标与分技能统计需在后续定义，不能用首版显示值当作每秒伤害。

`reset_training()` 无条件重置主角位置/动作/冷却，删除已发布火球和攻击效果，清空稻草人统计。F2 在 1/2 级火球间切换，不重置正在施放的动作。

## 扩展与验证

替换地图时复用 Player 场景与 DamageReceiver，不改变公共技能控制器。未来真实敌人自己处理 accepted hit 的生命/抗性/硬直规则。目标目前只接收既定伤害。

游戏统一检测真实启动、地形/主角物理、目标受击、火球和重置，详见 tests/README.md。手感、平台难度与视觉验收由用户反馈。
