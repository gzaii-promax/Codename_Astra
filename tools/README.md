# 开发工具模块

## 执行协议

1. 从仓库根目录读取 `AGENTS.md`、`docs/testing.md`、`tools/toolchain.json` 和最新报告。
2. 游戏验收执行 `node tools/check.mjs --scope game`；工具自检执行 `node tools/check.mjs --scope toolchain`。本机需使用获准的沙箱外环境，原因及原始证据见 `docs/errors/ENV-0004.md`。流程生成或修改后立即执行。
3. 解析标准输出的单个 JSON 摘要，再读取 `report_path` 指向的完整报告。退出码 `0` 仅表示指定范围通过；`1` 表示失败、超时或阻塞；`2` 表示参数不受支持。
4. 核对 `expected_check_ids`、`summary.missing`、每项检查的 `status` 和证据。失败时读取该项 `log_path`，查公共错误记录，再定位原因并复跑同一入口。
5. 交接时给出 `run_id`、`status`、`report_path`、开放错误及未完成项。无需依赖上一个 agent 的聊天上下文。

## 文件与边界

- `toolchain.json`：固定工具版本、路径及来源，由主 agent 维护。
- `bootstrap.mjs`：全新 macOS ARM64 环境的固定依赖准备，独立安装至 `.tools/ci/`，校验归档与包锁哈希，保存成功/失败日志与报告。
- `toolchain-config.mjs`：本机和 CI 共用配置选择、路径解析与版本规则。`ASTRA_TOOLCHAIN_CONFIG` 指向实际配置；报告保留源配置与派生配置各自证据。
- `test-toolchain.mjs`：安装与配置机制的 Node 自动用例，覆盖正常/错误配置、版本拒绝、归档校验和受控超时。不是游戏验收替代品。
- `../.github/workflows/check.yml`：在 GitHub 上准备环境、执行同一验收入口并保存原始证据，规则见 [docs/ci.md](../docs/ci.md)。
- `check.mjs`：唯一公共测试入口，支持 `--scope toolchain|game`，拒绝未知范围或参数。
- `check-game.mjs`：game 范围实现，复制真实工程和固定 GUT 到独立快照，校验 tests/manifest.json，执行格式/lint/导入/真实测试/JUnit 读取/启动。测试名必须完整且唯一，不能用空执行得到通过。
- `play.mjs` 与根目录 `Play.command`：用固定引擎打开真实游戏，不安装工具、不代替验收。macOS launcher 使用本机 Node `/usr/local/bin/node`。
- `read-junit.py`：用 Python 标准库独立解析 GUT JUnit XML；拒绝无法解析、空测试、无断言及计数矛盾的报告。
- `.tools/`：工具本体；入口不安装工具，不修改系统配置，不建立 Git 仓库，不重新指定 `HOME`。
- `artifacts/test-runs/<run_id>/`：每次运行独立保留 fixture 项目、命令日志、Godot 日志、GUT XML 和 `report.json`；`latest.json` 提供最新报告位置。
- fixture 仅验证工具链，没有游戏功能或正式素材。完整自检包括版本、Godot 导入/解析/运行、GUT 成功和故意失败、linter/formatter 成功和故意失败，以及受控进程超时。

## 判读要点

- `checks[].status` 是检测结果是否符合该项预期；`checks[].actual.observed_status` 保留底层进程状态。因此故意失败和超时项可以 `status: pass`，同时保留底层 `fail` 或 `timeout` 与退出码。
- 每个外部命令使用 argv 数组直接执行，具有有限超时；超时后终止进程并确认它已退出。原始 stdout、stderr 和进程结果留在日志中，报告保留诊断尾部。
- `junit-success` 和 `junit-failure` 分别核对实际测试数量、断言数量、失败、错误、跳过及测试名；不能只凭 GUT 退出码认定测试已执行。
- 内部配置/fixture 检查的 `execution_kind: internal` 表明它们由入口完成，`command` 给出完整复跑入口；不需要手动拼装内部命令。
- 报告保存后读取回验，再原子更新最新指针。报告中的 SHA-256 标识实际测试源码/入口/解析器/配置/测试协议；game 的代码哈希、lint、格式检查均取自同一个快照。Git commit 与 working_tree_status 另行记录；首次提交前 commit 为 null，不能凭提交号忽略工作树改动。
- 不具备运行条件时产生 `blocked` 报告并保留未完成检查；不能把仅创建测试文件视为完成验证。
- 工具 fixture 结果仅证明检测能力，不能视为游戏功能测试；game 正常验收不接受任何非预期失败/超时。游戏操作手感由用户主动反馈。

## GitHub 工具与 CI

固定引擎、GUT、gdtoolkit 与运行时来源在 toolchain.json；Python 工具使用独立虚拟环境及 requirements-gdtoolkit.lock。GUT 是测试依赖，没有引入替代游戏框架；首版游戏使用原生 CharacterBody2D、Resource 和物理查询，避免尚无实际需求的控制器/技能插件。

GitHub CLI 2.102.0 已从官方 macOS arm64 发布包安装到 `.tools/gh-2.102.0/`，归档 SHA-256 与官方 checksums 匹配；路径/来源记录在 toolchain.json。工具自检在配置存在 gh 时追加 `version-gh`，其他成功、故意失败、超时、报告读取检查保持有效。账号授权由用户通过网页完成，凭据保存在系统 keyring，禁止把 token 写入仓库或日志。

仓库为私有 `gzaii-promax/Codename_Astra`，Git/PR 流程见 [docs/git-workflow.md](../docs/git-workflow.md)。GitHub connector 和本机 CLI 各自有权限；连接能返回 profile 不代表能访问当前私有仓库。不要因 connector 404 就判断仓库不存在。

CI 已获实现授权，先在 macos-15 ARM64 runner 上实际验证全新安装。Node 由固定官方 setup action 准备，Python 使用固定 Astral python-build-standalone 归档及 SHA-256；bootstrap 精确校验后创建 venv；Godot/GUT 归档和 pip 包使用 SHA-256。CI 的 Git 使用最低版本策略并记录实际值；不安装 gh、不获取个人凭据。是否已跑通及实际 run 见 docs/status.md，不将工作流文件存在等同于成功。
