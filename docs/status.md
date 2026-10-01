# 当前交付状态

## 首版技术交付

2026-10-01 已完成本地可运行工程：主角移动/跳跃、普通攻击、火球术、gray box 地图、训练稻草人、可替换静态占位角色及训练信息。使用项目固定 Godot 4.7.2，运行方式见根 README.md。手感与玩法数值仍等待用户试玩反馈。

## 已执行证据

| 范围 | 最终 run_id | 实际结果 |
| --- | --- | --- |
| game（推送前） | `20261001T085453031Z-480c12f9` | 12/12 检查；34 tests、153 assertions；0 failures/errors/skipped |
| toolchain（含 gh） | `20261001T085409035Z-768c274e` | 22/22 检查；预期失败与超时保留底层状态 |

报告分别在 `artifacts/test-runs/<run_id>/report.json`，game 同目录有 `game.xml`、`logs/gut.log`、`logs/startup.log` 和真实工程快照。测试 agent 已核原始 JUnit/引擎日志，主 agent 在当次首版交付时核对检查完整、日志存在与当时源码 SHA-256 完全一致：60 项文件哈希均匹配，没有阻塞。首次本地交付的原始报告 `20261001T082716048Z-759ee433` 另有第三 agent 的独立交接复核；本轮仅新增固定 gh 配置/工具版本检查及 Git 交接文档，游戏行为代码保持不变。原报告不随交付文档更新而改写。

实际非 headless 图形运行使用 Godot 4.7.2 Compatibility / Apple M4 Pro，已查看 `artifacts/first-version.png`（1440 × 810）与 `artifacts/render-capture.log`：占位主角、火球、目标、中文 HUD 与地图标签可见。截图由真实 viewport 获取；它不证明手感或硬件键盘人工试玩通过。

## 错误与修复

初期项目未齐备阻塞、GUT fixture 的 current_scene 父节点错误均已记录并复跑关闭；动作方向、重置效果、左右贴墙火球的边界修复已添加真实回归并通过。见 errors/ 下对应记录。既往 Xcode/权限问题保留原记录，新的 agent 遇到同类错误应先核对环境。

## Git 与交接

开始本轮时目录没有 Git 仓库或提交历史；本轮已初始化 `main`，游戏最终验收在首次提交前执行，因此报告 commit=null 并保留真实工作树状态与源码哈希。首版完成后建立详细本地提交；用 `git log -5 --format=fuller` 阅读最终提交及验证说明。

本机原先没有提交作者配置，当前仓库使用明确的 agent 作者 `Codex <codex@local.invalid>`，仅本地配置。用户现已授权将首版提交到私有 `gzaii-promax/Codename_Astra`，本机 gh 2.102.0 已安装并由用户完成网页授权。

远端初始为空；建立空 `main` 基线 `8f585ab`，在 `feat/combat-v1` 保留原首版提交 `172c38e` 并通过合并 `e07e4d5` 建立共同历史，游戏内容树保持一致。推送前最终验证通过，main 与功能分支已原子推送到私有远端，并创建[首版 PR #1](https://github.com/gzaii-promax/Codename_Astra/pull/1)，已附加到本 Codex 任务。

用户随后给予持续提交与合并授权。2026-10-01 核对 PR 最新 head `b6d9cdcbc8fb9ab4a5f2aac672c3cdd864930d4a`、既有验收报告及对应文件哈希后，将 PR #1 转为 ready 并使用 Merge commit 合并；GitHub 实际结果为 MERGED，合并提交 `09f35ec8b0ffaba38f6e77974ecc943721828083`。本地 main 已 fast-forward 同步，完整首版代码现已在 main；后续功能从最新 main 新建分支。

提交与合并授权不扩大功能范围，手感仍等待用户试玩反馈。首版描述见 delivery-v1.md，持续 Git 流程见 git-workflow.md。首版合并时尚未接入 CI，使用本地验收证据；当前 CI 接入证据另列下节，发行和手感仍分别验证。

## 后续工作边界

- 用户可主动反馈速度、跳跃高度、加减速、普攻移动比例、前后摇、火球速度/冷却、键位和角色观感；新反馈统一记录 channel=user_feedback，保留原意。
- 所有现有数值均为原型初值，不因自动测试通过视为平衡结论。
- 占位图为内置 imagegen 生成的单帧 PNG；没有正式角色动画，素材替换见 assets/README.md、player/README.md。
- 主动取消/受击中断目前是分离的控制器 API 与测试能力，没有取消键或真实受伤链路。
- 当前没有互动道具、完整技能树、敌人 AI、存档、音乐、正式地图、独立发行包或跨平台验证。
- 新机器上的依赖自动安装与 CI 已获接入授权；实际状态见下方持续集成记录。

## 持续集成接入（2026-10-01）

独立 CI 分支从 main 建立，范围见 [ci.md](ci.md)。多语言 PR #3 与生命 PR #4 保持未合并草稿；PR 详情面板加载问题按用户要求暂缓。

全新依赖安装报告 `artifacts/bootstrap/20261001T155028596Z-58d98722/report.json` 为18/18通过。隔离缓存重装报告 `20261001T155256529Z-ce9ae058` 为16/16通过：缓存归档仍核对 SHA-256，故意损坏的 GUT 元数据恢复，venv 旧标记清除。本机原工具保留，CI 使用 `.tools/ci/toolchain.json`。

GitHub 分支保护 API 返回403，要求升级套餐或公开仓库，暂无法对私有 main 设置必需检查；未修改可见性或付费设置。合并前仍由 agent 核对最新 head、实际检查、原始报告与源码哈希。

独立本地验收：安装/配置 Node 单测9/9；CI 配置 toolchain `20261001T155653795Z-06765dcf` 为21/21通过；game `20261001T155734136Z-1d5d0e3c` 为12/12通过、34 tests / 153 assertions、0 failures/errors/skipped。主 agent 复读报告、JUnit 与日志路径，65份游戏/入口源码 SHA-256 全部匹配。非法配置回归 `20261001T155620615Z-7a58ec62` 正确 exit1/blocked，保留12项与配置路径，未回退本机配置。远端成功、故意失败与恢复验证尚待实际运行，不以本地通过代替 GitHub 结论。

第一轮远端运行 [36888487517](https://github.com/gzaii-promax/Codename_Astra/actions/runs/36888487517) 在 setup-python 未找到固定3.12.14 ARM64包而失败；业务检查未执行，原始job log已保存，详见 errors/ERR-20261002-CI-PYTHON.md。修复保留同版本，改用固定Astral PBS归档。实际下载重装 `20261001T160323835Z-f71e0171` 为21/21通过，Python3.12.14/darwin-arm64/稳定base_path均记录，单测增至10项。旧本地验收仅对应旧源码，新源码验收与远端复跑另行记录。

修复版独立本地验收：Node10/10；CI toolchain `20261001T160452470Z-75687419` 为21/21；game `20261001T160529698Z-fa10d4aa` 为12/12、34 tests/153 assertions、0 failures/errors/skipped。全部65份game源码哈希、配置哈希与原始证据路径一致。对应新PBS运行时配置，远端复跑待核实。
