# 当前交付状态

## 受击保护技术交付（2026-10-02）

新增公共 `shared/combat_config.gd`：主角保护 0.5 秒，其他生命角色默认 0 秒。正伤害后由公共 `Combatant` 先启动保护再发送事件；保护内不扣血、不更新血条、不重复受击中断，拒绝不续期。零秒显式跳过保护判定，零伤害不启动计时。暂停冻结计时，训练重置、死亡、击倒与起身清零；剧情死亡继续生效。完整约定见 [hit-protection.md](hit-protection.md)。

独立最终 game 报告 `20261001T180028010Z-3cfc27f7` 为 14/14 检查、103 tests、1361 assertions，0 failures/errors/skipped；保留全部 93 项既有用例，新增 10 项保护验收。先行报告 `20261001T175713993Z-d067c708` 亦通过，在其基础上加强第 30 帧到期与跨截止近战窗口验证后才运行最终报告，没有用旧结果替代新源码。

独立测试 agent 与主 agent 分别读取报告、原始 XML/名册、21 份日志和 122 项源码/协议 SHA-256，全部与当前工作区一致、无引擎错误。实际 60 Hz 下第 12 帧剩约 0.3 秒、第 29 帧仍拒绝、第 30 帧剩 0 并可再次受伤；长近战窗口跨截止后生命 90→80，窗口结束仍 80、只一次事件，后续真实火球降至 73。零秒敌人/稻草人连续命中、暂停/重置、受击事件重入与生命周期均覆盖。

实际工作区另外用固定 Godot 执行 `--editor --import` 和主场景 `--quit-after 120`，均 exit0、无引擎错误、stderr 为空；独立 settings 路径不触碰玩家配置。原始 argv/日志和报告保存在最终运行目录 `workspace-checks/`，确认实际类缓存注册 `CombatConfig`，导入后 122 项源码哈希及两个新 UID 仍与通过快照一致。

已核实远端 PR #3 合入 main、尺度 PR #6 合入生命分支；生命 PR #4 当前仍为 OPEN draft。本轮从生命 head `06718c78a27e4ffd822d8d8ec9e61ca48897fa79` 接续到 `codex/hit-protection`，独立草稿、不合并或发布。下方旧版本描述保留各轮原交付时点；当前版本未进入 main，用户手感仍待试玩反馈。

## 统一尺度与可变跳跃技术交付（2026-10-02）

按用户采纳需求落实 1 U=16 个逻辑像素，公共常数提炼到 shared/game_units.gd，所属模块文档记录单位、职责与变更要求。主角身体/受击框、稻草人受击框均 16×32 px；稻草人允许穿过，技能攻击框保持独立。地图外框 512×256 px（含墙、顶、地板）置于原 960×540 逻辑视口，出生点和平台按 U 配置；基础移动 24 px/s，无遮挡短至长跳上升 16–40 px。具体范围与工程初值见 [scale-movement-v4.md](scale-movement-v4.md)。

首次松键截断本次上升，同一物理帧间松键重按也保留 release；持续持键落地不连跳，保留缓冲与土狼时间。三语帮助同步短按/长按说明。独立完整 game 验收 `20261001T171024428Z-05e42084`：14/14 检查、93 tests、1222 assertions，0 failures/errors/skipped。实测短/9帧中/长跳为 16.0886/22.4122/40.0871 px；真实 Space 持 1 个物理帧的短跳同为 16.0886 px；真实 60 帧移动 24 px。主 agent 独立读取 XML、原日志与报告，114 项运行前源码/协议哈希一致；四份同一通过快照导入生成的 UID 元数据另有原件/哈希核对。

真实图形证据在 `artifacts/scale-visual/20261001T171024428Z-05e42084/`：scale 三图与 localization 三语 HUD/菜单/帮助九图均为 1440×810、capture exit0、无错误。主 agent 实际打开全部十二图，primary-review.json 为 pass；独立审查 agent 另打开尺度三图并记录 independent-review.json 为 pass。地图、角色和稻草人显示完整，短/长跳画面位置不同，更新帮助可在面板内换行滚动；截图不代表用户手感或正式美术验收。

首轮四项测试调度失败报告保留并关闭，见 [采样与等待修复](errors/ERR-20261002-SCALE-TEST-SAMPLING.md)。额外工作区直接启动检查发现旧类缓存，刷新导入后实际主场景 120 帧无错误，见 [工作区类缓存](errors/ERR-20261002-WORKSPACE-CLASS-CACHE.md)。原始失败不会当作通过记录。

本轮实现提交 `05efebb1ab74fd2764ddae8a4b111672c8ead4e8` 已推送，已创建并核实[草稿 PR #6](https://github.com/gzaii-promax/Codename_Astra/pull/6)：OPEN、isDraft=true、base=codex/health-combat-v3、head=codex/scale-movement-v4，已附加到本 Codex 任务。依赖 PR #3/#4 继续保持草稿，本轮不合并或发布。用户试玩手感仍待反馈；交接时远端普通 PR CI 已启动，最终 head 和结果以该 PR 当前检查与原始 artifact 为准，不使用旧版本绿灯代替。

## 通用生命与定时敌人技术交付

2026-10-01 接续未合并的多语言版本，新增通用 Combatant、四种伤害目标规则及加算减伤；默认规则 1、规则 2/3 减伤 50%、零血死亡。支持阵营改变、当前伤害归属重绑定、无敌状态、击倒且不可补刀、剧情直接死亡、同阵营协助起身和显式可选恢复计时。反弹只有来源接口，协助只有公共接口，未新增反弹技能或交互 NPC；默认不安排自动恢复。

训练场右侧新增固定向左的敌人，默认每 1.5 秒尝试近战、前摇 0.3 秒、伤害 10，无追踪、巡逻或决策 AI。主角与敌人各 100 HP，复用同一血条组件；真实攻击扣血，零血停止控制/攻击，菜单暂停计时，R/菜单重置恢复双方并清理效果。允许受击中断时撤销近战窗口但保留冷却；稻草人统计采用最终伤害。原技能时序与数值保持首版基线。

CI接入前的生命版本 game 报告 `20261001T152213740Z-0f6367a4`：14/14 检查通过，79 tests、1121 assertions，0 failures/errors/skipped；保留原 53 项与新增 26 项验收，106 项源码/协议 SHA-256 与交付前工程匹配。主 agent 已独立读取原始 JUnit、引擎日志并核对源码；完整快照在 `artifacts/test-runs/<run_id>/`。两轮测试设施失败未删除，修复和复验见 `errors/ERR-20261001-HEALTH-TEST-FIXTURE.md`；断言通过但引擎报错的首轮仍记为 fail。

从同一通过快照捕获的真实图形证据位于 `artifacts/health-visual/20261001T152325729Z/`，capture.log exit_code=0、stderr 为空，九张 1440×810 viewport PNG 与 106 项源码哈希齐全。测试 agent 与主 agent 分别打开三语受伤、敌人死亡、主角击倒全部九图，review.json 与 primary-review.json 均为 pass。固定场景 50 px 近战距离下条框、数值与长状态文本分开；敌人死亡文字和倒地身体同步。初轮视觉重叠与 24 px 高度差仍不足的失败均保留，见 `errors/ERR-20261001-HEALTH-BAR-OVERLAP.md`。该证据只覆盖当前场景；主角仍为占位素材，没有专用死亡/击倒姿势，任意密集单位自动排布未验证。

分支 `codex/health-combat-v3` 依赖 `feat/localization-v2`，已创建并核实[草稿 PR #4](https://github.com/gzaii-promax/Codename_Astra/pull/4)：OPEN、isDraft=true、base=feat/localization-v2、head=codex/health-combat-v3，已附加到本 Codex 任务。实现提交 `85473836829e5b876178ff0e1cc265e6f7f725de` 已推送，提交树的 106 项哈希与最终报告一致；后续交接文档提交不改变该验证范围，最终 head 以 GitHub 当前读取为准。依赖 PR #3 仍为草稿；本轮不合并或发布。具体范围与用户采纳规则见 `health-combat-v3.md`。生命版本原交付时尚无 CI，使用当时本地验收；当前 CI 同步另列下节；用户试玩手感仍待反馈。

## 首版技术交付

2026-10-01 已完成本地可运行工程：主角移动/跳跃、普通攻击、火球术、gray box 地图、训练稻草人、可替换静态占位角色及训练信息。使用项目固定 Godot 4.7.2，运行方式见根 README.md。手感与玩法数值仍等待用户试玩反馈。

## 多语言下一版技术交付

2026-10-01 在既有工程增加可配置语言模块、暂停菜单、语言选择与帮助。首批 en、ja、zh_CN，每种 30 个文本键，覆盖菜单、HUD、技能名称/说明、帮助和地图标签。语言保存到 ConfigFile，启动恢复；缺失/空译文回退默认简体中文，命名参数由文本入口替换，未知键保持字面值。语言清单与 JSON 可新增或自定义，UI 从清单生成选项；技能只声明文本键，战斗规则与数值保持原基线。

本轮分支 `feat/localization-v2`，已创建并核实[草稿 PR #3](https://github.com/gzaii-promax/Codename_Astra/pull/3)：OPEN、isDraft=true，base=main。实现提交 `23c64a28b1237df2cd8c3f7dee46fabf623d7bec` 已推送；当前 head 以后续 GitHub 读取为准，本轮不合并或发布。剧情脚本以后由用户提供；本轮没有生成故事。范围见 localization-v2.md，新增语言与自定义译文方法见 ../localization/README.md。

## 已执行证据

| 范围 | 最终 run_id | 实际结果 |
| --- | --- | --- |
| game（生命原交付） | `20261001T152213740Z-0f6367a4` | 14/14 检查；79 tests、1121 assertions；0 failures/errors/skipped |
| game（多语言原交付） | `20261001T103447218Z-fb5fe550` | 14/14 检查；53 tests、649 assertions；0 failures/errors/skipped |
| toolchain（CI接入前） | `20261001T102523641Z-7c23a1c9` | 22/22 检查；预期失败与超时保留底层状态 |
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

提交与合并授权不扩大功能范围，手感仍等待用户试玩反馈。首版描述见 delivery-v1.md，持续 Git 流程见 git-workflow.md。首版合并时尚未接入 CI，使用本地验收证据；当前 CI 接入证据另列下节，发行和手感仍分别验证。

## 后续工作边界

- 用户可主动反馈速度、跳跃高度、加减速、普攻移动比例、前后摇、火球速度/冷却、键位和角色观感；新反馈统一记录 channel=user_feedback，保留原意。
- 所有现有数值均为原型初值，不因自动测试通过视为平衡结论。
- 占位图为内置 imagegen 生成的单帧 PNG；没有正式角色动画，素材替换见 assets/README.md、player/README.md。
- 主动取消仍未绑定按键；受击中断已接入主角和定时敌人，遵循阶段策略。击倒协助与计时恢复目前仅提供公共接口，未新增完整交互玩法。
- 当前没有互动道具、完整技能树、敌人决策 AI、存档、音乐、正式地图、独立发行包或跨平台验证。
- 新机器上的依赖自动安装与 CI 已完成main接入；各版本实际验收见下方记录。

## 持续集成接入（2026-10-01）

独立 CI 分支从 main 建立，范围见 [ci.md](ci.md)。多语言 PR #3 与生命 PR #4 保持未合并草稿；PR 详情面板加载问题按用户要求暂缓。

全新依赖安装报告 `artifacts/bootstrap/20261001T155028596Z-58d98722/report.json` 为18/18通过。隔离缓存重装报告 `20261001T155256529Z-ce9ae058` 为16/16通过：缓存归档仍核对 SHA-256，故意损坏的 GUT 元数据恢复，venv 旧标记清除。本机原工具保留，CI 使用 `.tools/ci/toolchain.json`。

GitHub 分支保护 API 返回403，要求升级套餐或公开仓库，暂无法对私有 main 设置必需检查；未修改可见性或付费设置。合并前仍由 agent 核对最新 head、实际检查、原始报告与源码哈希。

独立本地验收：安装/配置 Node 单测9/9；CI 配置 toolchain `20261001T155653795Z-06765dcf` 为21/21通过；game `20261001T155734136Z-1d5d0e3c` 为12/12通过、34 tests / 153 assertions、0 failures/errors/skipped。主 agent 复读报告、JUnit 与日志路径，65份游戏/入口源码 SHA-256 全部匹配。非法配置回归 `20261001T155620615Z-7a58ec62` 正确 exit1/blocked，保留12项与配置路径，未回退本机配置。远端成功、故意失败与恢复验证尚待实际运行，不以本地通过代替 GitHub 结论。

第一轮远端运行 [36888487517](https://github.com/gzaii-promax/Codename_Astra/actions/runs/36888487517) 在 setup-python 未找到固定3.12.14 ARM64包而失败；业务检查未执行，原始job log已保存，详见 errors/ERR-20261002-CI-PYTHON.md。修复保留同版本，改用固定Astral PBS归档。实际下载重装 `20261001T160323835Z-f71e0171` 为21/21通过，Python3.12.14/darwin-arm64/稳定base_path均记录，单测增至10项。旧本地验收仅对应旧源码，新源码验收与远端复跑另行记录。

修复版独立本地验收：Node10/10；CI toolchain `20261001T160452470Z-75687419` 为21/21；game `20261001T160529698Z-fa10d4aa` 为12/12、34 tests/153 assertions、0 failures/errors/skipped。全部65份game源码哈希、配置哈希与原始证据路径一致。对应新PBS运行时配置，远端复跑待核实。

普通PR远端证据（已下载至 `artifacts/ci-runs/<GitHub run_id>/`，另有主/测试agent独立核查）：

| 情形 | GitHub run | 实际结果 |
| --- | --- | --- |
| 正常源码 | [36889507143](https://github.com/gzaii-promax/Codename_Astra/actions/runs/36889507143) | Python阻断修复；bootstrap23/23、Node10/10、toolchain21/21、game12/12；34tests153assertions无失败/跳过；65源码hash匹配head817c119 |
| 临时失败探针 | [36889794629](https://github.com/gzaii-promax/Codename_Astra/actions/runs/36889794629) | headf4ebc65；普通game/job真实失败；唯一失败case为test_large_tick_carries_time_through_all_phases，XML/原log含CI_FAILURE_PROBE；失败artifact成功上传，其余准备/工具检查通过 |

本次恢复提交明确撤销失败探针，测试源码与正常验收的原合同一致；最终差异不保留错误断言，也不放宽正常game失败规则。[CI PR #5](https://github.com/gzaii-promax/Codename_Astra/pull/5) 的最新head必须重新通过 `macOS / repository-checks`，核对源码/实际配置/合并引用后按持续授权使用Merge commit合入main，再核对main push检查。最终动态状态及原始artifact见PR检查；不能用上述历史绿灯批准新head。两个功能草稿继续保留，CI同步进入它们只更新基础设施和验收记录。

### CI 同步到多语言草稿

CI [PR #5](https://github.com/gzaii-promax/Codename_Astra/pull/5) 已按持续授权合并，main实际提交 `6a7dd66b64f10831b502a8614c2844f2a7ba0e2c`；最终恢复 head90d8bf7 的 [run36890205920](https://github.com/gzaii-promax/Codename_Astra/actions/runs/36890205920) 全通过。main push检查 [36890671925](https://github.com/gzaii-promax/Codename_Astra/actions/runs/36890671925) 另验实际合并提交。

本草稿同步main的安装器、工作流与配置读取；保留localization快照、字体、独立settings路径和跨进程恢复验收。多语言业务代码、素材与53项测试契约保持原样，三个交接文档冲突按各自版本范围并置。后续最新head仍须本地和远端必要验收通过，PR #3保持draft。

main实际合并提交的push run36890671925已全通过并取回原artifact，head/实际commit一致6a7dd66，bootstrap23/23、toolchain21/21、game12/12、34/153、65源码hash匹配。多语言同步后的独立本地game `20261001T161745574Z-f9af9883` 为14/14、53tests649assertions、0失败/错误/跳过，98源码hash和有效CI配置一致；两个独立进程验证ja保存/重启恢复。最新远端head验收见PR #3检查。

### CI 同步到生命草稿

接续更新的多语言base66a143e，保留通用生命/伤害规则/定时敌人/血条的完整业务代码、素材及79项测试契约。两处交接文档冲突并置CI与生命版本事实；原53项多语言回归、设置隔离和跨进程恢复仍保留。PR #4继续draft，base仍为feat/localization-v2。最新head必须运行相同普通PR CI并核对原始证据。

多语言草稿最新head66a143e的 [run36891160942](https://github.com/gzaii-promax/Codename_Astra/actions/runs/36891160942) 远端已通过：bootstrap23/23、Node10/10、toolchain21/21、game14/14、53/649，98源码hash与实际merge引用和配置吻合，原artifact/XML已取回。

生命同步后的独立本地game `20261001T162117348Z-b8cf2746` 为14/14、79tests1121assertions、0失败/错误/跳过；111源码hash与快照/有效CI配置一致，21份原始日志无引擎错误，两个进程验证ja保存与重启恢复。业务文件与原9544618交付diff为空；推送最新head后按PR #4远端检查与原artifact核验，继续保留draft。
