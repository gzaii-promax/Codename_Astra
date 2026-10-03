# 人类创作、AI 开发与集成交接

## 职责与目录

本协议约束任务和文件归属，不绑定某个 agent、历史线程或指定 Coding Agent。任何遵守项目规则的 AI 会话均可承担开发、测试、审阅或集成。人类负责玩法、手感、调参、关卡与正式素材；AI 负责工程与验证；集成者负责证据审查和受保护的 Git 操作。重要规则改变仍由用户决定。

| 工作区 | 分支 / 用途 | 写入边界 |
| --- | --- | --- |
| 原目录 `Godot-project` | `main`，集成与用户试玩 | 不作为场景创作区；原有未提交/未保存工作保留，未安全交接前不更新 |
| 固定 `Godot-project-human`（原目录的同级目录） | `codex/human-editing`，长期人类创作 | 人类通过 Godot 修改资源；AI 不直接改其中源码/场景。冻结交接后可由集成者代办精确快照的 Git 提交，不能借此改文件 |
| 各任务独立 worktree | 唯一 `codex/<任务>-<会话>` | AI 代码与资源实现、测试、PR；写文件子 agent 也独立 |
| 验收快照 | `artifacts/test-runs/<run_id>/game-project` | 只验证，不继续开发，不当作人类工作区 |

固定目录只登记一次，记录在 Git common-dir 的 `astra-workspaces/human.json`。所有 linked checkout 共用登记和占用记录；不复制整套 Git 仓库，不嵌套工作树。其他机器可选自己的绝对同级路径，但同一仓库只登记一个人类工作区。工具不删除/替换已有路径或未登记的同名分支。建立失败若 Git 已创建 checkout、登记未完成，保留现场，由集成者核对 `git worktree list --porcelain` 后修复登记，禁止再次强行创建/删除。

## 第一次进入与现有修改迁移

人类工作区必须从已验收且包含本轮守卫的完整 commit SHA 建立。草稿阶段可以使用该 PR 的已验证 head；这不意味着该 PR 已合并 main。由 AI 在自己的工作区执行：

```sh
node tools/workspace.mjs setup-human --path /Users/hanguo/Documents/ChatGPT/Godot-project-human --base <已验证的40位commitSHA>
```

该入口使用现有公共集成锁。随后在人类目录准备并验证本机工具：

```sh
cd /Users/hanguo/Documents/ChatGPT/Godot-project-human
node tools/prepare-worktree.mjs --tools-from /Users/hanguo/Documents/ChatGPT/Godot-project
node tools/check.mjs --scope toolchain
node tools/play.mjs --editor
```

打开前先保存并关闭目前的 Godot 编辑器。不要从项目管理器双击旧主目录继续创作。原目录已有修改不会自动复制、恢复或 stash。用户先保存、查看差异、说明哪些修改属于待移交内容；AI 保留原件，逐文件审查，之后在自己的工作区接收并验证。未保存状态不能由 Git diff 或磁盘哈希证明，不能宣称工具已读取内存场景。

## 单一写入者与运行占用

每个逻辑 `.tscn/.tres` 路径同时只有一个写入者，即使在不同 worktree 中。Godot 编辑器可打开任意场景，当前采用保守的全资源独占 `*`，存续到整个引擎进程组退出。人类编辑器打开时，AI 仍可在自己的 checkout 做纯代码工作、只读审阅和快照测试，但不能写资源。将来确有需要可设计更细的编辑器文件限制，本轮没有假装实现按 tab 强制权限。

AI 磁盘修改资源必须通过有时限/明确退出的写入命令持有声明路径：

```sh
node tools/workspace.mjs edit --files player/player_character.tscn skills/definitions/fireball.tres -- python3 /absolute/task-script.py
```

新建、删除、重命名也属写入；重命名同时声明原路径与目标路径。命令必须仅写声明的资源，并在自己目录编辑。工具规范化路径，拒绝逃逸、符号链接及非资源路径。原目录与人类目录拒绝 AI `edit`。纯代码仍按每任务 checkout 唯一写入会话执行。

所有 `play.mjs` 启动登记 checkout 活动；同目录另一启动/同步/交接拒绝。`--editor` 拒绝原目录 main，并取得全资源占用；普通试玩使用无资源写权限的活动记录。启动失败、正常退出、SIGINT/SIGTERM 传播退出码；先确认整组子进程结束再释放记录，无法确认则留占用。F5/F6 启动的游戏随编辑器进程组受保护；不要让外部子进程自行脱离该组。

资源写入、交接与同步还保守检查本机所有 Godot 进程，包含未登记或不知来源的编辑器/运行器；存在进程或 `ps` 失败时阻断，不擅自终止。因而 headless 验收正在运行时，需要等待它结束后再编辑资源。测试夹具的进程列表与真实桌面分开模拟；夹具绿灯不能说明真实编辑器已关闭。

这是合规入口的工程守卫，不是操作系统沙箱：无法阻止手工 Git、直接文件写入、改名的引擎或原生项目管理器绕过。不得因存在守卫就假设绕过操作安全。无法确定状态时保留文件，停止同步。

## 保存、交接与接收

1. 人类保存全部场景/资源，确认磁盘内容，关闭编辑器及其运行实例。明确确认保存/关闭后才使用以下标志；AI 不可由无进程自行推断此前所有内存修改已保存。
2. 查看 `git status --short` 与 `git diff HEAD`（包含暂存改动）；确认新文件、删除、重命名和 project 配置均属于交接范围。
3. 在人类目录执行 `node tools/workspace.mjs handoff --saved --closed`。入口取得全资源占用，检查进程，保存 HEAD、分支、index 指纹、完整 Git 状态和非忽略文件哈希；创建独立 `artifacts/handoffs/<id>/report.json`、`tracked.diff` 与 `files/` 文件副本。删除文件以状态/基线差异记录；忽略的依赖、缓存、设置和旧报告不复制。副本保留后可供另一个 AI 阅读，无需在活目录修改。
4. AI 在自己的任务目录运行 `node tools/workspace.mjs check-handoff --report /absolute/human/artifacts/handoffs/<id>/report.json`。它同时冻结双方活动、验证人类快照未漂移，按共同 merge-base 比较提交、暂存/未暂存和新文件，遇到同文件改动阻断自动接收。路径使用 NUL 分隔；不会因空格/换行丢失文件。冲突必须审阅并记录采用的版本，不能“让测试绿”而覆盖人类改动。
5. 审阅后在 AI worktree 仅从已哈希清单接收已冻结内容（包含新文件和删除），不得盲目复制 files/ 中额外未列文件，声明资源写入路径；提交模块文档/设计基线变化，运行必要验收，再创建/更新 PR。任何交接后修改都要新交接；旧报告不再证明新内容。

Git 历史需要保留人类分支的原提交：如人类尚未提交，可由集成者在公共集成锁内，通过 `workspace-state.mjs` 的 `withLease(human,['*'],'handoff-review',…)`、`verifyHandoff(report,record.token)` 复核后代办 `git add`/`commit` 精确已审阅的文件，提交前枚举整个 cached diff（NUL分隔），确认所有已暂存项均在用户批准路径内；出现额外暂存项立即停止，不擅自 unstage，也不允许普通 commit 夹带。前后检查源码哈希不变，再产生新交接报告；只写 index/提交元数据，禁止夹带源码修改。先在 AI worktree 合入该原始人类提交，再补工程修正，避免 cherry-pick 产生另一套身份后使固定人类分支永远无法快进。此操作不授权自动提交其他未交接文件。

手感反馈仍独立于自动测试。有意调参和基线批准流程见 [design-baselines.md](design-baselines.md)。

## 同步、异常与恢复

PR 合并与主目录同步必须由 [公共集成锁](worktrees.md) 包住完整证据核对/合并/同步。持锁脚本最后调用受控同步入口：

```sh
node /absolute/verified/tools/workspace.mjs sync --root /absolute/target --revision <已核实SHA> --saved --closed
```

只允许原目录 `main` 或登记的人类分支；工具验证调用者在持锁进程树中，检查活动/资源记录、Godot 进程、Git 干净状态，然后仅 `merge --ff-only`。它不执行 fetch、PR 合并或验收，不能单独替代完整集成脚本。主目录或人类目录脏、存在编辑器/租约、缺少明确关闭确认、扫描失败、历史分歧，均停止并保留 HEAD/文件。远端已合并则报告本地同步延期。

人类目录不随每个 main 更新自动跳分支。保存交接、审阅并完成精确提交后，若其 HEAD 为目标祖先才可安全快进。若已分歧，在独立 AI worktree 从人类 HEAD 建临时分支，审阅合并目标 main、解决冲突并复验，保留双方历史；经授权后把固定人类分支快进到该组合提交。未经审阅不能 rebase/reset/stash 绕过分歧。手工解决资源冲突时只有指定任务持有相关资源归属，双方停写。

占用存于 `astra-workspaces/claims/`，元数据更新使用短锁 `gate/`。工具不按年龄回收；未知/残缺/死 PID 记录均阻断。崩溃后先保存现场、读 token/PID/root/kind/files，核实 wrapper 与全部子孙已退出、Godot 已关闭，协调相关职责后，仅清理已证明失效的那条记录；不得抢未知锁。进程无法确认结束时继续保留，记录公共错误。

退出时正常关闭编辑器即可释放占用。固定人类工作区长期保留，不作为任务收尾归档对象。AI 仅归档自己创建且已无用途的工作树，先保存忽略证据。草稿未合并或仍有交接用途的工作树本轮保留。

## 验收与当前边界

`tools/test-human-workspace.mjs` 用真实临时 Git 仓库覆盖争用、代码并发、未知记录、路径/符号链接、退出/取消、保存确认、索引与磁盘漂移、已提交同文件冲突、脏 main 保留及干净/分歧快进。进程列表用受控夹具覆盖成功、故意失败和不可观察情况；真实桌面进程检查另列报告。沿用原启动/集成锁和 toolchain 成功/失败/超时/报告协议；不把故意阻断计为真实同步通过。

每 checkout 独立 `.godot`、`.tools` 可写配置和 artifacts；固定工具只读借用。当前 `ASTRA_SETTINGS_PATH` 只隔离语言设置文件，**不代表整个 `user://` 隔离**。其余游戏状态仅内存，没有磁盘存档；以后新增持久化必须单独设计每工作区命名空间。原目录试玩沿用已有设置，人类/AI linked checkout 使用自己的 `.tools/play/settings.cfg`。原生管理器打开不继承 launcher 环境，不能作为安全创作入口。
