# 当前工程状态

## 当前实现基准

2026-10-05 [PR #18](https://github.com/gzaii-promax/Codename_Astra/pull/18) 已合并，游戏与工具实现基准为 `74fe97841e1c936035c5647223df8df38a2f96ce`。下表包含该版本；后续仅状态文档记录更新不改变这个行为基准，实际 checkout/HEAD 仍从工作区读取。

| 已交付内容 | 当前规则 / 入口 |
| --- | --- |
| 主角移动、跳跃、普攻与火球 | 1 U=16 px；基础速度 3.5 U/s；短/长跳 1/2.5 U；技能阶段与等级覆盖。见 [移动契约](scale-movement-v4.md)、[player](../player/README.md)、[skills](../skills/README.md) |
| 心生命、定时敌人与训练场 | 主角/敌人各 3 心，稻草人 10 心归零回满；普攻/敌击 0.5 心、火球 1 心；主角默认 0.5 秒受击保护，其他角色默认零秒。见 [心规则](heart-health-v5.md)、[受击保护](hit-protection.md)、[world](../world/README.md) |
| 三房间地图 | Godot 原生灰盒编辑；A ↔ B ↔ C 与 C → A；独立房间身份与探索、相机、碰撞调试，菜单可往返训练场。见 [地图契约](map-system.md) |
| 多语言与菜单 | 中文、英文、日文；暂停、帮助、重置、语言偏好保存。见 [语言契约](localization-v2.md) |
| 工程契约修复 | 尊重保存输入和 Inspector 配置；显式战斗绑定；稳定命中结果；世界/来源效果归属；动作同步再入和有限值校验。见 [工程评审](engineering-practices.md)、[原问题记录](errors/ERR-20261005-ENGINEERING-CONTRACTS.md) |
| 训练场编辑配置与调试输入 | 保存地形与出生标记；场景局部 DebugInput；保存/重载/重置、停用及错误绑定。见 [world](../world/README.md) |
| 按影响检查与证据归档 | docs 入口、保守 CI 路径分级、当前/历史分离与关键失败归档。见 [测试协议](testing.md)、[CI](ci.md) |

架构与配置入口见 [ARCHITECTURE](../ARCHITECTURE.md) 和 [文档索引](index.md)。历史依赖分支的 MERGED 状态不能代替 main 提交包含关系核对。

## 本轮编辑入口与流程改进

- [训练场场景](../world/training_arena.tscn) 的地形保存为 `Geometry` 下六个可编辑 StaticBody2D，出生位置保存为 `Spawns` 下三个 Marker2D。根节点通过显式路径读取出生位置；保存、重载、入树与重置不再重新注入固定坐标。默认地形和动作数值沿用原独立基线。
- 两个世界各自持有 `DebugInput` 子节点，统一 F2 等调试命令；玩家、世界、碰撞显示路径及房间快捷键可配置，保存的 `enabled=false` 生效。错误绑定拒绝命令并保留诊断，暂停时不执行。编辑入口与限制见 [world](../world/README.md)。
- `node tools/check.mjs --scope docs` 提供无需引擎的本地 Markdown 结构检查与报告。CI 只有状态、历史、索引四个明确路径可走轻量分支；规则、代码、配置、工具、未知或不可核对的 diff 仍完整验收。范围及证据边界统一见 [测试协议](testing.md#按影响选择检查)。
- 当前状态与历史快照分开；关键原失败证据进入版本控制，普通运行快照留在忽略目录。CI 报告请求保留 90 天，仍受仓库/组织策略上限约束。

新增六个真实引擎用例先在原代码复现六项失败，再验证保存的地形/出生点、错误绑定、暂停、嵌套调试节点及自定义按键；完整交付证据如下。这些实现不代表用户已认可试玩效果。

## 本轮已核对证据与同步

| 范围 | 实际结果 |
| --- | --- |
| 原失败与独立组合复验 | 旧实现新增六项全部失败，14 条原始机制断言；独立 game `20261005T093756546Z-2329dbc8`：14/14 checks、177 tests / 3243 assertions，零失败/错误/跳过；188 项报告源码、165 项快照哈希核对一致 |
| 工具与文档 | Node 54/54；本地 toolchain 22/22（含 gh）；最终 docs 2/2。独立 game 使用 `7f4c5b2…`，最终 head `b76224e…` 仅四份说明文档变化，其余 245 个受控文件哈希相同；最终 PR/main CI 另对完整源码验收 |
| PR CI | [37291579416](https://github.com/gzaii-promax/Codename_Astra/actions/runs/37291579416)：head=`b76224e…`、实际合并引用=`167b56fe…`；docs 2/2、CI toolchain 21/21（不含 gh）、game 14/14、177/3243，源码哈希全部对应最终 head |
| 实际 main CI | [37292224277](https://github.com/gzaii-promax/Codename_Astra/actions/runs/37292224277)：报告提交=`74fe9784…`；Node 54/54、docs 2/2、toolchain 21/21、game 14/14、177/3243；188 项游戏源码哈希核对一致，原始日志无引擎错误 |
| 实际画面 | 实际 viewport 图已查看；训练地形、角色与心读数、地图调试覆盖正常；短/长跳峰高约 16.09/40.09 px。截图检查与用户手感分别判断 |

原目录 `/Users/hanguo/Documents/ChatGPT/Godot-project` 本次经用户选择“备份原文件后同步 main”后，同步至 `74fe9784…` 并现场确认工作树干净。原 `project.godot` 与补丁保存在其 `artifacts/review-improvements-primary-original/`；目标配置逐字保留原编辑器改动，另外含已验证 Input Map。

实际导入曾恢复缺少 GUT 依赖的旧单测标签，原日志保留；备份编辑器布局缓存后仅关闭 `test_hit_protection.gd` 标签，选中的玩家脚本与其他标签保留。随后原目录导入和主场景 120 帧启动均无引擎错误，没有修改游戏源码或用户语言设置。

完整报告、原失败、CI 上下文、快照、备份和同步核查保存在本任务 checkout 的 `artifacts/review-improvements/`；`merge-verification.json` 与 `preservation-map.json` 提供身份和归档位置。普通 ignored 证据不随新 checkout 自动出现，关键历史摘录按下节归档。

## 上一版本的历史证据

[main push CI 37221178853](https://github.com/gzaii-promax/Codename_Astra/actions/runs/37221178853) 的 CI 上下文和 game 报告实际提交均为 `6fe34926c12464df6dfc83ec03a9e2a52af40715`。game run `20261004T173723640Z-40245eee` 为 14/14 checks、171 tests / 3175 assertions，零 failures/errors/skipped。本轮重读原始 report、JUnit 与 21 份日志，180 项源码/协议 SHA-256 与该基准 checkout 一致，未发现脚本/引擎错误。这是基准版本的技术证据，不能证明后续修改已经通过。

原始报告保存在交付 worktree `/Users/hanguo/.codex/worktrees/e156/Godot-project/artifacts/engineering-safety/ci-runs/37221178853/artifacts/test-runs/20261004T173723640Z-40245eee/`；PR/main 合并与独立复验身份见同一 `artifacts/engineering-safety/` 下的 `completion.json`、`merge-verification.json`。这些是本地忽略证据，新 checkout 不自带；关键证据的长期归档按 [测试协议](testing.md) 执行。

[PR #17 精简历史证据](evidence/pr-17/README.md) 保存关键原失败日志摘录、原始失败/main JUnit 和来源哈希；报告摘要与日志摘录明确标示保留范围，不能冒充完整原始报告，也不证明后续版本通过。

远端已合并与用户原目录同步是两个结果。原目录曾因未提交 `project.godot` 延期同步，记录见历史；现在是否同步，必须读取其分支、HEAD、工作树和使用状态，不能据旧记录代替现场核实。后续验收从实际 checkout 的 `artifacts/test-runs/latest.json` 找完整报告并核对 scope、源码身份及原始证据。

## 尚未完成与用户验收

- 用户手感、动作数值/平衡、正式译文和视觉仍待审核；当前数值是可按明确指令调整的原型初值。
- 地图转场、提前预加载、攀爬为已采纳的后续必做 TODO，边界仅在 [地图契约](map-system.md) 维护。
- 尚无剧情、互动道具、完整技能树、敌人决策 AI、磁盘世界/成长存档、音乐、正式背景、发行包或跨平台验证。发布平台与正式素材规格未定。
- 主角为静态占位视觉；TrainingHUD 是用户认可的临时测试实现，正式重做与其他工程债见 [ui](../ui/README.md)、[工程评审](engineering-practices.md)。
- 稻草人统计为命中次数和累计心伤害，DPS 范围待确定；主动取消尚未绑定按键，反弹、击倒协助与计时恢复仅有公共接口。

自动测试、真实截图审核与用户试玩分别判断。原问题与反馈入口见 [公共错误记录](errors/README.md)；历次交付原文见 [status-history.md](status-history.md) 和 [git-history.md](git-history.md)。
