# 历史 Git 交接记录

> 2026-10-02 文档整理时完整保留的原 Git 交接页。以下分支、PR 状态、授权例外和执行计划按原时点阅读；旧 draft-only 限制已被后续明确整合授权取代。日常流程见 [git-workflow.md](git-workflow.md)，实际已整合版本见 [status.md](status.md)。


## 当前多会话约定（2026-10-02）

所有写入开发在每会话独立 worktree/唯一功能分支内完成，原目录保留 main。创建、工具准备、Godot 启动、测试证据、公共串行集成锁及安全归档的固定流程见 [worktrees.md](worktrees.md)，后续 Agent 必须执行。持续提交/合并授权适用；并行不意味着可以操作别人的 checkout 或同时推进 main。


## 地图首版交接（2026-10-02）

本轮用户明确授权已采纳的地图方案实施，持续提交与合并授权适用。实现分支 `codex/map-system-v1` 从已整合 `main` 的 `5d3310364a162a0021de7ca71debc0328d68566c` 创建，[PR #10](https://github.com/gzaii-promax/Codename_Astra/pull/10) 以 main 为 base；不沿用历史功能草稿限制。最终本地 game `20261002T070747379Z-3e11afa4`、真实 13 图及原目录启动已核实，详见 [status.md](status.md)。首次远端 CI 失败已保留并修复精确物理帧测试，见 [MAP-CI](errors/ERR-20261002-MAP-CI.md)。远端检查必须核对该 PR 最新 head、原始 artifact 与源码哈希，再用 Merge commit 合并并同步本地 main；用户手感仍独立待验收，不发布安装包。

## 当前整合授权（2026-10-02）

用户明确要求把 `codex/health-combat-v3` 和 `feat/localization-v2` 合入主分支。本轮保留两个分支历史，同时整合 `codex/scale-movement-v4` 中已经合入的心形 PR #7；处理公共生命代码与测试冲突，保留主角 0.5 秒保护、严格半心伤害、稻草人归零回满和可变跳跃。通过本轮必要验收后创建整合 PR，base 必须为 `main`，按持续授权合并并同步本地 main。

本轮开始时远端：main=`a3015e2`，多语言=`c9293b7`，生命=`d211fa9`，尺度/心形=`fa1324e`。PR #4/#6/#7/#8 均为 MERGED，但分别进入原依赖分支，后续提交未自动进入 main。旧草稿限制已由用户本轮明确合并授权取代；不发布安装包。最新证据见 [integration-main.md](integration-main.md)。


## 历史交付记录（当前状态以上方核实为准）

- 仓库：`https://github.com/gzaii-promax/Codename_Astra`，私有；本机 CLI 已核实 private=true、push=true。
- origin：`https://github.com/gzaii-promax/Codename_Astra.git`。
- 默认分支：main；首版功能分支：feat/combat-v1。
- 首版[PR #1](https://github.com/gzaii-promax/Codename_Astra/pull/1)已附加到 Codex 任务，并于 2026-10-01 合并；合并提交为 `09f35ec8b0ffaba38f6e77974ecc943721828083`。后续实际分支状态与提交以 GitHub 读取结果为准。
- 用户已授权持续提交与合并：在本项目已授权开发范围内，通过必要验收并提交 PR 后，可自行合并，无需再次确认提交或合并。功能范围和重要架构决策仍按用户已有分工处理。
- 当前多语言下一版有更具体的新限制：只创建或更新 draft PR，不自动合并或发布，见 docs/localization-v2.md。此轮限制优先于持续合并授权；后续按最新用户范围执行。
- 生命与定时敌人接续未合并的 `feat/localization-v2`，分支 `codex/health-combat-v3` 已创建并核实独立[草稿 PR #4](https://github.com/gzaii-promax/Codename_Astra/pull/4)，以 `feat/localization-v2` 为 base，差异只包含本轮功能。实现提交为 `85473836829e5b876178ff0e1cc265e6f7f725de`；最终 head 以当前 GitHub 读取为准。依赖 PR #3 保持草稿；本轮不合并或发布。范围与验收见 docs/health-combat-v3.md、docs/status.md。
- 统一尺度与可变跳跃接续生命分支，分支 `codex/scale-movement-v4` 已核实独立[草稿 PR #6](https://github.com/gzaii-promax/Codename_Astra/pull/6)，base=codex/health-combat-v3；实现提交 `05efebb1ab74fd2764ddae8a4b111672c8ead4e8`。本地 game 93 项验收与真实图形已完成，范围/证据见 docs/scale-movement-v4.md、docs/status.md。依赖 #3/#4 及本 PR 均保持草稿，不合并或发布；最终 head 与远端 CI 读取当前 PR。

### 受击保护本轮基线（2026-10-02）

上述版本描述保留原交付时点。当前 GitHub 已核实：PR #3 已合入 main（`origin/main=a3015e2`），PR #6 已合入生命分支，生命 PR #4 仍为 OPEN draft、head=`06718c78a27e4ffd822d8d8ec9e61ca48897fa79`。尺度内容存在于生命草稿分支，尚未进入 main。

受击保护使用 `codex/hit-protection`，从该生命 head 建立，以 `codex/health-combat-v3` 为 base 交付独立 draft PR；不合并或发布。公共默认值与验收见 `hit-protection.md`。本地已有其他 worktree/未应用 stash 不属于本轮改动；不应用、删除或迁移它们。

实现提交 `98ab99e` 已推送，独立[草稿 PR #8](https://github.com/gzaii-promax/Codename_Astra/pull/8) 已创建并核实 OPEN、isDraft=true、base=codex/health-combat-v3、head=codex/hit-protection；已附加到当前任务。完整本地验收与实际工作区启动证据见 `status.md`。只更新交接文档不会改变已验收业务源码；最新 head/远端检查仍须读当前 PR。

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

原轮次多语言 PR #3 与生命 PR #4 有草稿例外；本轮明确合并授权已取代该限制。CI PR #5已独立按持续授权合入main；把CI基础设施同步进草稿不意味着合并功能版本。


## 2026-10-05 从 AGENTS 移出的历史整合说明

以下保留原文；其中“本轮”指原整合轮次，路径按原根目录 `AGENTS.md` 阅读。现行持续授权仍由 AGENTS 维护，实际结果见 [status.md](status.md)。

```markdown
- 2026-10-02 用户已采纳地图系统讨论中的全部建议并授权第一版开发：Godot 原生编辑的 3 个灰盒房间、A ↔ B ↔ C 与 C → A、有向连接、共享模板与独立身份/探索、相机与调试入口。契约见 [docs/map-system.md](docs/map-system.md)，转场、预加载和攀爬为后续必做 TODO，不在第一版实现；持续提交/合并授权适用，用户手感仍独立验收。

- 2026-10-02 用户明确授权把 `codex/health-combat-v3` 和 `feat/localization-v2` 合入 `main`；本轮同时整合已交付的心形分支，解决原反馈中的心形与跳跃缺失。此授权取代以下旧交付文档的 draft-only 限制；不扩大功能范围，不发布安装包。
- 当前整合范围：多语言与菜单、通用生命与定时敌人、1 U=16 px 的统一尺度与 1–2.5 U 可变跳跃、心形生命和主角 0.5 秒受击保护。当前规则分别见 [localization-v2.md](docs/localization-v2.md)、[scale-movement-v4.md](docs/scale-movement-v4.md)、[heart-health-v5.md](docs/heart-health-v5.md)、[hit-protection.md](docs/hit-protection.md)；心单位取代旧减伤规则，其他角色默认 0 秒保护。
- 合并链修复范围和当前验收见 [docs/integration-main.md](docs/integration-main.md)、[docs/status.md](docs/status.md)。旧 PR #4/#6/#7/#8 的 MERGED 状态仅表示合入原依赖分支；是否进入 main 以远端提交包含关系核实，不以 PR 状态推断。
```
