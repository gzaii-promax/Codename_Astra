# 当前交付状态

## 通用生命与定时敌人技术交付

2026-10-01 接续未合并的多语言版本，新增通用 Combatant、四种伤害目标规则及加算减伤；默认规则 1、规则 2/3 减伤 50%、零血死亡。支持阵营改变、当前伤害归属重绑定、无敌状态、击倒且不可补刀、剧情直接死亡、同阵营协助起身和显式可选恢复计时。反弹只有来源接口，协助只有公共接口，未新增反弹技能或交互 NPC；默认不安排自动恢复。

训练场右侧新增固定向左的敌人，默认每 1.5 秒尝试近战、前摇 0.3 秒、伤害 10，无追踪、巡逻或决策 AI。主角与敌人各 100 HP，复用同一血条组件；真实攻击扣血，零血停止控制/攻击，菜单暂停计时，R/菜单重置恢复双方并清理效果。允许受击中断时撤销近战窗口但保留冷却；稻草人统计采用最终伤害。原技能时序与数值保持首版基线。

本轮最终 game 报告 `20261001T152213740Z-0f6367a4`：14/14 检查通过，79 tests、1121 assertions，0 failures/errors/skipped；保留原 53 项与新增 26 项验收，106 项源码/协议 SHA-256 与交付前工程匹配。主 agent 已独立读取原始 JUnit、引擎日志并核对源码；完整快照在 `artifacts/test-runs/<run_id>/`。两轮测试设施失败未删除，修复和复验见 `errors/ERR-20261001-HEALTH-TEST-FIXTURE.md`；断言通过但引擎报错的首轮仍记为 fail。

从同一通过快照捕获的真实图形证据位于 `artifacts/health-visual/20261001T152325729Z/`，capture.log exit_code=0、stderr 为空，九张 1440×810 viewport PNG 与 106 项源码哈希齐全。测试 agent 与主 agent 分别打开三语受伤、敌人死亡、主角击倒全部九图，review.json 与 primary-review.json 均为 pass。固定场景 50 px 近战距离下条框、数值与长状态文本分开；敌人死亡文字和倒地身体同步。初轮视觉重叠与 24 px 高度差仍不足的失败均保留，见 `errors/ERR-20261001-HEALTH-BAR-OVERLAP.md`。该证据只覆盖当前场景；主角仍为占位素材，没有专用死亡/击倒姿势，任意密集单位自动排布未验证。

分支 `codex/health-combat-v3` 依赖 `feat/localization-v2`，已创建并核实[草稿 PR #4](https://github.com/gzaii-promax/Codename_Astra/pull/4)：OPEN、isDraft=true、base=feat/localization-v2、head=codex/health-combat-v3，已附加到本 Codex 任务。实现提交 `85473836829e5b876178ff0e1cc265e6f7f725de` 已推送，提交树的 106 项哈希与最终报告一致；后续交接文档提交不改变该验证范围，最终 head 以 GitHub 当前读取为准。依赖 PR #3 仍为草稿；本轮不合并或发布。具体范围与用户采纳规则见 `health-combat-v3.md`。GitHub 当前没有 CI 检查，本轮证据为本地验收；用户试玩手感仍待反馈。

## 首版技术交付

2026-10-01 已完成本地可运行工程：主角移动/跳跃、普通攻击、火球术、gray box 地图、训练稻草人、可替换静态占位角色及训练信息。使用项目固定 Godot 4.7.2，运行方式见根 README.md。手感与玩法数值仍等待用户试玩反馈。

## 多语言下一版技术交付

2026-10-01 在既有工程增加可配置语言模块、暂停菜单、语言选择与帮助。首批 en、ja、zh_CN，每种 30 个文本键，覆盖菜单、HUD、技能名称/说明、帮助和地图标签。语言保存到 ConfigFile，启动恢复；缺失/空译文回退默认简体中文，命名参数由文本入口替换，未知键保持字面值。语言清单与 JSON 可新增或自定义，UI 从清单生成选项；技能只声明文本键，战斗规则与数值保持原基线。

本轮分支 `feat/localization-v2`，已创建并核实[草稿 PR #3](https://github.com/gzaii-promax/Codename_Astra/pull/3)：OPEN、isDraft=true，base=main。实现提交 `23c64a28b1237df2cd8c3f7dee46fabf623d7bec` 已推送；当前 head 以后续 GitHub 读取为准，本轮不合并或发布。剧情脚本以后由用户提供；本轮没有生成故事。范围见 localization-v2.md，新增语言与自定义译文方法见 ../localization/README.md。

## 已执行证据

| 范围 | 最终 run_id | 实际结果 |
| --- | --- | --- |
| game（生命与定时敌人最终） | `20261001T152213740Z-0f6367a4` | 14/14 检查；79 tests、1121 assertions；0 failures/errors/skipped |
| game（多语言最终） | `20261001T103447218Z-fb5fe550` | 14/14 检查；53 tests、649 assertions；0 failures/errors/skipped |
| toolchain（当前协议） | `20261001T102523641Z-7c23a1c9` | 22/22 检查；预期失败与超时保留底层状态 |
| game（首版基线） | `20261001T085453031Z-480c12f9` | 12/12 检查；34 tests、153 assertions；0 failures/errors/skipped |

多语言最终报告覆盖全部 34 个既有回归与 19 个新增用例；93 项文件 SHA-256 对应多语言交付当时工程，原始 JUnit、引擎日志及 manifest 已核对。本轮生命功能采用上文新的 106 项验证。新增两个实际引擎进程验证保存/重启恢复，PID 38715 与 38716，使用同一独立 language-restart.cfg，读取进程未重新设置语言即恢复 ja。所有引擎子进程的 ASTRA_SETTINGS_PATH 在日志与 actual 中记录，不碰玩家设置。

真实图形证据在 `artifacts/localization-visual/20261001T102716473Z/`：capture.log exit_code=0、无引擎错误，report.json、source-hashes.json、九张 1440×810 viewport PNG 齐全。主 agent 已实际打开三语 HUD/菜单/帮助全部九图，并另写 review.json（visual_review=pass），保留原 capture 的 pending 标记作为当时状态。可见中日文无缺字，面板均在 960×540 逻辑画布内；长帮助使用滚动区域。完整文字字形与布局测量另由 GUT 验证，不能把截图保存成功等同于手感或正式译文审核。

报告分别在 `artifacts/test-runs/<run_id>/report.json`，game 同目录有 `game.xml`、`logs/gut.log`、`logs/startup.log` 和真实工程快照。首版验收当时的 60 项哈希对应首版代码，不将该旧报告替代本轮 93 项验证。首次本地交付原始报告 `20261001T082716048Z-759ee433` 另有独立交接复核；原报告不随交付文档更新而改写。

实际非 headless 图形运行使用 Godot 4.7.2 Compatibility / Apple M4 Pro，已查看 `artifacts/first-version.png`（1440 × 810）与 `artifacts/render-capture.log`：占位主角、火球、目标、中文 HUD 与地图标签可见。截图由真实 viewport 获取；它不证明手感或硬件键盘人工试玩通过。

## 错误与修复

初期项目未齐备阻塞、GUT fixture 的 current_scene 父节点错误均已记录并复跑关闭；动作方向、重置效果、左右贴墙火球的边界修复已添加真实回归并通过。见 errors/ 下对应记录。既往 Xcode/权限问题保留原记录，新的 agent 遇到同类错误应先核对环境。

多语言首轮发现 HUD 在初始窄列换行后保留过大高度，底部 2648 超出画布。修复真实容器重排后，三语底部为 161，原 183 项布局断言通过；公共记录 ERR-20261001-LOCALIZATION-HUD-OVERFLOW 已关闭。独立截图探针的 autoload 提前编译问题也已修复并通过原图形方式复验，见 ERR-20261001-I18N-GRAPHICS-PROBE。所有失败与超时证据保留。

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
- 主动取消仍未绑定按键；受击中断已接入主角和定时敌人，遵循阶段策略。击倒协助与计时恢复目前仅提供公共接口，未新增完整交互玩法。
- 当前没有互动道具、完整技能树、敌人决策 AI、存档、音乐、正式地图、独立发行包或跨平台验证。
- 新机器上的依赖自动安装与 CI 尚未实现；本机工具来源、固定版本和路径已记录。
