# 多语言模块

## 职责与文件

`localization_service.gd` 定义 `LocalizationService extends Node`，由项目注册为 autoload `Localization`。JSON 目录转换成 Godot 内置 `Translation` 资源并注册到 `TranslationServer`；UI、地图标记、技能说明以及后续故事统一调用显式 `Localization.text(key, args)`。

查找使用本实例拥有的 `Translation.get_message()`，再查询默认语言，避免其他测试实例或全局翻译资源改变本实例结果。切语言同步 `TranslationServer.set_locale()`；模块只注册和销毁自己创建的资源，从不 `TranslationServer.clear()`。未加入树的独立实例销毁时也解除自己的资源。

- `languages.json`：默认语言、语言顺序、名称、目录和字体。
- `catalogs/*.json`：扁平文本字典；三语各 30 个相同 key。
- `localization_service.gd`：目录载入、查找与回退、语言切换、字体缓存、设置恢复。
- `settings_store.gd`：ConfigFile 原生解析及损坏用户数据的诊断。

默认语言为简体中文 `zh_CN`，同时提供 English `en`、日本語 `ja`。本模块没有新插件或故事内容，不改变战斗规则。

## 公开接口

| 接口 | 行为 |
| --- | --- |
| `initialize(settings_path_override = "", manifest_path_override = "") -> bool` | 载入并恢复语言；支持独立临时路径 |
| `available_languages() -> Array[Dictionary]` | 按 manifest 顺序返回新条目；字段 `locale`、`name`、`font` |
| `set_language(locale, persist = true) -> bool` | 先验证并成功保存（如果要求保存），再切换语言 |
| `text(key, args = {}) -> String` | 查找文本与命名参数替换 |
| `get_font() -> Font` | 当前语言字体缓存；未配置或缺失时 `null` |
| `get_settings_path() -> String` | 实际设置路径，供工具/测试诊断 |
| `current_language` / `last_error` | 当前语言与错误/降级诊断，调用者视为只读 |
| `language_changed(locale: String)` | 初始化完成或成功切到另一语言时发出；相同语言不重复发出 |

`_ready()` 首次自动初始化。测试应在 `new()` 后先 `initialize(temp_settings, temp_manifest)` 再加入树。同路径重复初始化幂等、不重复注册；已经初始化后改用不同路径返回 `false` 并诊断。初始化失败可以修正路径后再试；失败时不注册部分资源。

## Manifest 与新增语言

```json
{
  "schema_version": 1,
  "default_language": "zh_CN",
  "languages": [
    {
      "locale": "zh_CN",
      "name": "简体中文",
      "catalog": "res://localization/catalogs/zh_CN.json",
      "font": "res://assets/fonts/NotoSansCJKsc-Regular.otf"
    }
  ]
}
```

语言的四个字段都为字符串，`locale`、`name`、`catalog` 非空，`font` 可以为空。locale 唯一，默认语言必须在非空列表中；使用 Godot 支持的 locale 标识。`res://`、`user://` 和绝对路径直接使用，相对 catalog/font 路径相对 manifest 父目录解析。

新增语言只需增加文本目录与 manifest 条目，提供合适字体和许可记录；菜单从 `available_languages()` 生成，不改 UI 或战斗业务代码。修改对应 JSON 即可调整译文，下次启动载入；当前没有运行时热重载编辑器。

## 文本与参数

```json
{
  "skill.fireball.name": "火球术",
  "hud.target": "稻草人 · 累计伤害 {damage} · 命中 {hits} 次"
}
```

| 键族 | 用途 / 参数 |
| --- | --- |
| `app.title` | 训练场标题 |
| `menu.open/title/resume/reset/help/close/language/hint/save_error` | 菜单、语言选项和帮助；`save_error` 用 `{error}` |
| `hud.controls/debug_controls` | 实际控制及调试按键 |
| `hud.skill_stats` | `{skill}`、`{level}`、`{damage}`、`{windup}`、`{recovery}`、`{cooldown}` |
| `hud.target` | `{damage}`、`{hits}` |
| `hud.phase` | `{phase}`、`{cooldown}` |
| `phase.idle/windup/active/recovery` | 动作阶段 |
| `arena.room/target` | 地图与目标标记 |
| `skill.basic_attack.name/description`、`skill.fireball.name/description` | 技能名称与行为说明；技能资源保存对应 key |
| `manual.title/movement/combat/training/languages` | 帮助标题与四段操作说明，无剧情 |

`String.format(args)` 替换 `{name}` 命名参数。缺参保留占位符便于诊断，多余参数不影响文本。UI 负责数字精度，译文负责语序。未知 key 原样返回，不对 key 做参数替换。后续剧情使用稳定的 `story.*` 等 key，走同一 API。

说明对应 A/D 或左右方向键、空格/W/上方向键、J、K、F2、R、Esc。F2 是训练等级切换；一级/二级前摇说明来自首版规则。后续玩法变化应同步说明译文与相关验收预期。

## 降级与设置

- 缺失、空字符串或纯空白译文回退默认语言；默认语言也缺失时原样返回 key。
- 非字符串值跳过并诊断。非默认 catalog 缺失/损坏时仍保留语言选项，缺失文本回退默认语言，`last_error` 保留原因。默认 catalog 缺失/损坏或 manifest 无效则初始化失败。
- ConfigFile 默认 `user://settings.cfg`；仅修改 `[localization]` 的 `language`，保留其他 section/值。Variant 语法由 ConfigFile 原生支持，不重建白名单。
- 缺文件时直接使用默认语言，不自动写入。坏配置、目录路径或不支持的已保存语言使启动回退默认语言并提供诊断，不删除原文件。
- 默认 `set_language()` 要求保存。保存或现有文件解析失败时返回 `false`、原语言不变，不发成功事件；损坏配置不被覆盖。`persist = false` 仅当前运行切换。
- 损坏用户数据可能让原生解析打印 ERROR。仅在一个无 `await` 的同步 `ConfigFile.parse()` 调用内暂时关闭 `Engine.print_error_messages`，调用结束立即恢复原值，并把 Error 编号、路径、说明交给 `last_error`。初始化、保存、业务代码和整个测试的错误输出均不关闭；解析失败仍通过返回值和断言可见。

工具/测试使用环境变量 `ASTRA_SETTINGS_PATH` 指向每轮独立文件，只有 `_ready()` 首次初始化读取。正常游戏默认路径不变；已显式 `initialize(temp...)` 的实例不被覆盖。此入口隔离真实菜单保存，避免修改用户偏好，不重新指定 `HOME`。

## 字体与验证

中文、英文使用随附 `NotoSansCJKsc-Regular.otf`，日文用 `NotoSansCJKjp-Regular.otf`，来源与许可见 `../assets/fonts/README.md`。返回的 `FontFile` 设置 `allow_system_fallback = false`，不借系统字体掩盖缺字。空/缺失字体返回 `null`，UI 可以用自己的默认字体，但这不能作为随附字体字形验证通过的证据。

固定入口 `node tools/check.mjs --scope game`；报告与原始日志按 `../docs/testing.md` 读取。覆盖三语切换、配置恢复和其他 section、坏配置和保存失败、目录回退、命名参数、第四语言、资源所有权和初始化幂等、真实字符与随附字体、菜单/帮助/暂停行为。结果以本轮报告为准；落盘和静态检查不替代真实执行。三语画面需要实际图形运行检查，手感由用户独立反馈。

内置 API 依据：[Translation](https://docs.godotengine.org/en/stable/classes/class_translation.html)、[TranslationServer](https://docs.godotengine.org/en/stable/classes/class_translationserver.html)、[ConfigFile](https://docs.godotengine.org/en/stable/classes/class_configfile.html)、[FontFile](https://docs.godotengine.org/en/stable/classes/class_fontfile.html)、[Engine 错误打印控制](https://docs.godotengine.org/en/stable/classes/class_engine.html#class-engine-property-print-error-messages)。
