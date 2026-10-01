# 训练界面与暂停菜单模块

## 职责与依赖

`training_hud.gd` 提供 `TrainingHUD extends CanvasLayer`。训练读数读取 Player 的有效火球定义、动作阶段、剩余冷却及 TrainingDummy 的累计伤害/命中次数；不修改技能数值。菜单负责暂停/恢复场景树、调用现有训练场重置接口，以及显示语言选择和帮助；不创建新场景、不保存成长。

依赖 autoload `Localization`、主角动作控制器、稻草人与训练场。文本全部通过 `Localization.text(key, args)`，字体通过 `Localization.get_font()` 写入共享 Theme；语言选项动态读取 `available_languages()` 的 locale/name，不在 UI 写死语言数量或 locale。收到 `language_changed` 后立即刷新 HUD、菜单、手册和字体。技能名称/描述取 `get_definition(action_id)` 返回的 `name_key/description_key`。

## 玩家操作

- 初始直接进入可玩训练场，菜单默认关闭。
- Esc（Godot 默认 `ui_cancel`）或顶部菜单按钮打开菜单；Esc、继续按钮关闭菜单。
- 菜单打开后 `SceneTree.paused = true`，角色/技能/训练场保持继承的暂停模式，不执行战斗或训练快捷键。HUD 使用 `PROCESS_MODE_ALWAYS`，菜单在暂停时仍接受鼠标、Tab/方向键/Enter 操作。
- 帮助按钮显示手册；关闭帮助按钮或 Esc 返回菜单，继续保持暂停。手册支持滚轮及聚焦后的键盘滚动。
- 重置按钮调用原有 `reset_training()`，随后关闭菜单并恢复游戏；不重新加载主场景。
- 菜单打开前若场景树已暂停，关闭时恢复原暂停状态；HUD 离树时同样恢复，避免遗留暂停。
- 语言选项调用 `set_language(locale)`，保存策略由 Localization 管理。失败时保留原语言，并显示本地化保存错误信息。

## 布局与文本

HUD 使用 PanelContainer、HBoxContainer、VBoxContainer 分配标题、操作说明、技能参数与目标统计；标签使用 `AUTOWRAP_WORD_SMART`。暂停遮罩填充视口，中心菜单按视口宽度限制；手册使用 ScrollContainer 且禁用水平滚动，在 960 × 540 下保留可见关闭按钮。不采用长文本固定坐标叠放。

HUD 在填入文本前设置视口宽度，并在 `minimum_size_changed` 后延迟重新适配高度。原因是首次自动换行可能在子 Container 分配宽度前按窄列计算过大的最小高度；宽度确定后最小高度会缩小，但顶层 PanelContainer 不会自行收缩。重新适配使用真实内容最小尺寸，保留自动换行和长文本，不裁切或放宽布局验收。

HUD 文本键：`app.title`、`hud.controls/debug_controls/skill_stats/target/phase`、`phase.idle/windup/active/recovery`。菜单键：`menu.open/title/resume/reset/help/close/language/hint/save_error`。手册键：`manual.title/movement/combat/training/languages` 加两种技能的名称与描述。

参数仍显示原实际数据：damage 为整数文本，windup/recovery/cooldown 保留两位小数，剩余 cooldown 一位小数；翻译仅改变标签，不更改战斗或等级值。HUD 读取绑定后的火球定义，因此 F2 切级显示下次施法属性，当前已开始动作仍使用其原定义。

## 稳定接口与节点

测试可从 TrainingArena 的 `HUD` 调用：

- `open_menu()` / `close_menu()` / `is_menu_open() -> bool`；
- `open_help()` / `close_help()` / `is_help_open() -> bool`；
- `get_ui_control(name: String) -> Control`：查找下列唯一节点，不要求依赖多层 Container 路径。

稳定控件名：

| 控件 | 类型与用途 |
| --- | --- |
| Interface / HudPanel | Control / PanelContainer，根与训练读数 |
| AppTitle / Controls / DebugControls / SkillStats / TargetStats / PhaseStats | Label，分别对应标题/按键/调试/技能参数/稻草人/阶段文本 |
| MenuButton | Button，打开菜单 |
| PauseOverlay / MenuPanel / HelpPanel | ColorRect / PanelContainer / PanelContainer |
| MenuTitle / LanguageLabel / MenuHint / SaveError | Label，菜单标题/语言/操作提示/保存错误 |
| ResumeButton / ResetButton / HelpButton | Button，继续/重置/手册 |
| LanguagePicker | OptionButton，item metadata 保存 locale；item_selected 连接真实切换流程 |
| HelpTitle / HelpText | Label；HelpText 按段落连接完整 manual 与技能名称/描述，自动换行 |
| HelpScroll / HelpCloseButton | ScrollContainer / Button，手册滚动与返回菜单 |

## 验证与限制

统一入口 `node tools/check.mjs --scope game` 验证正式场景的语言切换、菜单暂停/恢复、按钮重置、键对应关系及 960 × 540 布局。游戏 headless 不能证明字形实际可见；root 的图形查看和截图是独立证据。新增或改动验证流程后立即执行，结果以本轮报告为准。

界面仍为原型样式，未实现正式 HUD 美术、技能后台编辑或技能树。正式字体规格与用户手感反馈分别由其他模块/用户负责。
