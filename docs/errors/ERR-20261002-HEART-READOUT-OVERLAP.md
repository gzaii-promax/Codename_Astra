# ERR-20261002-HEART-READOUT-OVERLAP：击倒文本覆盖第三单位心容器

- status: resolved
- channel: automated_test
- category: UI layout
- first_seen: 2026-10-02（Asia/Shanghai）
- related_run_ids: `20261001T173738107Z-511a5081`, `20261001T174929088Z-c237683c`
- code_state: `32c3e3c` 加未提交心系统改造

## 复现与原始证据

固定 Godot 4.7.2 从本轮通过快照运行 `tests/probes/heart_health_visual.gd`，独立设置、45秒界限、exit0及原始stdout/stderr保存在 `artifacts/heart-visual/20261001T174201178Z/capture.log`；report.json、source-hashes.json和12张图齐全。截图保存成功仅是capture pass，独立review.json判定fail；主agent也实际打开全部12图确认问题。

英文、日文 `player_downed` 图中，主角击倒长文本覆盖稻草人第二行右侧心容器。主角与敌人水平相距50px、稻草人与主角相距62px；稻草人原读数在脚底上108px，第二行进入主角击倒文本绘制区域。英文两完整绘制矩形交集为32×13逻辑像素，日文27.5×13。中文短标签不覆盖，不能因此认定三语均通过。

图中0.5和9.5两条浮动伤害也互相叠字，虽然没有遮心数，仍降低读数可辨识性。原每条按不同年龄漂移并仅水平错开8px，不能保证两条字分离。

自动101项/1811断言、14检查虽通过且122源码hash吻合，旧布局断言只比较主角/敌人，缺少新增稻草人同屏的第三角色覆盖。本问题由实际图形和独立审查发现，未把自动通过当视觉通过。

## 修复与验收

- 稻草人读数改到脚底上50px；两行图形下边界为脚底上32px，与当前32px稻草人头部边界相接，不遮身体。文字位于主角读数下方，保留三个真实角色位置。
- 活跃浮字按24px竖直行距排列，共用最新命中的漂移时间，保留各次文本、淡出和全部统计。
- 三语健康布局回归加入稻草人/主角、稻草人/敌人完整绘制范围，分别覆盖受伤、死亡和击倒；原101用例契约不缩减。

完整同入口复验 `20261001T174929088Z-c237683c`：14/14 检查通过，101 tests、1996 assertions，0 failures/errors/skipped；新增三角色真实绘制范围断言均通过，122 项源码/协议哈希一致。主 agent 另读原始 XML 和21份日志，无引擎错误。

新真实图形证据 `artifacts/heart-visual/20261001T175314663Z/` 从上述通过快照捕获，exit0、stderr为空。主 agent 与独立审查 agent 均逐一打开三语受伤/稻草人回满/敌人死亡/主角击倒共12张1440×810原图；`primary-review.json` 和 `review.json` 均为pass。en/ja击倒长字不再覆盖两行稻草人心容器，0.5/9.5浮字分行可读。旧fail图片、review和报告保留。此结论限定于已捕获位置/状态，用户手感仍待试玩。
