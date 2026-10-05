# Agent 测试协议

## 范围与入口

- 范围由命令参数确定：`docs` 验证 Markdown 文件与本地链接；`toolchain` 验证测试工具自身；`game` 验证真实项目及既有回归。各范围的 pass 只证明自己的检查完成，不能证明用户已认可手感。
- 工作目录：项目根目录，即 `AGENTS.md` 所在目录；尚未建立 Git 仓库时同样适用。
- 单一入口：`node tools/check.mjs --scope docs|toolchain|game`（执行时选择一个范围）。未知范围和参数必须拒绝。
- 路径、固定版本、来源：`tools/toolchain.json`。工具本体在 `.tools/`，不提交。
- 新机器/CI 需要 game/toolchain 验收时先执行 `node tools/bootstrap.mjs`；按输出配置路径设置 `ASTRA_TOOLCHAIN_CONFIG`。安装与验收分开，game/toolchain 共用 `tools/toolchain-config.mjs`；docs 只需 Node 与 Git，不安装引擎依赖。CI 具体触发、证据与合并门槛见 [ci.md](ci.md)。
- 具体安装与测试状态：见最新报告；未执行或报告缺失时为未验证。
- 新建或修改测试流程后立即执行；每次准备验收前执行本轮必要检查。
- 地图版完整 GUT 进程预算为 150 秒。新增真实物理用例使原 90 秒首轮真实超时，证据保留在 ERR-20261002-MAP-VALIDATION.md；提高有限预算不改变检查集合、断言、超时失败和原始 XML 要求。
- 本机已验证的执行方式：在获准的沙箱外环境运行相同入口。沙箱内 Godot 用户缓存与 Python fixture 文件访问曾失败，见 [ENV-0004](errors/ENV-0004.md)。新 agent 应先读取该记录；权限失败时先核对执行环境，保持测试预期及 `HOME` 不变。

## 按影响选择检查

本地验收开始时由 agent 按实际 diff 选择下表；混合改动执行所有适用项。分类写在 PR/交接的验证说明即可，不新增分级模板。修改授权、验收规则或测试入口不属于纯文案；不得仅按 `.md` 后缀判轻量。CI 使用更保守的路径白名单，见 [ci.md](ci.md)。

| 改动 | 必要检查 | 独立验证与证据 |
| --- | --- | --- |
| 纯文案、排版或导航；不改变游戏、配置、工具/CI、验收契约或授权边界 | `node tools/check.mjs --scope docs`，阅读对应报告与链接错误 | 无需独立 Godot 复验；不能把 docs pass 写成 game pass |
| 已认可的配置/场景调整，或局部游戏行为修改 | docs；相关配置的真实保存、重新加载、入树、行为与 reset；原失败项/受影响机制；最终完整 `--scope game` | 保留独立设计期望、机制和原失败。同一源码已经完整验收后，不为无变化的文字收尾重复 game |
| 公共依赖、动作/效果生命周期、signal 再入，或测试工具/CI/验收契约修改 | docs；相关 Node 回归；工具/环境契约变化时 toolchain；原失败项/受影响机制；完整 game | 公共契约和检测能力须有真实针对性反例，交付前对冻结源码独立验证；不得把故意失败 fixture 当游戏通过 |

新 worktree 的工具准备仍须证明环境可用；相同已验证工具/配置可按 [worktrees.md](worktrees.md) 复用，不因每次改文案重复引擎自检。配置或依赖身份改变、先前检查失败、引入新改动或有未解决疑点时，重新执行相应检查。

组合源码完成一次本轮必要 game 检查后，仅文案收尾执行 docs 并核对游戏/测试源码身份；不重复未变化的完整游戏验证。文字若影响验收/工具契约则按第三行处理。最终 PR head 的适用 CI、原始报告、实际配置和哈希仍要核对，main push 再验证实际合并提交；不能把旧报告改写成新 head 的报告。

本次不新增调参探索模式，也不改变 [设计基线](design-baselines.md) 的正式验收流程。新的明确用户指令可以批准基线变更；长跳大于短跳等机制关系不能代替已采纳的具体尺度/数值约束。

## 并行验收

可维护性改动同时执行 [工程评审](engineering-practices.md) 的配置、依赖、生命周期和同步再入反例；原失败必须可读，不能只增加证明现有实现的正向测试。临时 HUD 保留原回归并标注债务，不据当前 UI 测试通过宣称正式架构完成。

写入/运行开发任务按 [worktrees.md](worktrees.md) 使用独立 checkout。需要引擎或工具验证时，工具准备和单测入口为 `node tools/prepare-worktree.mjs --tools-from <同仓库已验证目录>` 与 `node --test tools/test-toolchain.mjs tools/test-worktree.mjs tools/test-worktree-runtime.mjs tools/test-game-failures.mjs`；随后运行既有 scope 验收。所有报告、快照、设置和引擎日志留在实际 checkout，交接写明绝对目录与 run_id。不要跨目录读取 latest.json，也不把依赖准备或故意失败 fixture 计为真实游戏通过。共享集成操作另用公共锁。

## 执行与交接

1. 读 `AGENTS.md`、工具配置、`artifacts/test-runs/latest.json` 及其指向的报告。
2. 检查报告的范围、工作目录、工具版本、开始时间及对应代码状态，避免把旧结果当作本轮证据。
3. 从项目根目录运行入口。每个检查必须有有限超时，执行结束后读取报告及失败日志，不能只看进程退出码。
4. 按统一错误流程修复并复跑；保留每轮报告和日志，不覆盖失败证据。
5. 输出本轮 `run_id`、状态、报告路径、开放错误及未完成检查。测试子 agent 和主 agent 使用同一协议；主 agent 核查交付结论。

## 机器报告约定

- 每轮报告：`artifacts/test-runs/<run_id>/report.json`。
- 最新指针：`artifacts/test-runs/latest.json`，提供运行编号与报告位置；指针本身不是完整测试证据。
- 状态只使用 `pass`、`fail`、`timeout`、`blocked`：分别表示预期检查通过、结果不符合预期、超时、无法完成执行条件。报告须说明总体状态所对应的原因。
- 报告至少含协议版本、`run_id`、范围、工作目录、开始时间、耗时、工具路径与版本、执行命令、总体状态及检查列表。
- 每项检查至少含稳定标识、目的、预期结果、实际结果、状态、退出码、日志路径及失败上下文。未启动的检查退出码可为空，但必须记录原因。
- 失败上下文应定位到检查、报错及触发条件，必要时关联错误编号、代码版本、重试与上一轮运行。没有 Git 信息时明确标为不可用。
- 原始日志与结构化结果一同保留，日志路径须能从报告定位。报告缺字段、无法解析或找不到关键证据不得算通过。历史长期归档与本轮完整报告职责见下节；摘要不能冒充原始报告。
- game/toolchain 哈希覆盖实际源码与受版本控制的工作流、安装脚本、配置读取器、源配置、包锁及测试协议；实际配置另在 `toolchain_config` 记录路径、SHA-256、完整 manifest。CI 派生配置不假装存在于 Git HEAD。docs 哈希覆盖当前 Markdown 与文档检查入口、实现和回归脚本，记录 Node 版本，不要求 Godot/Python 配置。
- PR 验收可能运行 GitHub 的合并引用。以 CI 上下文分别核对 PR head/base、GITHUB_SHA、报告的实际 commit；最新 head 上所有适用检查通过才具备合并证据。
- 必须核对预期检查是否全部执行；空检查列表、意外跳过、未完成运行不能得到 `pass`。

## 关键证据的长期归档

CI 原始 artifacts 请求保留 90 天，实际期限受仓库/组织策略上限约束；期限内可下载完整报告、日志、配置和源码快照。可从 Git 和固定工具重新运行，与能够取回当时的原始失败证据，是两个结论。

重要公共契约缺陷、测试检测能力缺陷及其修复，将精简证据归档到受版本控制的 `docs/evidence/<问题或PR>/`：至少说明原失败与修复/交付的源码身份、运行入口、具体反例和结果，保留必要原始日志或明确标为摘录的片段及原文件 SHA-256/行号，并提供对应 CI 链接。报告摘要必须标明摘要、原报告 SHA-256 和保留范围，不称为完整原报告。摘要里的通过结果不能代替本轮完整验收。

普通运行继续在本任务 ignored artifacts 保存完整报告/快照，收尾由任务所有者确认需要保留的失败、配置与交接证据后整理；长期归档不要求提交每轮完整 game-project 或 vendor。只归档/整理当前任务自己的文件，不删除其他会话的 worktree、报告、未提交文件或未知 stash。现行目录与原始报告协议不变。

## 配置保存与设计变更

配置链变更遵循 [inspector-configuration.md](inspector-configuration.md)，覆盖保存、无缓存重载、入树、实际行为与重置。受击保护四项回归与现有默认窗口验证同时保留。

[设计基线流程](design-baselines.md) 将尺度/布局的独立预期保存在 `tests/baselines/design-v1.json`；用户的明确新指令足以授权相应更新，无需重复批准。未认可的新设计先保留失败并澄清，不从被测实现生成期望，不为通过测试回退已认可设计。原失败、基线变更出处和机制回归结果须在交接中可读取。

`report.failure_classification` 读取 `checks[id=junit].actual.junit` 的原始失败消息及 `gut_log_path` 的实际 `[Failed]` 断言（去 ANSI、按 suite/name 对应、排除 summary 重复），以 `DESIGN_BASELINE:` / `MECHANISM:` 标签生成诊断：`counts` 与 `cases` 的类别为 `design_baseline`、`mechanism`、`mixed`、`unclassified`。标签覆盖当前尺度/地图用例；其他未标记用例或引擎错误保留未分类，不能靠名称猜原因。GUT 9.7.1 的 XML 可能只保留同一 case 的首条失败，原始日志补充其余断言；`cases[].evidence_coverage = junit_only` 表示分类可能不完整，不能据此排除机制故障。成功报告 counts 全零；没有可读 XML 时为 `status: unavailable`，须检查失败项与日志，不能视为零失败。

分类不修改原始 JUnit、退出码或验收规则；设计失败也阻止交付，标签本身不代表用户认可或已查明原因。Node 回归涵盖标签、混合/无标签错误、GUT 布尔断言的无冒号 `[Failed]`、跳过、缺失报告和证据不变性，完整引擎仍按相同入口独立执行。

## 引入测试环境的自检

| 用例 | 判定 |
| --- | --- |
| 成功用例 | 指定检查执行完成，预期结果与实际结果一致，报告及日志可读取 |
| 故意失败用例 | 捕获指定失败及上下文，底层失败保留在报告，不能吞掉失败或误报成功 |
| 超时用例 | 在约定时间后终止受控测试进程，保留超时原因与日志，不能无限等待或误报成功 |
| 报告读取 | 另一 agent 能按文档找到、解析报告，定位日志，并复跑相关检查 |

故意失败与超时用例测试的是检测能力：捕获符合预期时，自检项可以通过；底层实际失败/超时及退出码仍须原样记录。正常验收中的非预期失败或超时不能因此视为通过。

## 游戏范围的固定契约

- `tests/manifest.json` 提供非空、唯一的预期测试名称；`tests/game/` 存放 GUT 测试。发现的测试名称、JUnit 实际执行名称和契约必须完全匹配。新增或移除测试时同一次改动维护契约，不接受自动减少预期来掩盖失败。
- 入口将本轮 `project.godot` 与 `shared/combat/skills/player/world/ui/localization/assets/tests` 复制到报告目录的 `game-project/`；固定 GUT 只复制到该快照的 `addons/gut/`。不提交插件本体，不修改正式游戏目录的插件配置。完整快照和 source SHA-256 允许另一 agent 检查报告对应的代码。
- 每轮验证引擎、Python、linter 和 formatter 的固定版本；检查 GUT 元数据。真实自有 GDScript 执行 lint 与 format check，排除 vendor 和历史 artifacts。
- 真实项目完成 headless import、GUT 自动测试、独立 JUnit 读取和主场景 120 帧运行。每个外部进程均有有限超时。引擎日志有脚本/解析/运行错误时，即使退出码为 0 也判失败。
- 引擎子进程显式提供 `ASTRA_SETTINGS_PATH=<本轮目录>/settings.cfg`，原始日志与 actual 保留该环境覆盖；不改 HOME，不写玩家配置。`localization-restart-write/read` 使用同一独立 language-restart.cfg，在两个实际引擎进程中保存日文并恢复，保留 PID、恢复前语言与译文。第二项必须读取第一项写出的文件，不能在读取进程重新设置语言充当恢复。
- 三语 UI/字体/布局检查在真实场景 GUT 用例中执行。非 headless 画面另用 `tests/probes/localization_visual.gd` 保存三语 HUD、菜单和帮助共九张真实 viewport 图及 report.json；它是额外图形证据，不计作 GUT assertions 或 headless 成功。原始日志也必须检查。
- 图形复跑 argv：`<toolchain godot path> --path <真实工程或对应快照> --script res://tests/probes/localization_visual.gd -- <绝对输出目录>`，并单独设置 `ASTRA_SETTINGS_PATH=<输出目录>/settings.cfg`。使用已导入的工程，设置有限进程超时，stdout/stderr/exit_code 保存在 capture.log；查看全部 PNG 后另记录审核结论，capture 的 pass 只证明截图保存完成。
- 尺度图形证据可使用相同方式运行 `tests/probes/scale_movement_visual.gd`，保存静止、短跳顶点附近、长跳顶点附近三张 viewport，并记录逐帧峰高；它不替代 GUT 的碰撞/输入验收或用户手感审核。
- JUnit 判读要求每个预期 case 都有断言，且 failures/errors/skipped 为 0；执行失败仍尝试读取现有 XML，保留实际失败上下文。缺文件、空测试、跳过或名称缺失不算通过。
- 行为覆盖与独立限制见 [tests/README.md](../tests/README.md)。第一版技术数值是暂定验收基线，玩法调整时必须说明为什么改变预期，而不能仅按实现自动改测试。
- `latest.json` 可能指向工具链或游戏范围。报告 `scope` 不等于 `game` 时，不可据此声明首版已通过；也不能将工具 fixture 结果计为游戏测试。
- game 验收优先由测试子 agent 执行与首次判读；主 agent 必须读取完整报告、JUnit 与失败日志，承担交付结论。docs 的独立验证边界按上面的检查分级执行；用户主动反馈仍是独立渠道。

## 失败、修复与反馈

- 失败先查 [errors/README.md](errors/README.md) 及历史记录，按报错、触发条件、版本和位置确认是否复现。
- 先检查依赖与环境，再定位资源/配置、代码或测试原因。每次修复记录假设、改动、复跑命令与前后结果。
- 修复后先复跑原失败项，再跑受影响回归，最后完成本轮必需检查；报错文本变化不能单独证明修复成功。
- 自动测试记录 `channel: automated_test`；用户主动反馈记录 `channel: user_feedback`，保留原意、场景与复现条件。不要求用户等 agent 提问才反馈。
- 用户手感反馈由用户判断；自动测试仅报告已执行的技术验证。无法自动复现的用户问题仍须保留，不能因测试通过自动关闭。

## 心容器版本补充验收

心系统采用 `docs/heart-health-v5.md` 中用户已采纳的验收：半心步进、3/10/3 容器、普攻0.5/火球1/敌击0.5、自伤友伤完整心伤害、严格数值校验、稻草人反复回满与统计保留；旧减伤断言由对应新规则替换，其余生命/技能/语言/尺度回归保留。

`tests/probes/heart_health_visual.gd` 是本版本额外图形入口，使用上面的同一 argv/独立 settings/有限超时协议，从最终通过的已导入快照捕获三语完整/半颗/空心、敌人死亡、主角击倒、稻草人受伤与回满。保存原始日志、源码哈希和 report.json，打开全部 PNG 后另写审核结论；截图保存成功不等于视觉审核或用户试玩通过。旧 `health_combat_visual.gd` 也已迁移到心单位，不使用旧25/40等生命版数值作为本轮验收。
