# ERR-20261001-I18N-GRAPHICS-PROBE — 独立图形探针提前引用 autoload

- 状态：resolved
- channel：automated_test
- 首次出现：2026-10-01，多语言首轮快照 `20261001T101330588Z-6bf62a17`；工作分支 feat/localization-v2 尚未提交。
- 原始证据：`artifacts/localization-visual/failed-6bf62a17/capture.log` 保留 argv、环境路径与 exit_code=1。
- 复现：Godot 4.7.2 以 `--script res://tests/probes/localization_visual.gd` 启动该快照，非 headless，输出目录独立，ASTRA_SETTINGS_PATH 亦独立。
- 原始错误：`Compile Error: Identifier not found: Localization`，位于探针第 23 行；图形设备正常初始化为 Apple M4 Pro / Compatibility，既有主场景与 GUT 导入运行不受此问题影响。
- 预期：独立探针读取真实 autoload，截图三语 UI；实际：探针在主循环初始化之前编译，直接全局标识引用无法解析，没有生成有效截图。
- 原因判断：代码/探针启动阶段问题；引擎/字体已在首轮导入通过，非依赖缺失或文件权限问题。
- 修复尝试：在延后执行的 `_run()` 中通过 root.get_node("Localization") 取得类型化服务，避免探针编译期间依赖 autoload 全局标识；不修改游戏业务或弱化验收。捕获报告额外标注 scope=viewport_capture、review_status=pending，截图保存成功不自动等同于人工图形审核通过。
- 当时结论：待修复后原图形命令复跑，保留原失败日志；最终验证见下文。

## 第二次复现与修正

`artifacts/localization-visual/20261001T102321649Z/capture.log`：改为延后取 autoload 节点后，探针仍用 TrainingArena/TrainingHUD 的静态类型，引擎在主循环脚本编译时提前解析这些类，再次出现依赖内 `Identifier not found: Localization`。空 scene 的后续调用使探针未自行退出，外层 45 秒超时终止，ETIMEDOUT/SIGTERM 原样保留；没有生成有效图片。

修正为仅用内置 Node/Control 类型，延后加载实际场景，移除探针对业务全局类的提前编译依赖；空 scene 显式失败退出。游戏业务的 autoload 访问及原验收标准保持一致。

## 修复验证

原图形启动方式在已导入的实际工程复跑，证据目录 `artifacts/localization-visual/20261001T102716473Z/`。capture.log 保留 argv、独立设置环境、实际 exit_code=0；无脚本/解析/引擎错误。report.json 与九张 1440×810 PNG 齐全，包含三语 HUD、菜单、帮助；source-hashes.json 对应当前代码。主 agent 已实际打开全部九图并在独立 review.json 记录视觉结论，原始 capture 报告不改写。

独立主循环探针的提前编译错误不再复现；两轮原失败/超时日志保留。本问题关闭，手感与正式译文润色仍属于用户反馈。
