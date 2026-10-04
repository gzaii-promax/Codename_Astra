# 训练／地图界面与暂停菜单模块

## 职责与依赖

`TrainingHUD` 是临时测试 HUD。2026-10-05 用户确认当前版足够测试，后续完全重做；本轮保留实现，不改 UI 行为。运行时创建全部控件、父场景/Player 路径依赖、菜单与读数集中、逐帧刷新均作为工程债记录，不作为正式 HUD 或新模块的复用标准。正式重做时重新划分展示/菜单/数据接口，审查可编辑场景及 signal 数据绑定；本记录不是已完成重构或正式 UI 设计。流程入口见 [engineering-practices.md](../docs/engineering-practices.md)。

`training_hud.gd` 提供 `TrainingHUD extends CanvasLayer`。读数读取 Player 的有效火球定义、动作阶段和剩余冷却；训练模式另读取 TrainingDummy 的累计伤害/命中次数，地图模式显示当前房间与本次探索数量。菜单负责暂停/恢复、调用当前模式的重置接口、切换训练场／地图样例，以及显示语言选择和帮助；不修改技能数值、不保存成长。

依赖 autoload `Localization`、主角动作控制器以及当前场景的读数／重置接口。地图模式以父节点提供 `reset_world()` 判断；不强类型引用 MapWorld，避免与地图根场景产生加载循环。`TrainingDummy` 使用 `get_node_or_null()`，地图不依赖它；地图读数使用 `get_room_title()`、`get_visited_rooms()` 和 `registry.rooms.size()`，房间总数不写死。文本全部通过 `Localization.text(key, args)`，字体通过 `Localization.get_font()` 写入共享 Theme；语言选项动态读取 `available_languages()` 的 locale/name，不在 UI 写死语言数量或 locale。收到 `language_changed` 后立即刷新 HUD、菜单、手册和字体。技能名称/描述取 `get_definition(action_id)` 返回的 `name_key/description_key`。公共头顶心容器 `health_bar.gd` 另读取同角色的 Combatant，不依赖角色控制方式。

## 玩家操作

- 初始进入项目指定的可玩场景，地图／训练场菜单默认关闭。
- Esc（Godot 默认 `ui_cancel`）或顶部菜单按钮打开菜单；Esc、继续按钮关闭菜单。
- 菜单打开后 `SceneTree.paused = true`，角色/技能/训练场保持继承的暂停模式，不执行战斗或训练快捷键。HUD 使用 `PROCESS_MODE_ALWAYS`，菜单在暂停时仍接受鼠标、Tab/方向键/Enter 操作。
- 帮助按钮显示手册；关闭帮助按钮或 Esc 返回菜单，继续保持暂停。手册支持滚轮及聚焦后的键盘滚动。
- 训练重置按钮调用原有 `reset_training()`；地图重置按钮调用 `reset_world()`，随后关闭菜单并恢复游戏；重置不重新加载主场景。
- `WorldModeButton` 在地图模式显示“进入训练场”，训练模式显示“进入地图样例”。点击后关闭菜单、解除暂停，再延迟执行 `change_scene_to_file()`；目标分别为 `res://world/training_arena.tscn` 和 `res://world/map_world.tscn`。延迟切换避免在当前 UI 回调期间释放场景；两种模式的运行状态不跨场景保存。
- 地图快捷键 F3／F4／F5（跳转 A／B／C）、F6（碰撞显示）、F2（火球等级）、R（地图重置）由 MapWorld 处理；HUD 只提供说明，不重复响应。暂停时这些快捷键不改变地图。
- 菜单打开前若场景树已暂停，关闭时恢复原暂停状态；HUD 离树时同样恢复，避免遗留暂停。
- 语言选项调用 `set_language(locale)`，保存策略由 Localization 管理。失败时保留原语言，并显示本地化保存错误信息。

## 布局与文本

HUD 使用 PanelContainer、HBoxContainer、VBoxContainer 分配标题、操作说明、技能参数与目标统计；标签使用 `AUTOWRAP_WORD_SMART`。暂停遮罩填充视口，中心菜单按视口宽度限制；手册使用 ScrollContainer 且禁用水平滚动，在 960 × 540 下保留可见关闭按钮。不采用长文本固定坐标叠放。

HUD 在填入文本前设置视口宽度，并在 `minimum_size_changed` 后延迟重新适配高度。原因是首次自动换行可能在子 Container 分配宽度前按窄列计算过大的最小高度；宽度确定后最小高度会缩小，但顶层 PanelContainer 不会自行收缩。重新适配使用真实内容最小尺寸，保留自动换行和长文本，不裁切或放宽布局验收。

模式切换后旧 HUD 可能已离树但仍有延迟布局回调；`_fit_hud()` 与 `_resize_interface()` 先检查节点仍在树中、未排队删除及 viewport／控件有效性，离树回调直接返回。地图 HUD 顶部为 10 px，训练 HUD 保留 12 px；地图在 960 × 540 三语布局的底边必须不超过 160 px，为房间主体留出空间。

训练 HUD 文本键：`app.title`、`hud.controls/debug_controls/skill_stats/target/phase`、`phase.idle/windup/active/recovery`。公共菜单键：`menu.open/title/resume/reset/help/close/language/hint/save_error`，训练菜单增加 `menu.enter_map`。训练手册键：`manual.title/movement/combat/training/languages` 加两种技能的名称与描述。地图使用 `map.title/controls/debug_controls/target/reset/enter_training` 和 `map.manual.title/movement/combat/navigation/debug/languages`；技能参数和动作阶段仍显示同一主角的真实数据。

地图 TargetStats 用 `{room}`、`{visited}`、`{total}` 显示房间名称和探索数量。手册明确 A↔B↔C、C 中央黄色出口单向回 A，探索仅当前地图运行保存，R 重置返回 A，F3–F6 用于调试。HUD 高度仍以 145 px 为基准，长文本保留自动换行，不覆盖下方地图区域。

参数仍显示实际数据：damage 与累计伤害以心为单位，整数无小数、半心保留一位小数；windup/recovery/cooldown 保留两位小数，剩余 cooldown 一位小数；翻译仅改变标签，不更改战斗或等级值。HUD 读取绑定后的火球定义，因此 F2 切级显示下次施法属性，当前已开始动作仍使用其原定义。

## 通用头顶心容器

`HealthBar extends Node2D` 保留原类名和节点名以便现有角色复用，但现在绘制心容器。它默认从 `../Combatant` 读取当前/最大心数、生命周期和阵营，可通过 `combatant_path` 绑定其他节点。组件不扣血、不判断目标规则，也不根据空心推断死亡。当前主角 3 个容器、PeriodicEnemy 3 个容器、TrainingDummy 10 个容器；稻草人自动回满时立即显示满心。

心形由 10 × 8 的像素几何构成，不使用字体中的心字符或外部图片。每个容器填充值为 1、0.5 或 0，分别显示完整、左半填充和空心轮廓。默认像素边长 1 px、横向间隙 2 px、行间隙 2 px，每行最多 5 颗；10 心自动排成两行，每行居中。Inspector 可调整 `heart_pixel_size`、`containers_per_row`、`container_gap`、`row_gap`、`font_size`。为避免误配巨大上限导致绘制失控，当前最多枚举 100 个图形容器；数值文字仍显示真实上限，超过 100 个容器需要后续专用布局，不改变战斗的上限规则。

主角心容器位于脚底上 82 px，PeriodicEnemy 位于脚底上 114 px，保留 32 px 高度差，避免 50 px 近战距离下三语数值/状态与心图形重叠；稻草人心容器位于脚底上 50 px，两行图形止于脚底上 32 px，与稻草人头部相接；其数值文字位于主角心图形下方，避免近距主角击倒长文本覆盖第三个角色。浮动伤害从脚底上 142 px 起，旧标签在最新标签上方按 24 px 行距排列，整组使用最新标签的 elapsed 同步上移，各标签保留自己的淡出时间。其他角色通过节点位置调整。友方绿色、敌方红色、中立金色；击倒变黄色、死亡变灰色，空心与状态仍可见。读数使用 `health.values` 的 `{current}`/`{max}`，附带本地化心单位；状态来自 `health.downed`、`health.dead`。

受击保护期间拒绝攻击，不发新的生命事件，心容器保持首击后的真实状态；组件不维护独立保护计时。

组件订阅 `health_changed(current, max)`、`state_changed(state)`、`faction_changed(faction)` 和 `Localization.language_changed(locale)` 重绘。文字使用 `Localization.get_font()`，几何图形不依赖字体。未绑定或配置无效时停止绘制，返回空容器/文本及比例 0。

可供验收与其他界面读取：

- `get_container_fills() -> Array[float]`：按从左到右、从上到下顺序返回每个容器的 1/0.5/0 填充；例如 3 心受 0.5 心伤害后为 `[1.0, 1.0, 0.5]`。
- `get_container_rects() -> Array[Rect2]`：各心图形的局部坐标矩形，便于验证换行与间距。
- `get_presentation_rect() -> Rect2`：合并心图形、当前字体 ascent/height 和 3 px 文字描边后的真实局部绘制范围，便于验证近距三语布局。
- `get_fill_ratio() -> float` 和 `get_display_text() -> String`：保留整体血量比例及本地化心数/状态读数。

## 稳定接口与节点

测试可从 TrainingArena 的 `HUD` 调用：

- `open_menu()` / `close_menu()` / `is_menu_open() -> bool`；
- `open_help()` / `close_help()` / `is_help_open() -> bool`；
- `get_ui_control(name: String) -> Control`：查找下列唯一节点，不要求依赖多层 Container 路径。

稳定控件名：

| 控件 | 类型与用途 |
| --- | --- |
| Interface / HudPanel | Control / PanelContainer，根与训练读数 |
| AppTitle / Controls / DebugControls / SkillStats / TargetStats / PhaseStats | Label，分别对应标题/按键/调试/技能参数/稻草人或房间探索/阶段文本 |
| MenuButton | Button，打开菜单 |
| PauseOverlay / MenuPanel / HelpPanel | ColorRect / PanelContainer / PanelContainer |
| MenuTitle / LanguageLabel / MenuHint / SaveError | Label，菜单标题/语言/操作提示/保存错误 |
| ResumeButton / ResetButton / HelpButton | Button，继续/重置/手册 |
| WorldModeButton | Button，在地图样例与训练场之间切换 |
| LanguagePicker | OptionButton，item metadata 保存 locale；item_selected 连接真实切换流程 |
| HelpTitle / HelpText | Label；HelpText 按段落连接完整 manual 与技能名称/描述，自动换行 |
| HelpScroll / HelpCloseButton | ScrollContainer / Button，手册滚动与返回菜单 |

## 验证与限制

统一入口 `node tools/check.mjs --scope game` 验证正式场景的语言切换、菜单暂停/恢复、按钮重置、键对应关系及 960 × 540 布局。游戏 headless 不能证明字形和心图形实际可见；`tests/probes/heart_health_visual.gd` 通过真实 viewport 捕获三语受伤、稻草人回满、敌人死亡和主角击倒画面，截图人工查看是独立证据。新增或改动验证流程后立即执行，结果以本轮报告为准。

界面仍为原型样式，未实现正式 HUD 美术、技能后台编辑或技能树。正式字体规格与用户手感反馈分别由其他模块/用户负责。
