# GitHub 与分支交接

## 授权与职责

用户已给予持续提交与合并授权：在已授权开发范围内，必要验收通过后可 commit、普通 push、创建/更新 PR，并自行合并，无须再次索取提交/合并许可。授权不扩大功能或重要架构决定范围，不代表用户已验收手感。2026-10-02 明确整合授权已取代旧多语言/生命等 draft-only 例外；原交付快照见 [git-history.md](git-history.md)。

仓库为私有 `gzaii-promax/Codename_Astra`，origin 为 `https://github.com/gzaii-promax/Codename_Astra.git`，默认分支 main。实际权限、refs 和 PR 状态须本轮读取，不能从旧文档推断。

## 每轮固定流程

1. 读取 AGENTS、近期提交、相关模块、[当前状态](status.md)、最新报告与开放错误；核对当前 checkout、分支、base SHA、origin 和工作树。
2. 所有写入任务使用自己的 worktree 和唯一功能分支（`codex/` 或 `claude/` 前缀，见 [agent-collaboration.md](agent-collaboration.md)），原目录保留 main。准备工具、运行设置与验收隔离按 [worktrees.md](worktrees.md)；续做自己的已有 checkout 不重复创建。
3. 从 `tools/toolchain.json` 或实际派生配置读取 gh 路径；按需核实登录和 repo 权限。沿用现有 keyring/credential helper，不显示完整 token、不修改公共认证配置。
4. 完成授权范围并同步模块文档，按 [检查分级](testing.md#按影响选择检查) 执行必要检查并复读相应报告/原始证据。纯文案用 docs；需要 game 时核对 JUnit、日志与源码身份。用户手感单列为待验收，不把自动通过当作试玩通过。
5. Commit 写明最终变化、原因、验证和遗留事项；普通 push 自己的功能分支，不 force。首次 push 明确 `-u origin <自己的分支>`，不误推 main。
6. 同一目标已有未合并 PR 时更新原 PR；独立改动创建新 PR。描述最终问题/行为、验证和审核重点，gh 多行正文用 `--body-file`。成功创建或继续处理实际 PR 后调用 Codex `attach_artifact`；读回 URL、base/head、head SHA 与状态。
7. 进入公共集成锁后重新核对最新 base/head、对应 CI 检查/原始 artifact/源码哈希与冲突状态。base 改变使验证组合改变时先更新/复验；证据未完成不能合并。条件齐备再转 ready，使用 Merge commit 和 `--match-head-commit <已验收SHA>`。
8. 在同一锁内读取实际合并提交、fetch、核对 main 包含关系与 tree；主目录仍为 main、干净且无人编辑/运行时 `git merge --ff-only origin/main`。不代替用户 stash/reset/switch；不能同步时保留远端结果并明确报告。
9. 核对 main push 的实际合并提交、适用检查和原始证据，保存本轮 checkout/base/head/merge、scope/run_id/report_path 与审核结论；关键失败/修复按测试协议长期归档。结束时只归档自己创建且已无用途的 worktree，先保存必要 ignored 证据，不自动删功能分支。

## 公共锁与 CI 门槛

```sh
node tools/with-integration-lock.mjs -- node /private/tmp/astra-integrate-this-task.mjs
```

示例中的脚本须由本轮按实际 PR 编写。锁包住**完整核对、合并、fetch、安全 main 同步和结果核查序列**，不能只锁 merge 后在外同步。锁竞争 exit73；等待后重试，不抢未知锁、不启动后台 Git/gh。进程取消与遗留锁处理见 [worktrees.md](worktrees.md)。

CI 的 `macOS / repository-checks` 对最新 head 检查；PR 合并引用中的实际 commit 与 head/base 分别核对，main push 再验实际 merge commit。原始 artifact、有效配置和源码哈希为合并证据，规则见 [ci.md](ci.md) 与 [testing.md](testing.md)。历史 403 说明见 CI 文档，不能因为没有强制分支保护就跳过这些门槛。

历史首版初始化、依赖分支链和一次性交接完整保留在 [git-history.md](git-history.md)；当前已进入 main 的结果见 [status.md](status.md)。
