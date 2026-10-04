# 文档索引与阅读顺序

第一次接手先读 [运行说明](../README.md)、[AGENTS](../AGENTS.md)、[架构导航](../ARCHITECTURE.md) 和 [当前状态](status.md)。改某个模块时再读其 README 与对应规则，避免把全部历史交付一起当作当前上下文。

## 当前规则与实现入口

| 主题 | 规则 / 边界 | 实现与扩展 |
| --- | --- | --- |
| 房间地图 | [map-system.md](map-system.md)：三房间、有向连接、共享模板与独立探索；后续必做 TODO 也在此维护 | [world](../world/README.md)、[房间编辑](../world/rooms/README.md)、[世界配置](../world/maps/README.md) |
| 尺度与移动 | [scale-movement-v4.md](scale-movement-v4.md)：1 U=16 px、3.5 U/s、可变跳跃；坐标表是训练场布局 | [player](../player/README.md)、[shared](../shared/README.md) |
| 心生命与伤害 | [heart-health-v5.md](heart-health-v5.md)：当前心单位、伤害许可与归零回满；覆盖旧生命版减伤/血条 | [combat](../combat/README.md)、[world](../world/README.md)、[ui](../ui/README.md) |
| Inspector 配置归属 | [inspector-configuration.md](inspector-configuration.md)：保存覆盖、默认值、运行状态、程序管理例外与真实保存往返 | [player](../player/README.md)、[combat](../combat/README.md)、[world](../world/README.md) |
| 受击保护 | [hit-protection.md](hit-protection.md)：主角 0.5 秒、其他角色默认零秒及完整边界 | [combat](../combat/README.md)、[shared](../shared/README.md)、[player](../player/README.md) |
| 技能与阶段 | 已采纳扩展约束见 [AGENTS](../AGENTS.md)；当前属性、单位、等级解析和行为接口见模块文档 | [skills](../skills/README.md) |
| 语言与菜单 | [localization-v2.md](localization-v2.md)：多语言需求与原验收边界；原 draft-only 已被后续整合授权取代 | [localization](../localization/README.md)、[ui](../ui/README.md)、[字体](../assets/fonts/README.md) |
| 素材替换 | 原型占位，不代表正式视觉或故事 | [assets](../assets/README.md)、[graybox](../assets/graybox/README.md)、[player](../player/README.md) |

数值和接口在所属契约/模块文档维护；本页只提供入口。地图 TODO 不复制为另一份待办。剧情、玩法、手感和重要架构决策仍由用户负责，待确定事项见 AGENTS 与当前状态。

## 工程与验证

| 工作 | 入口 |
| --- | --- |
| 编辑器工作流、职责/依赖、signal 再入和效果归属评审 | [engineering-practices.md](engineering-practices.md) |
| 开发隔离、工具借用、编辑器、集成锁、归档 | [worktrees.md](worktrees.md) |
| Commit、PR、合并与 main 同步 | [git-workflow.md](git-workflow.md) |
| 运行验收、读取报告、失败复跑与证据边界 | [testing.md](testing.md)、[tests/README.md](../tests/README.md) |
| 设计数值变更与独立机制回归 | [design-baselines.md](design-baselines.md)、[tests/baselines/README.md](../tests/baselines/README.md) |
| 安装、检查入口和工具职责 | [tools/README.md](../tools/README.md)、[tools/toolchain.json](../tools/toolchain.json) |
| GitHub Actions、原始 artifact 与合并门槛 | [ci.md](ci.md) |
| 查错、用户反馈与状态索引 | [errors/README.md](errors/README.md) |
| 测试用语言资源 | [tests/fixtures/localization/README.md](../tests/fixtures/localization/README.md) |

`artifacts/`、`.tools/`、`.godot/` 是本地忽略数据；新 checkout 不自带。最新测试指针必须在本轮实际 checkout 中读取，按 report_path 找完整报告并核对 scope、代码状态、原始日志和源码哈希。文档里的旧 run_id 只能证明对应历史快照。

## 历史需求与交付

| 文档 | 阅读方式 |
| --- | --- |
| [status-history.md](status-history.md) | 整理前完整状态页：保留所有轮次的 run_id、日志、截图、失败修复和原 PR 状态 |
| [git-history.md](git-history.md) | 整理前完整 Git 交接页：首版初始化、依赖分支链与当时授权例外 |
| [first-version.md](first-version.md) / [delivery-v1.md](delivery-v1.md) | 原训练场需求与首次 PR；旧数值、无限生命稻草人、CI 尚未接入属于当时状态 |
| [delivery-localization-v2.md](delivery-localization-v2.md) | 多语言原 draft PR 描述与原始验收 |
| [health-combat-v3.md](health-combat-v3.md) | 旧通用生命版历史；生命数值、减伤和显示已被心容器规则覆盖 |
| [integration-main.md](integration-main.md) | PR #9 补齐依赖分支、心形/跳跃/保护的整合经过；之后地图与速度继续更新 |

旧交付记录中的“当前”“本轮”按各自时点理解。当前功能以实际 main 源码、包含关系与 [status.md](status.md) 为准，持续提交/合并授权以 AGENTS 为准；旧草稿说明不能重新限制已授权工作。

## 文档维护

- README 负责运行和可玩的操作；AGENTS 负责授权、约束与流程；ARCHITECTURE 负责职责、状态归属和改动入口。
- 模块 README 与功能契约负责接口/规则；status 只保留当前结果、证据入口与尚未完成项。
- 一次性交付过程与旧验收保留在历史记录。搬移历史时保留原始值、来源和失败，不把它改写成当前验收。
- 新增/移动文档时更新本索引及直接引用者；新增错误时更新错误索引。事实变更先核对实现和执行证据，再改状态。
