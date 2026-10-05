# 多会话隔离开发

## 决策与适用范围

自 2026-10-02 起，本项目所有会写代码、场景、配置或文档的开发会话（含写文件的子 agent）必须使用自己的 Git worktree 和唯一功能分支。原目录保留 `main`，供用户试玩和串行集成；只读调查可在原目录进行。一个会话内部按依赖顺序连续工作可以复用自己的 worktree。独立测试 agent 使用自己的 checkout 或已经冻结且明确交接的快照，不和开发者同时改同一个目录。

同一目录仅有一个当前检出分支，切分支会改变其中的文件。Worktree 提供独立文件、index 和 HEAD；Git 对象、本地分支名、远端 refs、stash 和公共配置仍共享。因此多个不同分支可同时开发；同一分支不可同时检出，也不能使用 force 绕过保护。依据：[Git 官方文档](https://git-scm.com/docs/git-worktree)。无需为每项任务完整克隆；若将来需要独立 Git 配置/对象库或不可信环境，再用独立 clone/容器。

隔离工作区不会消除同一文件的合并冲突，也不会隔离 CPU、内存、默认网络端口或外部服务。开始时明确模块、接口和文件责任；合并后按实际组合复验。当前没有开发服务器端口；以后新增服务必须分配每会话端口和数据库。

## 启动一个会话

推荐在 Codex 新会话选择 **Worktree**，起点选择最新 `main`；或让 agent 创建并附加 managed worktree。以工具实际返回的绝对目录为准，所有编辑、Godot 编辑器、测试、commit/push 都在那里执行。默认可能为 detached HEAD，开发前在该目录创建唯一功能分支：Codex 用 `codex/<任务>-<短会话标识>`，Claude 用 `claude/<任务>-<短会话标识>`。已附加且适合当前任务的 worktree 优先复用。不要仅新开 Local 会话后继续写原目录，也不要让两个写入会话共用永久 worktree。操作入口依据：[OpenAI 官方 Worktrees 文档](https://learn.chatgpt.com/docs/environments/git-worktrees)。

CLI 也可使用原生 Git（示例目录和分支须替换为本会话自己的唯一值）：

```sh
git -C /Users/hanguo/Documents/ChatGPT/Godot-project fetch origin
# 读取 origin/main 的完整 SHA，记录为本轮 base；不用共享 FETCH_HEAD。
git -C /Users/hanguo/Documents/ChatGPT/Godot-project rev-parse origin/main
git -C /Users/hanguo/Documents/ChatGPT/Godot-project worktree add --no-track -b codex/my-task-abc123 /private/tmp/astra-my-task-abc123 <刚核实的完整SHA>
cd /private/tmp/astra-my-task-abc123
git status --short --branch
git rev-parse --show-toplevel HEAD
git worktree list --porcelain
```

`--no-track` 避免新功能分支误把 origin/main 当作 push upstream；首次推送明确 `git push -u origin <自己的分支>`。续做已有分支先查 worktree 列表，使用其所属目录；不把它强行检出到第二处。不要自动迁移、stash、reset 或覆盖其他会话的未提交内容。

## 准备工具与运行环境

`.tools/`、`.godot/` 和 `artifacts/` 都被 Git 忽略，新 checkout 不自带它们。每个 worktree 各自保留可写配置、缓存、设置、快照、日志和报告。禁止把整个 `.tools`、`.godot`、`artifacts` 软链接到别人的目录，也不把它们列入 `.worktreeinclude` 批量复制。

同一版本的本机工具可以只读借用：

```sh
node tools/prepare-worktree.mjs --tools-from /Users/hanguo/Documents/ChatGPT/Godot-project
node --test tools/test-toolchain.mjs tools/test-worktree.mjs tools/test-worktree-runtime.mjs tools/test-game-failures.mjs
node tools/check.mjs --scope toolchain
node tools/check.mjs --scope game
node tools/play.mjs
node tools/play.mjs --editor
```

准备器仅适用于同一 Git 仓库的 linked checkout，检查双方版本契约与工具路径存在，生成本目录忽略的 `.tools/worktree/toolchain.json` 和唯一 `artifacts/worktree-setup/<run_id>/report.json`。工具路径转为绝对路径；检查入口和 launcher 默认加载该派生配置。显式 `ASTRA_TOOLCHAIN_CONFIG` 优先；配置存在但损坏或显式路径无效会失败，不悄悄回退。准备不等于工具可执行/版本已验证；首次用于引擎/工具验收前必须运行 toolchain 检查。纯文案任务按 [检查分级](testing.md#按影响选择检查) 运行 docs，不为文案重复准备 Godot。

相同准备可幂等复用；不同内容不可覆盖旧配置。变更前停止本 checkout 的引擎/测试，保存原配置与报告，再移走本 checkout 的派生配置，重新准备并验收。借用期间提供方工具必须保持稳定，不能重装、删改或移动；需要升级、提供方不可用或全新机器时，在自己的 worktree 独立安装：

```sh
node tools/bootstrap.mjs
ASTRA_TOOLCHAIN_CONFIG=.tools/ci/toolchain.json node tools/check.mjs --scope toolchain
ASTRA_TOOLCHAIN_CONFIG=.tools/ci/toolchain.json node tools/check.mjs --scope game
ASTRA_TOOLCHAIN_CONFIG=.tools/ci/toolchain.json node tools/play.mjs --editor
```

bootstrap 始终从 tracked `tools/toolchain.json` 固定版本安装到当前 checkout 的 `.tools/ci`，不重装提供方工具。同一个 checkout 不并发 bootstrap。当前 CI 配置没有 gh；可从已经核实的主目录 gh 绝对路径运行 GitHub 操作，或另行准备并验证 gh，禁止借此修改共享认证配置。

launcher 在 linked checkout 自动使用 `.tools/play/settings.cfg`，编辑器入口继承同一环境；每次日志位于本目录唯一 `artifacts/play/<run_id>/godot.log`。显式 ASTRA_SETTINGS_PATH 优先。主目录试玩沿用原 user:// 设置；同一 worktree 同时试玩/编辑会共享该 checkout 的试玩设置，需要同时启动时为每进程显式给不同路径。原生项目管理器直接打开不会自动获得此环境，开发请使用 launcher。

game/toolchain 验收每轮生成独立快照和 UUID 报告，game 显式提供本轮隔离的 ASTRA_SETTINGS_PATH；docs 只生成文档检查报告与对应源码身份，不启动引擎。交接必须写 **checkout 绝对路径、commit/源码哈希、scope、run_id、report_path**；latest.json 只代表该 checkout 最后结束的一次运行，不能拿另一目录或旧轮次的绿灯作本轮证据。运行引擎保留 HOME，不改全局用户配置。

## 合并与共享状态

每个会话只操作自己的分支和普通 push；不重写别人的 refs、不应用/删除未知 stash、不修改公共 Git/credential 配置。当前认证 helper 指向原目录 gh，使用既有 keyring 即可；不要在各 worktree 重跑 auth setup-git。Fetch 会更新共享远端 refs，但不会切换其他 checkout；依赖起点/验收基线须固定为明确 SHA。

各任务可独立提交 PR；合并、更新本地 main 统一通过公共集成锁，且由当次持锁者串行执行。锁位于 Git common-dir 的 `astra-integration.lock`，因此所有 worktree 竞争同一个锁。单条命令形式：

```sh
node tools/with-integration-lock.mjs -- node /private/tmp/astra-integrate-this-task.mjs
```

该脚本路径为本轮自编集成脚本的示例，仓库不提供绕过验收的自动合并脚本。脚本不得启动后台 Git/gh；需包含整个序列：取得锁后重新读取最新 base/head、检查与冲突状态，核查对应 CI 原始 artifact/源码哈希；用 `--match-head-commit <已验收SHA>` 和 Merge commit 合并；读取远端实际 merge commit；fetch；确认主目录仍在 main、工作区干净且无人编辑/运行后，在主目录 `git merge --ff-only origin/main`；核对 ancestry、tree 和远端 main 检查。不要只包住 merge 命令就释放锁后再同步。目标 base 改变导致验证组合变化时，先更新/复验再合并；合并后一轮从新 main 起步，正在工作的其他分支不自动切换或 reset。

竞争者退出 73 并打印持锁信息；等待持锁者结束后重试。普通结束和子进程失败都会释放自身锁并传播退出码；SIGINT/SIGTERM 取消终止整组子孙进程，确认结束后才释放，无法确认时留锁。强制结束/系统崩溃可能遗留锁；先读取 owner.json、核实 wrapper PID、其子孙进程/对应命令及工作区是否仍在运行，协调确认后才清理。工具不按时间擅自抢锁，不自动删除未知锁。此机制依赖各会话遵守入口，不能阻止手工绕过。

锁不代表主目录可随时被改动。主目录脏、被其他会话使用或当前分支不为 main 时，保留远端已合并结果，延期本地同步并明确报告原因；不能代替用户 stash/reset/switch。

## 结束与接续

PR 合并、远端结果和安全同步核实后，按 [关键证据归档规则](testing.md#关键证据的长期归档) 保存需要交接的报告/设置。Managed worktree 使用 Codex archive_worktree 归档并保留可恢复快照；原生 worktree 使用 Git remove 前核查清洁状态和忽略文件。归档/删除可能不保留 ignored 文件，必须先复制必要证据。只清理当前任务自己创建且已无用途的目录，不清理历史 worktree、未知 stash 或未推送内容，不强制删除分支。

后续会话仍需读取 AGENTS、相关模块和最新状态，文档承载决策，聊天不会因为共享 Git 自动继承。当前机制的实际验证、PR 与本地同步记录见 [status.md](status.md)。
