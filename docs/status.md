# 当前工程状态

## Inspector 与设计基线修复（2026-10-03）

本轮以远端 main `c3908038490d381543e0b033d26d9844bf171cdb` 为起点，只解决用户重新授权的前两条；没有恢复固定的人类项目/分支方案。主角场景保存默认 0.5 秒保护，启动尊重 Inspector 覆盖；尺度/地图设计预期集中到独立 JSON，机制用例、碰撞与状态边界保留。新约定见 [Inspector 配置归属](inspector-configuration.md)、[设计基线流程](design-baselines.md)、AGENTS 防回归节与各模块 README。

组合源码本地 game `20261003T144553250Z-ee277490`：14/14 检查、138 tests / 2916 assertions，零 failures/errors/skipped；171 项源码/快照哈希、原始 XML、日志和分类结果经主 agent 独立复读。toolchain `20261003T144607860Z-1b39fcf4` 22/22；Node 回归 43/43（含分类器 10 项）。两类失败仍阻止验收，分类补读详细 GUT 日志以避免 XML 首条失败遗漏。

独立基线四阶段的最终检测能力对照为 `20261003T144409Z-f7e2aeb5`：原值通过、只改实验速度失败、手工修改实验期望后通过、破坏实际移动仍失败。正式速度 56 px/s、跳高 16/40 px 与原关卡布局均保留；对照 fixture 的整体 pass 不替代实际 game 验收。恒速夹具碰台阶与 XML 限制的原因/复验见 [公共错误](errors/ERR-20261003-BASELINE-WALK-FIXTURE.md)。

冻结 `121984d…` 的独立 game `20261003T145039751Z-e73b59b3` 亦为14/14、138/2916、零失败/错误/跳过；重新插入旧覆盖后四个新用例全部失败。该故障注入同时发现无冒号 `[Failed]` 的诊断遗漏；原验收仍失败，修复后真实32条失败全部保留，分类器11项/完整Node44项通过，详见 [公共记录](errors/ERR-20261003-GUT-BARE-FAILURE.md)。最终新head需独立完整复验与CI，不用旧head绿灯批准新代码。

以上是提交前组合源码证据，含未提交文件状态，不把它写成最终 PR head 或 main 已通过。冻结 head 的独立测试及 PR/main CI 原始报告需再次核对；实际交付、合并及主目录同步状态保存到主目录 `artifacts/config-baseline-fix-01a10240/`。主目录原有未提交 `project.godot` 保留，不能由 agent 自动 stash/reset 或强行同步。更早下表为各自交付时点；今天的 main/checkout 状态仍按实际提交和报告核实。

## 已进入 main 的功能

2026-10-02 整理时已核对远端 PR、提交包含关系和原始报告。最近一次游戏行为变更为基础速度调整，main 游戏基线 `da2cb24639a77d7ff9b122600aa1d47c0cc9b22c`；后续文档提交不改变该功能基线。最新 checkout/head 仍须现场读取。

| 交付 | 已合并结果 | 当前行为 / 规则 |
| --- | --- | --- |
| 多语言、心形、可变跳跃与保护整合 | [PR #9](https://github.com/gzaii-promax/Codename_Astra/pull/9)，`5d3310364a162a0021de7ca71debc0328d68566c` | 三语菜单；心容器；可变跳跃；主角 0.5 秒保护。见 [整合记录](integration-main.md) |
| 第一版房间地图 | [PR #10](https://github.com/gzaii-promax/Codename_Astra/pull/10)，`a0204b483ef47c98f5e30c89948cc0e463094cd3` | 默认地图 A ↔ B ↔ C 与 C → A；菜单往返训练场。见 [地图契约](map-system.md) |
| 多会话工程流程 | [PR #11](https://github.com/gzaii-promax/Codename_Astra/pull/11)，`30d79a420315f1be1adbeea1a4d718beabe34499` | 每写入会话独立 worktree/分支；工具借用、运行隔离、公共集成锁。见 [worktrees.md](worktrees.md) |
| 基础移动提速 | [PR #12](https://github.com/gzaii-promax/Codename_Astra/pull/12)，`da2cb24639a77d7ff9b122600aa1d47c0cc9b22c` | 3.5 U/s = 56 px/s；加减速、重力、跳跃和阶段规则保留。见 [移动契约](scale-movement-v4.md) |

上述整合提交均属于整理基线的 ancestry。PR #4/#6/#7/#8 原先合入依赖分支，PR #9 才补齐 main；旧 MERGED 标签和旧 draft 描述都不能单独推断 main 内容。

主角/定时敌人各 3 心，稻草人 10 心归零回满；普攻/敌击 0.5 心、火球 1 心。心规则取代旧百分比增减伤，其他角色保护默认零秒。具体数值与接口分别维护在 [心规则](heart-health-v5.md)、[受击保护](hit-protection.md) 和模块 README。

## 可定位的执行证据

| 范围 | 证据 | 已核对结果 |
| --- | --- | --- |
| 游戏基线 main push | [CI 36995028275](https://github.com/gzaii-promax/Codename_Astra/actions/runs/36995028275)，game run `20261002T102213779Z-f7e3cf9e` | commit=`da2cb246…`；14/14 checks；134 tests / 2742 assertions；0 failures/errors/skipped；163 项源码哈希 |
| 速度交接 | `artifacts/speed-handoff/completion.json`、`merge-verification.json` | 实际 PR head/merge、main 同步和对应 CI；用户手感 pending |
| 并行流程交接 | `artifacts/worktree-handoff/completion.json`、`preservation-map.json`；[main CI 36980668317](https://github.com/gzaii-promax/Codename_Astra/actions/runs/36980668317) | Node 33 项；工具/游戏及真实隔离验证；本任务 worktree 已归档，历史 worktree 保留 |
| 地图交接与画面 | `artifacts/map-handoff/map-system-v1.json`；[main CI 36977930744](https://github.com/gzaii-promax/Codename_Astra/actions/runs/36977930744)；`artifacts/map-visual/20261002T064953082Z-d5624293/` | 134 项游戏用例；13 图逐图审核；正常切房与调试；手感 pending |
| 原整合验收 | game `20261001T185434427Z-1a47966d`；`artifacts/integration-workspace/20261001T185442Z/` | 当时 112 tests / 2172 assertions；原目录启动和三语 12 图，仅证明该整合时点 |

这些 artifacts 是主目录保存的忽略证据，新 worktree 不自带。完整游戏基线报告在主目录：`artifacts/speed-handoff/ci-runs/36995028275/checks-36995028275-1/artifacts/test-runs/20261002T102213779Z-f7e3cf9e/report.json`。每轮最新报告通过实际 checkout 的 `artifacts/test-runs/latest.json` 定位；核对 scope、commit/工作树、manifest、JUnit、日志和哈希后才能使用。后续修改需生成对应本轮证据。

更早的全部验收、失败修复和 PR 时点完整保留在 [status-history.md](status-history.md)，Git 依赖链在 [git-history.md](git-history.md)。自动通过、真实截图审核与用户试玩是不同结论。

## 尚未完成与反馈边界

- 用户手感、动作数值/平衡、正式译文和视觉仍待用户审核；现有数值是原型初值。
- 地图转场、提前预加载、攀爬为已采纳的后续必做 TODO，依赖与边界只在 [map-system.md](map-system.md) 维护；本轮未实现。
- 当前没有剧情、互动道具、完整技能树、敌人决策 AI、磁盘世界/成长存档、音乐、正式背景、发行包或跨平台验证。
- 反弹只保留归属切换接口；击倒协助与计时恢复只保留公共接口。主动取消未绑定按键，没有新增对应交互玩法。
- 角色仍为静态占位图，正式素材规格和平台待确定。稻草人当前统计为命中次数与累计完整心伤害，DPS 统计范围尚未决定。
- 公共错误状态与复发入口见 [errors/README.md](errors/README.md)。缺少心形/跳跃的 main 技术问题已闭环；用户试玩结论仍单独保留。

## 本轮文档整理

以 `da2cb246…` 为起点，仅整理 Markdown：补架构与索引，分离当前/历史状态及 Git 流程，纠正模块旧描述和已合并授权语境，补错误索引与技术闭环。源码、场景、数值、测试契约和 CI 实现均未改动。本地冻结验收：Node 33/33；toolchain `20261002T111811603Z-5602113a` 为 22/22；game `20261002T111921061Z-b7337712` 为 14/14、134 tests / 2742 assertions，0 failures/errors/skipped。主/测试 agent 分别复读原始 XML、日志和 163 项源码哈希。随后仅收尾导航、文案与本节记录，最终 head 再由 PR/main CI 核对。

文档检查覆盖 62 份 Markdown、全部入口可达、25 条错误索引一致；两份历史正文逐字保留。执行结果、最终 PR 与合并证据保存在本轮 `artifacts/docs-handoff/`，其中 `completion.json` / `merge-verification.json` 记录实际最终结果；本页不把合并前计划写成已完成。
