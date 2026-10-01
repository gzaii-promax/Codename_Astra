# ERR-20261002-SCALE-TEST-SAMPLING：尺度测试的物理帧采样与等待条件

- status: resolved
- channel: automated_test
- category: test
- first_seen: 2026-10-02
- related_run_ids: `20261001T170614834Z-918347de`、`20261001T171024428Z-05e42084`
- code_state: `codex/scale-movement-v4`，基于 `a9d295e41344de7836ede06db7bdc9d5c3458d72` 的未提交改动；精确源码见报告快照与哈希。

## 复现与原始证据

在 `/Users/hanguo/Documents/ChatGPT/Godot-project` 按 ENV-0004 使用授权环境运行 `node tools/check.mjs --scope game`，固定 Godot 4.7.2、GUT 9.7.1。

报告 `artifacts/test-runs/20261001T170614834Z-918347de/report.json` 为 fail：14 项检查执行齐全，12 项通过；GUT exit1、93 tests 中 4 项失败，1221 assertions、0 errors/skipped，未超时。原始 XML 与 `logs/gut.log` 保留。失败用例为地图左墙、恒速/反向速度、真实 Space 按松、撞顶；其他既有 79 项回归通过。

- 初次恒速读取为 `22.4000015`，预期 `24.0`；反向等待后的读取为 `1.5999992`，预期 `-24.0`。
- 真实键事件刚提交即检查状态，出现 `Physical Space maps to jump action` 失败；同用例实际跳高已经符合短/长跳要求。
- 墙与顶检查在等待返回时没有观察到接触标志；撞顶最高上升 `7.8139343 px`，未穿过仅留 8 px 的实际碰撞面。

## 原因判断与修复尝试

独立测试 agent 读取固定 GUT 的等待实现，确认 `wait_physics_frames(x)` 的内部条件为 `_elapsed_frames > x`，不能把每次 `wait_physics_frames(1)` 声称为逐个物理帧采样；它可能漏掉短暂接触标志。新增采样改用 SceneTree 的 `physics_frame`，并核对 Engine 物理帧计数。旧报告保留为采样修正前证据。

反向从 +24 到 -24 px/s 在已配置 192 px/s² 下至少需要 0.25 秒，原测试只等待约 0.1 秒，等待条件与物理要求不一致。修复给足加速时间，仍要求稳定速度为 ±24 px/s。真实输入事件在引擎处理后检查，不把事件刚入队的瞬间当成处理完成。墙/顶逐帧记录接触与实际位置，仍要求发生碰撞、不能穿透。

这些是测试设施问题的有证据判断；最终关闭须同入口复跑原失败项、全部必要回归，并由主 agent 读取原始报告确认。短/长跳容差及用户批准的尺寸、速度、高度不扩大。

## 当前结论

采样修正后同入口完整复跑 `20261001T171024428Z-05e42084`：14/14 检查、93/93 tests、1222 assertions，0 failures/errors/skipped，GUT 54.275 秒，未超时。主 agent 独立读取原始 XML、日志及报告，114 项源码/协议哈希与当时工程一致。原四项失败全部通过，速度位移容差还从 0.5 px 收紧到 0.05 px，真实 Space 短按明确为 1 个 Engine 物理帧。业务预期没有放宽，技术测试问题关闭；用户手感判断仍待试玩。
