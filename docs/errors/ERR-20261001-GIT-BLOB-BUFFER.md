# ERR-20261001-GIT-BLOB-BUFFER — Git 交付核对缓冲读取大字体失败

- 状态：resolved
- channel：automated_test
- 首次出现：2026-10-01，草稿 PR #3 的文档更新已推送至 `7793ee4a655031efda7f03af512ddc71666d9b52` 后。
- 复现上下文：Node 24.17.0 / Git 2.54.0，临时交付核对脚本用 spawnSync 执行 `git show HEAD:<file>` 并收集完整 stdout，遍历最终 game 报告的 93 项文件。
- 原始错误：`Error: spawnSync git ENOBUFS`，核对脚本退出 1。错误发生在已完成 commit/push/PR 读取后的哈希环节，不等于提交失败；后续实际读取确认 PR 仍 OPEN、isDraft=true，head 与本地一致。
- 预期与实际：应把所有已提交 Git blob 哈希与最终验收文件逐一对应；同步 stdout 缓冲方式在大文件处终止，未完成最后核对。新增两份字体为 16,437,364 与 16,467,736 字节。
- 原因判断：交付核对代码的缓冲读取限制，不是缺 Git/字体、授权失败或游戏代码错误；不重复提交或改动游戏。
- 修复：改用 child_process.spawn 的 stdout 流逐块计算 SHA-256，每个进程保留有限超时与非零退出诊断，不把字体全部塞入同步输出缓冲。
- 验证：`artifacts/git/committed-source-hashes.json` 保存实际 HEAD、方法、逐文件字节数与哈希；93/93 对应 `20261001T103447218Z-fb5fe550`，两份字体哈希同时与官方来源 sources.json 一致。实际进程退出 0，原缓冲错误不再复现。
- 后续：再次核对大素材时优先使用流式哈希，避免仅因辅助脚本失败重复执行已成功的 commit、push 或 PR 创建。游戏报告保持 14/14、53 tests/649 assertions；本问题不重写既有验收结果。
