# ERR-20261001-LOCALIZATION-HUD-OVERFLOW：英语切换后 HUD 容器高度溢出

- status: resolved
- channel: automated_test
- category: code/layout
- first_seen: 2026-10-01
- related_run_ids: `20261001T101330588Z-6bf62a17`、`20261001T102843808Z-5964f6ad`、`20261001T103447218Z-fb5fe550`
- related_error_ids: `ERR-GAME-GUT`、`ERR-GAME-JUNIT`
- code_state: 多语言首轮未提交开发快照；源码 SHA-256 保存在本轮报告。

## 复现与原始证据

固定 Godot 4.7.2、GUT 9.7.1，在项目根目录执行 `node tools/check.mjs --scope game`。
报告：`artifacts/test-runs/20261001T101330588Z-6bf62a17/report.json`；原始 `game.xml` 与 `logs/gut.log` 保存在同目录。

`test_engine_measured_ui_bounds_and_text_fit_all_three_languages` 真实实例化场景，切换 en 后打开菜单，等待 5 个引擎帧测量：
`HudPanel.get_global_rect().end.y == 2648`，viewport 高度 540，要求不超出 `541`（1 像素测量容差）。
该用例 183 断言中这一项失败。完整执行 53 tests、544 assertions、1 failure、0 errors/skipped；14 项检查中 12 项通过。

## 判断与影响

依赖版本、静态检查、导入、实际场景启动及两个跨进程语言持久化检查通过；所有 34 个既有战斗测试通过。
因此不是缺字体、缺插件或测试未执行。自动测量发现语言切换与 Container 尺寸反馈存在真实布局问题：面板可能保留初始窄列产生的过大高度。具体根因仍由 UI owner 按控件布局证据确认。
不改变 viewport 边界断言，不增大允许溢出的标准，不以其它测试通过关闭本问题。

## 修复与验证

UI owner 负责容器布局修正；修复后立即复跑统一入口，保留原测量、三语字体检查、原 34 项回归和持久化检查。下一轮结果追加在此，未取得全部相关验证前保持 investigating。

## 修复验证

UI owner 先设置真实 HUD 宽度再填入文本，监听 minimum_size_changed 并延迟重新适配 HUD，允许实际最小尺寸正常约束，同时去除初始窄列留下的过大高度；没有裁剪内容或放宽测试条件。

最终 `node tools/check.mjs --scope game` 运行 `20261001T102843808Z-5964f6ad`：14/14 检查通过，53 tests、648 assertions、0 failures/errors/skipped；原 34 个战斗用例保留并通过。
报告、JUnit 和原始日志位于 `artifacts/test-runs/20261001T102843808Z-5964f6ad/`。
原失败用例 `test_engine_measured_ui_bounds_and_text_fit_all_three_languages` 的 183 个测量断言全部通过，三语 HUD、菜单、帮助的面板边界与文字尺寸均符合原 1 像素容差；原始 GUT/import/startup 日志无引擎错误或警告。
原始 GUT 记录三语 HUD 底边均为 161，菜单底边为 en/zh_CN 413、ja 425，帮助面板底边均为 495；均处于 540 高 viewport 内，原 en 底边 2648 不再复现。

同轮还验证全三语字符可由随附 FontFile 提供（禁止系统字体回退）、命名参数契约一致、坏配置操作后错误打印恢复原值，以及真实两个 Godot 进程读写相同设置文件后恢复 ja。
技术溢出问题按原断言关闭；主 agent 的实际截图视觉检查单独记录，不由此推定用户已接受界面风格或手感。

## 最后审查后的冻结回归

最后审查新增未知 key 含命名参数仍原样返回的断言，并使目录与 picker 允许自由增添语言（核心 en/ja/zh_CN、字体完整性和布局标准不变）。随后 `20261001T103447218Z-fb5fe550` 完成 14/14 检查，53 tests、649 assertions、0 failures/errors/skipped。
原 183 项布局测量全部通过，三语 HUD 底边仍为 161。原始 XML、GUT/import/startup 日志和 93 个源码文件哈希已读取核对，当前源码全部一致；两个真实进程保存/恢复 ja 通过。该轮成为最新冻结验收证据，前轮失败与修复报告继续保留。
