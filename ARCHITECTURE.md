# 工程架构导航

本文描述当前源码中的职责与运行关系，不新增架构决定。初次接手可按“启动 → 状态归属 → 要改什么”阅读；参数和接口细节保留在各模块 README，当前交付与历史证据分别见 [状态](docs/status.md) 和 [文档索引](docs/index.md)。

## 启动与场景组合

[project.godot](project.godot) 的 `run/main_scene` 指向 [world/map_world.tscn](world/map_world.tscn)，唯一 autoload 是 `Localization`。语言服务加载清单、译文和语言偏好；主场景组合世界注册资源、Player、Camera、CollisionDebug 和 HUD。

```text
project.godot
├─ Localization → languages.json / catalogs / ConfigFile
└─ MapWorld → sample_world.tres
   ├─ Player → Actions / Visual / Combatant / DamageReceiver / HealthBar
   ├─ 动态 MapRoom → Terrain / Entrances / Exits
   ├─ Camera / CollisionDebug
   └─ HUD → 暂停菜单 / 帮助 / 语言选择 / 场景切换
```

菜单模式按钮通过 `change_scene_to_file()` 往返地图与 [training_arena.tscn](world/training_arena.tscn)。训练场组合 Player、TrainingDummy、PeriodicEnemy、HUD，并由脚本生成矩形灰盒地形。两个场景重新创建自己的运行状态；正常地图切房则保留同一个 Player。

## 模块与状态归属

| 模块 | 职责与拥有的状态 | 详细入口 |
| --- | --- | --- |
| player | 移动、跳跃、输入意图、朝向、火球等级与可替换视觉；调用动作控制器，响应受伤/生命周期 | [player/README.md](player/README.md) |
| skills | Resource 定义、等级覆盖、阶段策略；ActionController 拥有动作阶段、剩余时长和冷却，执行器生成具体攻击 | [skills/README.md](skills/README.md) |
| combat | HitData 保存当前伤害归属/许可；DamageReceiver 负责接收；Combatant 拥有心生命、阵营、生命周期及恢复/保护计时 | [combat/README.md](combat/README.md) |
| world | MapWorld 拥有房间身份、实例、探索和房间代次；TrainingArena 负责训练重置，稻草人保存统计，敌人保存攻击周期 | [world/README.md](world/README.md) |
| ui | 读取角色、动作、生命和世界信息；显示心容器/HUD、管理菜单与暂停；不计算伤害 | [ui/README.md](ui/README.md) |
| localization | 语言清单、Translation、字体、回退与 ConfigFile 偏好；通过 language_changed 通知界面 | [localization/README.md](localization/README.md) |
| shared | 无状态单位/战斗常量、输入映射和矩形地形辅助；不保存角色或世界状态 | [shared/README.md](shared/README.md) |
| assets | 占位角色、灰盒素材和字体及来源/许可 | [assets/README.md](assets/README.md) |
| tests / tools | 测试契约、实际工程快照、原始报告、依赖准备、运行入口与集成锁 | [tests/README.md](tests/README.md)、[tools/README.md](tools/README.md) |

场景组合与逻辑依赖应分别理解：Player 场景包含 UI 的 HealthBar，HUD 又读取 Player 等角色信息；不能因此把目录关系描述成严格单向的依赖图。核心 combat 不依赖角色控制或 UI，ActionController 不按技能名或语言分支。公共配置没有 autoload，个人状态留在各自实例。

## 四条运行链

### 输入、动作与技能

输入映射由 [InputSetup](shared/input_setup.gd) 幂等注册。Player 将输入交给 `request_attack()` / `request_fireball()`，再由 [ActionController](skills/action_controller.gd) 检查绑定、当前动作和冷却。`bind_action()` 解析等级后的独立定义；角色每物理帧显式调用 `tick(delta)`，推进前摇、执行、后摇。

进入 ACTIVE 时只调用一次 [SkillExecutors](skills/skill_executors.gd)，生成 [MeleeStrike](skills/melee_strike.gd) 或 [Fireball](skills/fireball.gd)。角色从阶段策略读取控制/惯性/跳跃/技能位移，执行器负责攻击行为。配置、运行状态和技能树分工独立；当前没有完整技能树。

### 碰撞、扣心与反馈

攻击携带 [HitData](combat/hit_data.gd)，真实物理查询调用 [DamageReceiver.receive_hit()](combat/damage_receiver.gd)。接收器与 [Combatant](combat/combatant.gd) 校验数据、当前归属/阵营许可、生命状态、无敌与保护，再结算心伤害并发送事件。角色响应受伤进行允许的动作中断；HealthBar 读取生命重绘；稻草人根据成功命中记录完整伤害与次数。

生命内部用整数半心保存，对外接口和统计用心。稻草人与主角/敌人复用 Combatant；稻草人采用 REFILL，主角/敌人默认死亡。具体容器、保护和零伤害语义见 [心规则](docs/heart-health-v5.md) 与 [受击保护](docs/hit-protection.md)，不沿用旧百分比减伤。

### 出口、房间与探索

[sample_world.tres](world/maps/sample_world.tres) 保存 room_id、房间模板与有向连接；[房间场景](world/rooms/README.md) 保存可编辑地形、入口和出口。模板文件名不等于世界身份：A/C 可共享模板，同时保持独立连接与探索记录。

MapExit 发出出口 ID；MapWorld 延迟处理并核对来源房间及代次，查询连接，脱树准备并校验目标房间/入口，之后替换房间、安置玩家、更新探索和相机。未通过校验时保留原房间；旧房间的延迟出口事件不能再触发旅行。

正常切房保留 Player 的生命、技能等级、冷却与保护，清除当前动作、运动和旧攻击。地图 R 重置另恢复角色状态并清空探索。`prepare_room()` 提供准备接口；提前预加载、转场和攀爬仍是 [地图契约](docs/map-system.md) 中的后续 TODO，接口存在不代表功能已实现。

### 译文、偏好与界面

[languages.json](localization/languages.json) 声明语言、catalog 和字体；Localization 将 catalog 转为 Translation，恢复语言偏好，通过 `text()` / `get_font()` 供 UI 与绘制使用。菜单选择语言时先验证并保存，再切换并发出 `language_changed`；缺失、空译文回退默认语言，未知键保留字面值。

只有语言偏好写入 ConfigFile。地图探索、训练统计、角色成长没有磁盘存档。工具/测试通过 ASTRA_SETTINGS_PATH 隔离设置，具体协议见 [testing.md](docs/testing.md) 与 [worktrees.md](docs/worktrees.md)。

## 要改什么，从哪里开始

| 改动目标 | 先读 / 编辑 |
| --- | --- |
| 启动、地图与训练场切换 | project.godot、world/README.md、ui/training_hud.gd |
| 移动/跳跃/身体尺寸 | player/README.md、docs/scale-movement-v4.md、player_character 场景与脚本 |
| 技能数值、等级或阶段 | skills/README.md、skills/definitions/*.tres；新增行为再查看执行器 |
| 心伤害、阵营、生命/保护 | combat/README.md、心规则/保护契约、shared/combat_config.gd |
| 房间地形/入口/出口 | [world/rooms/README.md](world/rooms/README.md)、对应 .tscn 的 Terrain/Entrances/Exits |
| 世界身份与路由 | [world/maps/README.md](world/maps/README.md)、sample_world.tres |
| 译文/语言/字体 | localization/README.md、languages.json、catalogs、assets/fonts/README.md |
| 界面、心容器与占位素材 | ui/README.md、assets/README.md、player/player_visual.gd |
| 测试、报告、CI、并行开发 | docs/testing.md、docs/ci.md、docs/worktrees.md、tools/README.md |

修改实现时同步所属模块文档；改变已采纳规则时保留原因和验收变化。测试源码、运行报告与用户试玩各自证明不同范围，导航文档不能代替它们。
