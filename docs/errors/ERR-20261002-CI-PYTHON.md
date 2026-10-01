# ERR-20261002-CI-PYTHON：托管 runner 缺少固定 Python 安装包

- 状态：investigating
- channel：automated_test
- 首次出现：2026-10-01 15:59 UTC；[GitHub run 36888487517](https://github.com/gzaii-promax/Codename_Astra/actions/runs/36888487517)，PR #5 head `5dccd8a28328c4272954e5174abdcac38c069ce4`。
- 上下文：macos-15 ARM64 / macOS 15.7.9；固定 setup-python v7.0.0 请求 Python 3.12.14。
- 原始证据：`artifacts/ci-runs/36888487517/run.log`；安装步骤退出失败：`The version '3.12.14' with architecture 'arm64' was not found for macOS 15.7.9.`
- 预期与实际：预期准备项目固定 Python 后运行验收；实际在 setup-python 失败，bootstrap、工具和游戏检查均未执行，不能算通过。CI 上下文步骤位于安装之后，导致此轮没有 artifact；GitHub 原始 job log 已取回保存。
- 原因判断：已确认托管安装列表缺少对应包；Python 官方该版本是 source-only 发布，actions/python-versions 的3.12.14矩阵没有darwin。来源见 ../ci.md，本机同版本 venv 成功不证明 setup-python 能准备该版本。
- 修复尝试：保留3.12.14，改由 bootstrap 默认安装固定 Astral PBS release20260929、SHA-256验证归档；稳定路径放置后创建venv，额外核验darwin/arm64。CI上下文前移至运行时准备之前。新来源真实安装报告 `20261001T160323835Z-f71e0171` 为21/21通过、Python归档cached=false；10项单测通过。公共验收与远端成功/真实失败/恢复成功流程继续执行。
- 当前结论：未完成远端验收，PR 保持草稿；不得放宽版本或将未执行检查视为成功。
