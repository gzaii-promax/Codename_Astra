# ERR-20261002-WORKTREE-TEST-FIXTURE：临时路径与清理夹具

- status: resolved
- channel: automated_test
- first_seen: 2026-10-02
- code_state: codex/worktree-workflow-v1，base a0204b4，新增运行隔离测试的工作树

## 复现与原始证据

执行 `node --test tools/test-worktree-runtime.mjs tools/test-toolchain.mjs`，17 项中 14 通过、3 失败。原始日志保存在本轮 worktree 的 `artifacts/worktree-handoff/first-root-tests.log`。两项断言实际 cwd 为 `/private/var/folders/...`，夹具预期 `/var/folders/...`；第三项清理空目录时 `rm` 缺少 recursive，出现 ERR_FS_EISDIR。复跑使用 Node 24.17.0、独立临时 Git 仓库。

## 原因与修复

macOS 临时目录别名由子进程规范化，而测试仅比较文本；统一以 realpath 建立夹具根路径，仍要求进程进入准确的 linked checkout。清理只作用于夹具自己的空锁目录，改用 recursive。没有放宽公共锁竞争、命令失败传播或设置隔离断言，没有改变业务行为。

## 当前结论

同一入口复跑 17/17 通过，日志 root-tests.log；随后加入 SIGINT/SIGTERM 孙进程回归，与既有工具链组合 19/19 通过，日志 root-tests-with-signals.log。此错误不涉及游戏手感。

## 工具准备的符号链接用例

独立子 agent 的准备器测试在新增 Git check-ignore 时出现一项失败：目标 `.tools` 为符号链接，Git 先返回 beyond a symbolic link，测试要求工具自己的明确拒绝提示。目标从未被允许共享写入，属于校验顺序与错误消息问题。原始输出保存在工具 worktree 的 `artifacts/worktree-tools-tests/20261002T073446Z-ignore-order-failure/original-output.log`；该目录编号是回溯归档标识，原始开始时刻未知，不当作运行时间。

修复为先 lstat 拒绝目标目录符号链接，再检查配置忽略规则。原失败项及完整 14 个准备器测试通过；与既有 10 个工具测试组合 24/24，报告 `20261002T073425883Z-aa60a007-7a2a-4ece-a4f9-987af52ea1cd/report.json`。主工作分支接入后，全部 33 个 Node 回归通过，日志 `artifacts/worktree-handoff/combined-node-tests.log`；故意失败 fixture 的底层非零结果保留，仅检测能力符合预期计为通过。
