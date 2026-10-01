# 公共工具模块

`input_setup.gd` 提供幂等 `InputSetup.ensure_actions()`：按物理键注册 move_left/right、jump、basic_attack、fireball、reset_training、toggle_fireball_level，重复调用不添加重复事件。角色键盘路径与场景事件路径共享这些映射；不承担动作时序或伤害。

`graybox_solid.gd` 提供 `GrayboxSolid.create(Rect2,Color,name)`，返回世界层 1 的 StaticBody2D；CollisionShape2D 与 Polygon2D 使用同一个矩形尺寸，保证 gray box 可见表面与物理表面一致。业务场景决定如何布局，不在公共工具中硬编码地图。

新增公共工具应服务明确的共同需求并有单一职责；不把主角/技能/目标状态放进全局万能工具。输入与地形由实际主场景测试覆盖，统一入口 `node tools/check.mjs --scope game`。
