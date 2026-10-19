# ERR-20261019-R4-VALIDATION-FIXTURES

- 状态：resolved
- channel：automated_test
- checkout：`/Users/hanguo/.codex/worktrees/aec1/Godot-project`，base `b71f2c179b676b1019408e55f12578f610b7b26e`，分支 `codex/r4-sprites-01a10533`。
- 原始 game 证据：`artifacts/test-runs/20261019T093101088Z-7fd3fede/report.json`、`logs/gut.engine.log`；183 tests / 3294 assertions，7 failed cases，原日志12条失败断言，零跳过。
- 原图形证据：`artifacts/r4-visual/capture.log` 与 `execution.json`；独立 probe 编译失败后45秒超时，未产生有效图片。

## 原因与修正

1. 旧零速度回归把 Visual 子节点强转为 Sprite2D，新实现使用 AnimatedSprite2D，转换得到 null。改用共同 Node2D 类型，完整保留零速度、transform 有限和 reset 断言。
2. 新测试把 arena 挂在 ALWAYS 处理的测试节点下，却将其设为 current_scene，既违反场景父级要求又使暂停测试继续动画。复现 [旧场景父级错误](ERR-20261001-TEST-SCENE-PARENT.md)；改为 root.add_child + autofree，保持实际场景继承正常暂停行为。
3. 保存测试使用 x=220，位于真实训练场左界224之外。改到明确空地 x=300，并先断言真实落地，再验证零延迟待机和零阈值跑步。
4. 新独立图形 probe 的 TrainingArena 静态类型在主循环初始化前触发 Localization 依赖编译。复现 [旧图形探针错误](ERR-20261001-I18N-GRAPHICS-PROBE.md)；改用内置 Node，运行后再加载实际场景，并对空场景显式退出。

不修改游戏运动、伤害或原设计基线。修正后由独立测试 agent 复跑同一完整 game 入口，图形入口另复跑并查看实际 PNG；成功证据补充后关闭。

## 碰墙实际速度修复与最终验证

第二轮 `20261019T093444186Z-6d375316` 已消除前述夹具问题，但仍有1个case/2条断言失败。逐帧实际位置约711.94–711.99，顶墙时请求 velocity.x 仍为3.2/6.4，导致 run/stand 交替；单帧 is_on_wall 也可交替。因此视觉改用 get_real_velocity 与 get_position_delta，过滤不超过 safe_margin 的水平恢复位移，未改变角色物理。测试连续观察40帧阻挡、动画稳定与最终idle。低速过滤限制已写入 player 模块。

最终独立 game `20261019T093828824Z-3e5b519f`：14/14 checks、183 tests /3371 assertions，零失败/错误/跳过；主 agent 复读原始报告、XML、21份日志与195项源码哈希一致。图形 `artifacts/r4-visual/final/` exit0，6张PNG实际查看，角色尺度、脚底和左右朝向符合本轮范围。生成素材帧间形变与用户手感仍待用户审核。

前两轮完整失败报告、快照和 wall-diagnostic.log 保留在本任务 artifacts；本问题是本轮新增动画的局部缺陷，未更改公共测试检测机制。
