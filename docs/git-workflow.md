# GitHub 与分支交接

## 已授权的远端

- 仓库：`https://github.com/gzaii-promax/Codename_Astra`，私有；本机 CLI 已核实 private=true、push=true。
- origin：`https://github.com/gzaii-promax/Codename_Astra.git`。
- 默认分支：main；首版功能分支：feat/combat-v1。
- 首版[草稿 PR #1](https://github.com/gzaii-promax/Codename_Astra/pull/1)已创建并附加到 Codex 任务，等待审核；未合并。
- 用户已授权持续提交：在本项目已授权开发范围内，每次通过 agent 自己的必要验证后，可直接 commit、push 并创建或更新 PR，无需再次确认提交。PR 合并须用户另行明确授权。

## 首次发布的历史

远端初始为空。为使首版全部代码可以在同一个 PR 审查，创建空 main 初始化提交 `8f585ab`，并在功能分支把该基线合入原本地首版提交 `172c38e`；连接提交为 `e07e4d5`。原首版提交及游戏内容树均保留，不强推或覆盖其他历史。

首次 PR 合并前 main 没有游戏功能，下一次开发应先读取当前 PR/提交，从 feat/combat-v1 接续用户反馈。合并后再从最新 main 创建后续功能分支。

## Agent 固定步骤

1. 阅读 AGENTS、最新提交、相关模块、docs/status、最新报告与开放错误；再检查 origin、当前分支和工作树。
2. 从 tools/toolchain.json 读取 gh 路径。执行 gh auth status 与 gh repo view，只记录账号/权限；禁止显示或提交完整 token。
3. 完成已授权范围，维护模块文档与详细 commit。验收使用现有单一入口，必须读取结果与源码 hash；按改动范围执行必要检查。验证通过后直接进行提交和 PR，不再索取提交许可。用户手感是独立反馈渠道，未完成的试玩结论写为待验收，不阻塞 PR 提交，也不能被自动测试替代。
4. 普通 push 推送功能分支，不 force、不自动覆盖默认分支。首版仅初始化 main 与功能分支，此后保持常规分支流程。
5. 同一目标已有未合并 PR 时优先更新该 PR；新的独立改动再创建 PR。描述写明最终实现/验证/遗留信息，首版可参考 docs/delivery-v1.md，gh 使用 --body-file 保留实际换行。创建或继续处理实际 PR 时调用 Codex attach_artifact 附加它。
6. 读取 GitHub 实际 PR 的 URL、base/head、状态和 head SHA，并核对远端 refs 与本地提交。不要把创建请求或描述草案当成成功结果。

授权存在系统 keyring；本地 git credential helper 调用当前项目的 gh，凭据不会写入 tracked files。新机器或移动目录后需重新配置工具路径/登录。本轮不新建 CI，不发布安装包；合并 PR 须用户另行明确授权。
