# 当前交付状态

## 首版技术交付

2026-10-01 已完成本地可运行工程：主角移动/跳跃、普通攻击、火球术、gray box 地图、训练稻草人、可替换静态占位角色及训练信息。使用项目固定 Godot 4.7.2，运行方式见根 README.md。手感与玩法数值仍等待用户试玩反馈。

## 已执行证据

| 范围 | 最终 run_id | 实际结果 |
| --- | --- | --- |
| game（推送前） | `20261001T085453031Z-480c12f9` | 12/12 检查；34 tests、153 assertions；0 failures/errors/skipped |
| toolchain（含 gh） | `20261001T085409035Z-768c274e` | 22/22 检查；预期失败与超时保留底层状态 |

报告分别在 `artifacts/test-runs/<run_id>/report.json`，game 同目录有 `game.xml`、`logs/gut.log`、`logs/startup.log` 和真实工程快照。测试 agent 已核原始 JUnit/引擎日志，主 agent 核对检查完整、日志存在与当前源码 SHA-256 完全一致：60 项文件哈希均匹配，没有阻塞。首次本地交付的原始报告 `20261001T082716048Z-759ee433` 另有第三 agent 的独立交接复核；本轮仅新增固定 gh 配置/工具版本检查及 Git 交接文档，游戏行为代码保持不变。原报告不随交付文档更新而改写。

实际非 headless 图形运行使用 Godot 4.7.2 Compatibility / Apple M4 Pro，已查看 `artifacts/first-version.png`（1440 × 810）与 `artifacts/render-capture.log`：占位主角、火球、目标、中文 HUD 与地图标签可见。截图由真实 viewport 获取；它不证明手感或硬件键盘人工试玩通过。

## 错误与修复

初期项目未齐备阻塞、GUT fixture 的 current_scene 父节点错误均已记录并复跑关闭；动作方向、重置效果、左右贴墙火球的边界修复已添加真实回归并通过。见 errors/ 下对应记录。既往 Xcode/权限问题保留原记录，新的 agent 遇到同类错误应先核对环境。

## Git 与交接

开始本轮时目录没有 Git 仓库或提交历史；本轮已初始化 `main`，游戏最终验收在首次提交前执行，因此报告 commit=null 并保留真实工作树状态与源码哈希。首版完成后建立详细本地提交；用 `git log -5 --format=fuller` 阅读最终提交及验证说明。

本机原先没有提交作者配置，当前仓库使用明确的 agent 作者 `Codex <codex@local.invalid>`，仅本地配置。用户现已授权将首版提交到私有 `gzaii-promax/Codename_Astra`，本机 gh 2.102.0 已安装并由用户完成网页授权。

远端初始为空；建立空 `main` 基线 `8f585ab`，在 `feat/combat-v1` 保留原首版提交 `172c38e` 并通过合并 `e07e4d5` 建立共同历史，游戏内容树保持一致。推送前最终验证通过，main 与功能分支已原子推送到私有远端，并创建[首版 PR #1](https://github.com/gzaii-promax/Codename_Astra/pull/1)，已附加到本 Codex 任务。

用户随后给予持续提交与合并授权。2026-10-01 核对 PR 最新 head `b6d9cdcbc8fb9ab4a5f2aac672c3cdd864930d4a`、既有验收报告及对应文件哈希后，将 PR #1 转为 ready 并使用 Merge commit 合并；GitHub 实际结果为 MERGED，合并提交 `09f35ec8b0ffaba38f6e77974ecc943721828083`。本地 main 已 fast-forward 同步，完整首版代码现已在 main；后续功能从最新 main 新建分支。

提交与合并授权不扩大功能范围，手感仍等待用户试玩反馈。首版描述见 delivery-v1.md，持续 Git 流程见 git-workflow.md。CI 尚未接入，本轮使用本地验收证据，合并不代表 CI、发行或手感验证通过。

## 后续工作边界

- 用户可主动反馈速度、跳跃高度、加减速、普攻移动比例、前后摇、火球速度/冷却、键位和角色观感；新反馈统一记录 channel=user_feedback，保留原意。
- 所有现有数值均为原型初值，不因自动测试通过视为平衡结论。
- 占位图为内置 imagegen 生成的单帧 PNG；没有正式角色动画，素材替换见 assets/README.md、player/README.md。
- 主动取消/受击中断目前是分离的控制器 API 与测试能力，没有取消键或真实受伤链路。
- 当前没有互动道具、完整技能树、敌人 AI、存档、音乐、正式地图、独立发行包或跨平台验证。
- 新机器上的依赖自动安装与 CI 尚未实现；本机工具来源、固定版本和路径已记录。
