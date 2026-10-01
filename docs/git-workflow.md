# GitHub 与分支交接

## 已授权的远端

- 仓库：`https://github.com/gzaii-promax/Codename_Astra`，私有；本机 CLI 已核实 private=true、push=true。
- origin：`https://github.com/gzaii-promax/Codename_Astra.git`。
- 默认分支：main；首版功能分支：feat/combat-v1。
- 首版[PR #1](https://github.com/gzaii-promax/Codename_Astra/pull/1)已附加到 Codex 任务，并于 2026-10-01 合并；合并提交为 `09f35ec8b0ffaba38f6e77974ecc943721828083`。后续实际分支状态与提交以 GitHub 读取结果为准。
- 用户已授权持续提交与合并：在本项目已授权开发范围内，通过必要验收并提交 PR 后，可自行合并，无需再次确认提交或合并。功能范围和重要架构决策仍按用户已有分工处理。
- 当前多语言下一版有更具体的新限制：只创建或更新 draft PR，不自动合并或发布，见 docs/localization-v2.md。此轮限制优先于持续合并授权；后续按最新用户范围执行。
- 生命与定时敌人接续未合并的 `feat/localization-v2`，分支 `codex/health-combat-v3` 已创建并核实独立[草稿 PR #4](https://github.com/gzaii-promax/Codename_Astra/pull/4)，以 `feat/localization-v2` 为 base，差异只包含本轮功能。实现提交为 `85473836829e5b876178ff0e1cc265e6f7f725de`；最终 head 以当前 GitHub 读取为准。依赖 PR #3 保持草稿；本轮不合并或发布。范围与验收见 docs/health-combat-v3.md、docs/status.md。

## 首次发布的历史

远端初始为空。为使首版全部代码可以在同一个 PR 审查，创建空 main 初始化提交 `8f585ab`，并在功能分支把该基线合入原本地首版提交 `172c38e`；连接提交为 `e07e4d5`。原首版提交及游戏内容树均保留，不强推或覆盖其他历史。

首次 PR 合并前 main 仅有空基线；PR #1 合并后已包含完整首版工程，本地 main 已同步。后续开发先读取最新 PR/提交，再从最新 main 创建功能分支接续用户反馈。

## Agent 固定步骤

1. 阅读 AGENTS、最新提交、相关模块、docs/status、最新报告与开放错误；再检查 origin、当前分支和工作树。
2. 从 tools/toolchain.json 读取 gh 路径。执行 gh auth status 与 gh repo view，只记录账号/权限；禁止显示或提交完整 token。
3. 完成已授权范围，维护模块文档与详细 commit。验收使用现有单一入口，必须读取结果与源码 hash；按改动范围执行必要检查。验证通过后直接进行提交和 PR，不再索取提交许可。用户手感是独立反馈渠道，未完成的试玩结论写为待验收，不阻塞 PR 提交，也不能被自动测试替代。
4. 普通 push 推送功能分支，不 force、不自动覆盖默认分支。首版仅初始化 main 与功能分支，此后保持常规分支流程。
5. 同一目标已有未合并 PR 时优先更新该 PR；新的独立改动再创建 PR。描述写明最终实现/验证/遗留信息，首版可参考 docs/delivery-v1.md，gh 使用 --body-file 保留实际换行。创建或继续处理实际 PR 时调用 Codex attach_artifact 附加它。
6. 读取 GitHub 实际 PR 的 URL、base/head、状态和 head SHA，并核对远端 refs 与本地提交。不要把创建请求或描述草案当成成功结果。
7. 按持续合并授权核对最新 head 与验收证据、源码哈希、适用的 GitHub 检查及冲突状态。必要检查未通过或证据与最新代码不对应时，先修复/复验；没有 CI 的仓库要明确本地证据范围。草稿在条件齐备后转 ready，默认用 Merge commit 保留详细历史，合并命令用 --match-head-commit 锁定已核对的 SHA，不绕过仓库要求。
8. 合并后读取实际 merged 状态/合并提交，核对远端 main，再 fetch 并用 fast-forward 同步本地 main。后续从最新 main 创建新分支。合并不等于用户手感验收，待反馈仍保留；不因合并自动删除分支。

授权存在系统 keyring；本地 git credential helper 调用当前项目的 gh，凭据不会写入 tracked files。新机器或移动目录后需重新配置工具路径/登录。

CI 接入本轮已获授权，工作流与验收见 [ci.md](ci.md)。接入后，合并前须读取当前 head 的 `macOS / repository-checks` 实际运行与 artifact，核对有效配置、完整验收及源码哈希；PR 合并引用不能混同 head。当前私有套餐不支持分支保护（API 403 已核实），仍由 agent 执行同一门槛。工作流限只读权限，不持有自动合并或发布令牌；合并由已有授权流程执行，本轮不发布安装包。

多语言 PR #3 与生命 PR #4 的版本草稿例外继续有效：仅创建/更新 draft PR，不合并或发布。CI PR #5已独立按持续授权合入main；把CI基础设施同步进草稿不意味着合并功能版本。
