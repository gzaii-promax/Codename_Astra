# ERR-20261002-MAP-VALIDATION：地图首版完整验收超时与 HUD 切换错误

- status: resolved
- channel: automated_test / static_api_review
- category: code / test execution budget
- first_seen: 2026-10-02
- related_run_ids: `20261002T064111312Z-56769cbb`、`20261002T064503253Z-7726e5b4`、`20261002T064953082Z-d5624293`
- related_error_ids: `ERR-GAME-GUT`、`ERR-GAME-JUNIT`
- code_state: 本轮地图开发工作区，精确 commit 与源码 SHA-256 见报告 `code_state`

## 复现与原始证据

- cwd: `/Users/hanguo/Documents/ChatGPT/Godot-project`
- command: `node tools/check.mjs --scope game`，按 `ENV-0004` 在获准沙箱外环境执行。
- versions: Godot `4.7.2.stable.official.ed1daf0bf`、GUT `9.7.1`、gdtoolkit `4.5.0`；报告确认引擎、Python、lint、format 版本。
- report: `artifacts/test-runs/20261002T064111312Z-56769cbb/report.json`
- raw log: `artifacts/test-runs/20261002T064111312Z-56769cbb/logs/gut.engine.log`、`logs/gut.log`、`logs/junit.log`
- source snapshot: 同轮 `game-project/`；不要用后来修改过的工作区解释为同一源码版本。

## 预期与实际

- 预期：133 个契约 case 全部有实际断言，JUnit failures/errors/skipped 均为 0；14 项固定检查完成。
- 实际：14 项检查执行，12 项通过；GUT 进程真实运行 90,019 ms 后按原 90 秒时限被 SIGTERM，`exit_code=null`、`timed_out=true`。运行进行到 `test_unit_scale.gd` 的死亡/恢复回归，未生成 `game.xml`，随后独立 JUnit 读取按缺文件判 fail。不能报告全套通过。
- 地图 21 case 的原始引擎日志显示 20 个通过，模式切换 case 捕获一个真实错误：
  `SCRIPT ERROR: Cannot call method 'get_visible_rect' on a null value.`
  `at: TrainingHUD._fit_hud (res://ui/training_hud.gd:361)`。
  当菜单从地图切到训练场时，旧 HUD 离树后排队的布局调用仍执行，`get_viewport()` 为 null。其余具体模式切换断言通过不能抵消这个引擎错误。
- 三语地图 HUD 的实际 bottom 为 161 px；相机给 HUD 预留的范围为 160 px。原 viewport 布局断言只检查画面范围，所以未拒绝这 1 px 遮挡；随后补充直接 `bottom <= 160` 独立断言。
- 原始日志还报告部分即时房间替换 case 的待释放孤儿节点。是否属于 `queue_free` 尚未过一帧的暂态或真实泄漏，需要进一步检查；暂不确认业务泄漏。

## 原因判断与修复交接

- 依赖版本、lint、format、import、主场景 startup 及跨进程语言恢复均通过，没有复现 `ENV-0004` 权限问题。
- HUD 错误定位到旧实例离树后 deferred 布局调用；业务修复应检查实例仍在树内以及 Viewport 可用，不应吞掉引擎日志或降低错误判定。
- 完整套件时限不足是执行证据：旧 112 项报告总耗时约 88.8 秒，新增加 21 个真实物理/输入 case 后在末尾遭到 90 秒 GUT 截断。完整验收仍须有限时限；若调整预算或分组，须明确记录，不能将原超时改称通过。
- 测试 agent 未自行放宽原时限或减少预期 case。主 agent 负责业务修复及预算决定；修复后须复跑模式切换、布局与本轮全量检查。

## 当前结论

原失败与超时证据保留。主 agent 明确将 GUT 有限预算设为 150,000 ms，其他进程与全部 133 case/断言保持；HUD 延迟布局增加离树/Viewport guard，并将地图 HUD 顶边调整为 10 px。测试清理等待 2 个真实物理帧观察 queue_free，避免将待处理删除误记为孤儿。

同入口复跑 `20261002T064503253Z-7726e5b4` 通过 14/14 检查；GUT 实际 99,411 ms，全轮 104,326 ms。原始 `game.xml` 为 133 个唯一 case、2724 assertions，failures/errors/skipped 均为 0，实际 case 与契约完全匹配。地图三语九次 HUD 底边测量均为 159 px，模式往返无离树错误。全部原始引擎日志不含脚本/运行错误、WARNING、孤儿、ObjectDB 或未释放对象警告；154 个已记录源码哈希与冻结快照一致。

关闭依据：原 HUD 错误、布局差异及套件截断均不再复现，完整 JUnit 可读且没有漏跑。此结论对应该冻结快照；随后新增或修改功能需另行验收。用户手感仍独立待验收。

## 追加：运行时 F6 碰撞显示 API 核查

- 来源：主 agent 静态 API 核查，测试 agent 已独立打开 [Godot 4.7 SceneTree 文档](https://docs.godotengine.org/en/4.7/classes/class_scenetree.html#class-scenetree-property-debug-collisions-hint)。该属性仅用于编辑器调试启动，官方说明运行期间改变值不支持预期效果。没有捕获旧实现 F6 画面，不把此问题记作图形观察。
- 源码证据：第二轮冻结快照 `artifacts/test-runs/20261002T064503253Z-7726e5b4/game-project/world/map_world.gd:52` 原先只翻转 `SceneTree.debug_collisions_hint`。
- 修复：最新实现使用 `MapCollisionOverlay` 读取当前实际 TileData 与 CollisionShape2D，`MapWorld.set_collision_debug` 控制显示；F6 触发该方法。
- 新增独立验收：134 个契约 case 中 F6 case 通过真实物理键输入，检查实际地板、玩家 body 与移动后的几何、A 的无路由出口隐藏，以及切换 B 后替换地形/出口和关闭。图形 probe 另捕获第 11 张中文 A 的真实 F6 画面并记录碰撞 polygon 数。
- 最终复跑：`artifacts/test-runs/20261002T064953082Z-d5624293/report.json` 通过 14/14 检查，原始 `game.xml` 134 个唯一 case、每项有断言，合计 2742 assertions，failures/errors/skipped 均为 0。F6 独立 case 通过；GUT 耗时 99,951 ms，全轮 105,162 ms。156 个源码 SHA-256 与冻结快照及当前已记录源码逐一匹配，包含新覆盖层。全部原始日志无脚本/运行错误、WARNING、孤儿或未释放对象警告。
- 图形关闭依据：`artifacts/map-visual/20261002T064953082Z-d5624293/primary-review.json` 记录主 agent 逐张查看全部 13 图（11 标准视角、2 端点视角），status=pass、material_defects为空。测试 agent 另外亲自打开中文 A F6 图，确认地板/墙体/台阶轮廓及玩家框可见；该图实际 `collision_debug_visible=true`、`collision_polygon_count=96`。标准与端点 `capture.log` 的 stderr 均为空，未发现引擎错误记录。图形捕获来自最终同源冻结快照，不与旧 F6 实现混用。
- 当前结论：原 HUD、布局、完整套件截断及运行时 F6 实现问题均有修复与复跑关闭证据；原失败/超时和 API 核查证据保留。没有宣称用户手感验收或正式美术完成。
