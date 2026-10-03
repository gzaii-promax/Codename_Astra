# 公共工具模块

## 公共战斗配置

`combat_config.gd` 提供无状态 `CombatConfig extends RefCounted`，受击保护时长以未暂停的游戏秒数计量：`PLAYER_HIT_PROTECTION_SECONDS=0.5` 记录主角默认基线，`DEFAULT_HIT_PROTECTION_SECONDS=0.0` 是通用生命组件声明初值。主角场景在 Combatant 子节点显式保存 0.5 秒；实际配置来自该实例的 `hit_protection_seconds`，不在 `_ready()` 用常量覆盖 Inspector / 场景值。修改单个角色直接保存场景属性，零秒也是合法覆盖；改默认基线时同步常量、默认场景和已批准的基线验收。常量不根据阵营选择，主角改变阵营也不改变保护配置。

实际剩余时间属于各自 `Combatant`，不保存在公共配置中。零秒跳过保护判定、不启动保护计时；训练稻草人复用 `Combatant` 的 10 心与 `REFILL` 行为，默认零秒保护。新增角色可显式配置有限且非负的秒数。更改常数或保护规则时同步 combat/player 模块文档，并通过真实受击、暂停、重置与现有战斗回归验证。范围与行为约定见 ../docs/hit-protection.md。

## 公共长度单位

`game_units.gd` 提供无状态 `GameUnits extends RefCounted`，公共常数 `PIXELS_PER_UNIT=16.0` 表示 **1 U=16 个游戏逻辑像素**。长度用 U/px，速度用 U/s 或 px/s，加速度用 U/s² 或 px/s²，时间继续用秒。定义来自用户采纳的第一版尺度，完整基线见 ../docs/scale-movement-v4.md。

它不是 autoload，也不存储角色状态或地图布局。业务脚本可引用 `GameUnits.PIXELS_PER_UNIT` 进行换算；场景资源中的实际形状仍以 px 保存，并由集成测试独立核对用户要求的尺寸。窗口像素、镜头、素材尺寸和逻辑长度应区分；更换角色素材不能改变 U。

U 统一计量，不强制所有属性按 1 U 或 0.5 U 跳变。地图模块负责网格布局，角色模块负责移动/跳跃，技能模块分别维护攻击范围。改变公共常数是项目尺度变更，必须同步场景资源、模块文档并复验尺寸与玩法行为，不能只改一个常数宣称全部自动适配。

## 输入与地形辅助

`input_setup.gd` 提供幂等 `InputSetup.ensure_actions()`：按物理键注册 move_left/right、jump、basic_attack、fireball、reset_training、toggle_fireball_level，重复调用不添加重复事件。角色键盘路径与场景事件路径共享这些映射；不承担动作时序或伤害。

`graybox_solid.gd` 提供 `GrayboxSolid.create(Rect2,Color,name)`，返回世界层 1 的 StaticBody2D；CollisionShape2D 与 Polygon2D 使用同一个矩形尺寸，保证 gray box 可见表面与物理表面一致。业务场景决定如何布局，不在公共工具中硬编码地图。

新增公共工具应服务明确的共同需求并有单一职责；不把主角/技能/目标状态放进全局万能工具。输入与地形由实际主场景测试覆盖，统一入口 `node tools/check.mjs --scope game`。
