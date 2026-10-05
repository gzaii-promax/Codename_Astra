# 当前工程状态

## 当前已交付基准

2026-10-05 本轮整理以 `main` 合并提交 `6fe34926c12464df6dfc83ec03a9e2a52af40715`（[PR #17](https://github.com/gzaii-promax/Codename_Astra/pull/17)）为基准。以下结果对应这个提交；本轮流程与编辑入口修改的最终结果须由其实际 PR、CI 与本轮报告确认，不沿用旧绿灯。

| 已交付内容 | 当前规则 / 入口 |
| --- | --- |
| 主角移动、跳跃、普攻与火球 | 1 U=16 px；基础速度 3.5 U/s；短/长跳 1/2.5 U；技能阶段与等级覆盖。见 [移动契约](scale-movement-v4.md)、[player](../player/README.md)、[skills](../skills/README.md) |
| 心生命、定时敌人与训练场 | 主角/敌人各 3 心，稻草人 10 心归零回满；普攻/敌击 0.5 心、火球 1 心；主角默认 0.5 秒受击保护，其他角色默认零秒。见 [心规则](heart-health-v5.md)、[受击保护](hit-protection.md)、[world](../world/README.md) |
| 三房间地图 | Godot 原生灰盒编辑；A ↔ B ↔ C 与 C → A；独立房间身份与探索、相机、碰撞调试，菜单可往返训练场。见 [地图契约](map-system.md) |
| 多语言与菜单 | 中文、英文、日文；暂停、帮助、重置、语言偏好保存。见 [语言契约](localization-v2.md) |
| 工程契约修复 | 尊重保存输入和 Inspector 配置；显式战斗绑定；稳定命中结果；世界/来源效果归属；动作同步再入和有限值校验。见 [工程评审](engineering-practices.md)、[原问题记录](errors/ERR-20261005-ENGINEERING-CONTRACTS.md) |

架构与配置入口见 [ARCHITECTURE](../ARCHITECTURE.md) 和 [文档索引](index.md)。历史依赖分支的 MERGED 状态不能代替 main 提交包含关系核对。

## 基准提交的已核对证据

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
