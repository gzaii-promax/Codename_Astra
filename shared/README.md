# 公共工具模块

## 公共战斗配置

`combat_config.gd` 提供无状态 `CombatConfig extends RefCounted`，受击保护时长以未暂停的游戏秒数计量：`PLAYER_HIT_PROTECTION_SECONDS=0.5` 记录主角默认基线，`DEFAULT_HIT_PROTECTION_SECONDS=0.0` 是通用生命组件声明初值。主角场景在 Combatant 子节点显式保存 0.5 秒；实际配置来自该实例的 `hit_protection_seconds`，不在 `_ready()` 用常量覆盖 Inspector / 场景值。修改单个角色直接保存场景属性，零秒也是合法覆盖；改默认基线时同步常量、默认场景和已批准的基线验收。常量不根据阵营选择，主角改变阵营也不改变保护配置。

实际剩余时间属于各自 `Combatant`，不保存在公共配置中。零秒跳过保护判定、不启动保护计时；训练稻草人复用 `Combatant` 的 10 心与 `REFILL` 行为，默认零秒保护。新增角色可显式配置有限且非负的秒数。更改常数或保护规则时同步 combat/player 模块文档，并通过真实受击、暂停、重置与现有战斗回归验证。范围与行为约定见 ../docs/hit-protection.md。

## 公共长度单位

`game_units.gd` 提供无状态 `GameUnits extends RefCounted`，公共常数 `PIXELS_PER_UNIT=16.0` 表示 **1 U=16 个游戏逻辑像素**。长度用 U/px，速度用 U/s 或 px/s，加速度用 U/s² 或 px/s²，时间继续用秒。定义来自用户采纳的第一版尺度，完整基线见 ../docs/scale-movement-v4.md。

它不是 autoload，也不存储角色状态或地图布局。业务脚本可引用 `GameUnits.PIXELS_PER_UNIT` 进行换算；场景资源中的实际形状仍以 px 保存，并由集成测试独立核对用户要求的尺寸。窗口像素、镜头、素材尺寸和逻辑长度应区分；更换角色素材不能改变 U。

U 统一计量，不强制所有属性按 1 U 或 0.5 U 跳变。地图模块负责网格布局，角色模块负责移动/跳跃，技能模块分别维护攻击范围。改变公共常数是项目尺度变更，必须同步场景资源、模块文档并复验尺寸与玩法行为，不能只改一个常数宣称全部自动适配。

## 输入与地形辅助

默认物理键保存在 Project Settings → Input Map（project.godot 的 input 节）。`input_setup.gd` 提供幂等 `InputSetup.ensure_actions()`，只补完全缺失的 move_left/right、jump、basic_attack、fireball、reset_training、toggle_fireball_level action；已有绑定、deadzone 和有意清空的 events 保持不变。日常调试在编辑器修改并保存，不在启动时强制补回默认键。角色键盘路径与场景事件路径共享这些映射；不承担动作时序或伤害。

`graybox_solid.gd` 提供 `GrayboxSolid.create(Rect2,Color,name)`，返回世界层 1 的 StaticBody2D；CollisionShape2D 与 Polygon2D 使用同一个矩形尺寸，保证 gray box 可见表面与物理表面一致。业务场景决定如何布局，不在公共工具中硬编码地图。

正式训练场的地形已保存于 `world/training_arena.tscn`，在编辑器编辑 Geometry 与出生标记，启动不再调用此生成器；本辅助继续供独立物理 fixture 使用。场景的显式出生绑定和局部 DebugInput 属于 world 模块，见 [world/README.md](../world/README.md)。

新增公共工具应服务明确的共同需求并有单一职责；不把主角/技能/目标状态放进全局万能工具。输入与地形由实际主场景测试覆盖，统一入口 `node tools/check.mjs --scope game`。

## 攻击效果生命周期

`AttackEffectLifecycle extends RefCounted` 是无持久状态的公共辅助，不是 autoload。世界在 `_enter_tree()` 调用 `register_world(self)` 声明边界；执行器通过 `find_world(caster)` 找最近的已声明世界，避免多个世界同时入树时误把另一世界的 `current_scene` 当作归属。独立测试 rig 没有边界时，执行器保留 current_scene / parent 回退。

发布攻击前显式调用 `register(effect, world, source, cancel_with_source)`；归属可以在世界/来源入树前组装，清理也不要求它们已入树。所有同时入树的相关节点必须属于同一 SceneTree。每个效果节点保存所属世界与来源的弱引用，世界与来源节点各自保存弱效果登记表；不存在全局效果数组，也不使用节点名、路径或具体攻击类判断。登记表在生成和清理时移除已释放的弱项，重复登记同一效果不会增加重复项。近战窗口声明 `cancel_with_source=true`，已发射的独立火球声明 `false`。手动构造效果的测试或新执行器也须显式注册，不通过扫描具体类型兜底。

`clear_world(world)` 清理该世界的全部已注册效果；`cancel_source(source)` 仅撤销该来源且跟随来源中断的效果。清理当帧先禁用处理与物理处理，再 `queue_free()`，避免删除队列尚未释放时继续命中。移动效果到 `Effects` 容器或 reparent 不改变归属，效果暂时脱树期间同样可被清理，重新入树不会恢复已取消攻击；若有意转移生命周期责任，必须显式重新注册，不能从新父节点推断。来源释放后弱引用为空，不会误匹配其他角色；世界清理仍能回收独立效果。效果自身继续负责寿命、距离、碰撞后的正常删除。

新增攻击行为应先声明世界、来源和中断策略，无须在世界/角色补一条类型分支。`tests/game/test_effect_lifecycle.gd` 通过真实场景的嵌套效果、两世界隔离、通用效果、来源释放与当帧停用验证此契约。

禁用未来帧不会终止已经执行的同步函数。近战在每个接触前再次检查删除状态，命中回调若重置世界/撤销来源，不能继续用之前的物理查询结果伤害其他目标。新效果也须在可触发取消/重置的回调边界后核对生命周期。

配置默认、保存覆盖与运行状态归属遵循 [Inspector 配置契约](../docs/inspector-configuration.md)；设计数值调整与机制回归遵循 [设计基线流程](../docs/design-baselines.md)。
