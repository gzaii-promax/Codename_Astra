# ERR-20261003-WORKSPACE-GUARD

- 状态：resolved
- channel: automated_test
- 首次：2026-10-03，本轮独立 codex/editor-isolation-01a101be，base a3401f6。
- 原始证据：`/private/tmp/astra-runtime-01a101be.log`、`astra-guards-final-01a101be.log`、`astra-guards-fixture-01a101be.log`；最终本轮工作流 JUnit 见 artifacts/engineering-handoff。

首次试运行 `context()` 报 `fatal: not a git repository: ''`，原因是把 GIT_DIR 等覆盖为空字符串而非删除变量；这是代码问题，不是依赖/环境缺失。已改为删除这些环境键，并立即重跑真实上下文、现有启动和锁回归。

独立审查还修复了 lock 调用者归属、已提交人类文件冲突、交接期间双端活动冻结、子命令 argv、canonical root、原样 diff/NUL 文件名、未知租约及启动失败子进程确认。对应回归覆盖正/负路径。

新进程扫描正确检测到本机原生 Godot 编辑器，正常资源夹具因此被阻断；不终止用户进程。测试夹具改为隔离受控进程观测，包含有/无/观测失败路径；真实桌面另留阻断证据，不能把夹具成功当成用户已关闭编辑器。清理只针对测试自建临时仓库。

复发时先核对 Git 环境、claim schema 与 root/argv，再读原始进程列表。正常 guard 阻断不等于引擎或业务代码故障。修复后复跑 `tools/test-human-workspace.mjs` 和原 runtime suite，并核对报告/日志与本轮源码哈希。
