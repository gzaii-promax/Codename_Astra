# 持续集成与合并检查

## 授权与范围

2026-10-01 用户授权实际跑通此前讨论的 CI：可复现依赖安装、GitHub Actions 自动验收、成功与失败证据、合并前核查。本轮从最新 main 建立独立 `codex/ci-checks` 分支；不把多语言 PR #3 或生命 PR #4 合入 main。PR 详情面板的加载问题暂时搁置。

CI 变更沿用持续提交与合并授权。多语言版本的草稿例外仍按该版本范围处理；不得把它自行扩展成所有后续工作都禁止合并。

## 工作流与安装

- `.github/workflows/check.yml`：工作流 `Repository checks`，检查名 `macOS / repository-checks`。所有目标分支的 PR 创建、更新、重开、转 ready、编辑均触发；main push 与手动触发也执行。草稿 PR 同样验收，不只过滤 main 目标。
- runner 固定 `macos-15` ARM64。官方 Actions 固定完整 commit SHA，不依赖漂移 tag；权限为 contents:read，checkout 不保存 Git 凭据。同一 PR 新提交取消旧运行，每次 job 限时 15 分钟。
- `tools/bootstrap.mjs`：Node 和 Python 由工作流先准备并按配置校验精确版本；独立安装固定 Godot、GUT 和带 SHA-256 的 pip 锁到 `.tools/ci/`。失败保留安装报告与日志，不能以目录存在代替校验，也不覆盖本机已安装工具。
- `tools/toolchain-config.mjs`：两个 scope 共用配置读取与版本判定。默认读取本机 `tools/toolchain.json`；`ASTRA_TOOLCHAIN_CONFIG` 显式选择 CI 生成的 `.tools/ci/toolchain.json`。公共命令参数仍只有 `--scope toolchain|game`。
- Godot、GUT、Python、Node、gdlint、gdformat 精确版本不变。Git 在 CI 只用于源码/提交元数据，采用明确最低版本 2.39.0 并记录实际版本；本机继续精确校验已有版本。CI 配置不要求 gh 或登录凭据。

## 同一验收入口

顺序执行 `node --test tools/test-toolchain.mjs`、`node tools/check.mjs --scope toolchain`、`node tools/check.mjs --scope game`。工具自检含预期失败与超时；它们只在检测结果符合预期时通过。普通 game 验收中的失败、跳过、缺失或超时仍判不通过。工作流不以 continue-on-error 隐藏失败。

新安装验证通过后，即使先前检查失败也尝试执行 game，保留独立证据；安装失败则由安装报告定位环境问题。所有正常结束的失败运行仍尝试上传 `artifacts/bootstrap/`、`artifacts/test-runs/`、CI 上下文与实际配置，保留 7 天。artifact 保存成功只证明可取回证据，不代表验收通过。

## 对应源码与判断

报告记录受版本控制的工作流、入口、安装脚本、配置读取器、源配置、包锁、测试与协议 SHA-256；另记录实际读取配置的路径、完整内容及 SHA-256。生成配置是运行环境证据，不冒充 Git HEAD 中的源码。

`artifacts/ci-context.json` 记录 PR head/base、事件 GITHUB_SHA、run_id/attempt 与 runner。默认 PR checkout 验证 GitHub 生成的合并结果，报告的实际 commit 可能不同于 PR head；合并前须同时核对当前 PR head、对应运行和源码哈希。main push 再验证实际合并提交。不能拿旧提交上的绿灯批准新提交。

接入验收包括普通 PR 的真实成功运行、临时修改现有稳定断言造成失败、取回失败日志/XML、恢复断言后重新成功。故意失败不加入最终 game 的可接受规则，也不减少测试契约。具体 run、提交和审核结果见 `status.md`，失败记录按 `errors/README.md` 保存。

## 仓库门槛与限制

2026-10-01 GitHub 的 main 分支保护 API 返回 403：`Upgrade to GitHub Pro or make this repository public to enable this feature.` 现套餐无法设置私有仓库的必需检查。保留私有属性，不升级套餐；CI 仍运行，并由 agent 在持续合并流程里核对必需检查。将来套餐支持后，再启用相同检查名的分支保护。

本轮不发布安装包。headless 技术验证不能替代画面审核、正式数值、用户试玩或发行平台验证。官方机制参考：[工作流事件](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows)、[runner](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)、[artifact](https://docs.github.com/en/actions/tutorials/store-and-share-data)、[私有分支保护](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches)。
