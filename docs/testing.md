# Agent 测试协议

## 范围与入口

- 范围由命令参数确定：`toolchain` 验证测试工具自身；`game` 验证当前真实项目及既有回归，均不能证明手感已获用户认可。
- 工作目录：项目根目录，即 `AGENTS.md` 所在目录；尚未建立 Git 仓库时同样适用。
- 单一入口：`node tools/check.mjs --scope toolchain` 或 `node tools/check.mjs --scope game`。未知范围和参数必须拒绝。
- 路径、固定版本、来源：`tools/toolchain.json`。工具本体在 `.tools/`，不提交。
- 新机器/CI 先执行 `node tools/bootstrap.mjs`；按输出配置路径设置 `ASTRA_TOOLCHAIN_CONFIG`。安装与验收分开，两个 scope 共用 `tools/toolchain-config.mjs`。CI 具体触发、证据与合并门槛见 [ci.md](ci.md)。
- 具体安装与测试状态：见最新报告；未执行或报告缺失时为未验证。
- 新建或修改测试流程后立即执行；每次准备验收前执行本轮必要检查。
- 地图版完整 GUT 进程预算为 150 秒。新增真实物理用例使原 90 秒首轮真实超时，证据保留在 ERR-20261002-MAP-VALIDATION.md；提高有限预算不改变检查集合、断言、超时失败和原始 XML 要求。
- 本机已验证的执行方式：在获准的沙箱外环境运行相同入口。沙箱内 Godot 用户缓存与 Python fixture 文件访问曾失败，见 [ENV-0004](errors/ENV-0004.md)。新 agent 应先读取该记录；权限失败时先核对执行环境，保持测试预期及 `HOME` 不变。

## 并行验收

写入/运行开发任务按 [worktrees.md](worktrees.md) 使用独立 checkout。工具准备和单测入口为 `node tools/prepare-worktree.mjs --tools-from <同仓库已验证目录>` 与 `node --test tools/test-toolchain.mjs tools/test-worktree.mjs tools/test-worktree-runtime.mjs`；随后运行既有 scope 验收。所有报告、快照、设置和引擎日志留在实际 checkout，交接写明绝对目录与 run_id。不要跨目录读取 latest.json，也不把依赖准备或故意失败 fixture 计为真实游戏通过。共享集成操作另用公共锁。

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
- 原始日志与结构化结果一同保留，日志路径须能从报告定位。报告缺字段、无法解析或找不到关键证据不得算通过。
- 哈希覆盖实际源码与受版本控制的工作流、安装脚本、配置读取器、源配置、包锁及测试协议；实际配置另在 `toolchain_config` 记录路径、SHA-256、完整 manifest。CI 派生配置不假装存在于 Git HEAD。
- PR 验收可能运行 GitHub 的合并引用。以 CI 上下文分别核对 PR head/base、GITHUB_SHA、报告的实际 commit；最新 head 上所有必要检查通过才具备合并证据。
- 必须核对预期检查是否全部执行；空检查列表、意外跳过、未完成运行不能得到 `pass`。

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
- 测试子 agent 负责实际执行与首次判读；主 agent 必须读取完整报告、JUnit 与失败日志，承担交付结论。用户主动反馈仍是独立渠道。

## 失败、修复与反馈

- 失败先查 [errors/README.md](errors/README.md) 及历史记录，按报错、触发条件、版本和位置确认是否复现。
- 先检查依赖与环境，再定位资源/配置、代码或测试原因。每次修复记录假设、改动、复跑命令与前后结果。
- 修复后先复跑原失败项，再跑受影响回归，最后完成本轮必需检查；报错文本变化不能单独证明修复成功。
- 自动测试记录 `channel: automated_test`；用户主动反馈记录 `channel: user_feedback`，保留原意、场景与复现条件。不要求用户等 agent 提问才反馈。
- 用户手感反馈由用户判断；自动测试仅报告已执行的技术验证。无法自动复现的用户问题仍须保留，不能因测试通过自动关闭。

## 心容器版本补充验收

心系统采用 `docs/heart-health-v5.md` 中用户已采纳的验收：半心步进、3/10/3 容器、普攻0.5/火球1/敌击0.5、自伤友伤完整心伤害、严格数值校验、稻草人反复回满与统计保留；旧减伤断言由对应新规则替换，其余生命/技能/语言/尺度回归保留。

`tests/probes/heart_health_visual.gd` 是本版本额外图形入口，使用上面的同一 argv/独立 settings/有限超时协议，从最终通过的已导入快照捕获三语完整/半颗/空心、敌人死亡、主角击倒、稻草人受伤与回满。保存原始日志、源码哈希和 report.json，打开全部 PNG 后另写审核结论；截图保存成功不等于视觉审核或用户试玩通过。旧 `health_combat_visual.gd` 也已迁移到心单位，不使用旧25/40等生命版数值作为本轮验收。

## 创作交接与设计基线

人类调参不能由旧断言自动否决；机制回归和已采纳设计基线分开维护，见 [design-baselines.md](design-baselines.md)。测试预期独立于业务配置，不自动回读业务属性充当期望；基线有意变更必须保留原失败、用户决定、旧/新值与回归影响。

`node --test tools/test-toolchain.mjs tools/test-worktree.mjs tools/test-worktree-runtime.mjs tools/test-human-workspace.mjs` 是工作流验收入口，纳入 CI。工作区测试使用真实临时 Git、隔离的进程观测夹具；真实桌面运行器另记实际进程、阻断/启动结果，不将模拟列表称为真实编辑器关闭。`play.mjs` 日志显示项目绝对路径；资源/交接/同步操作遇到不可观察状态停止。人类手感反馈独立保留。
