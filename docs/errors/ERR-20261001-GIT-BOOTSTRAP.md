# ERR-20261001-GIT-BOOTSTRAP：commit-tree 消息文件参数不受支持

- status: resolved
- channel: environment_setup
- category: tooling/command
- first_seen: 2026-10-01
- code_state: 原首版 172c38e；配置 origin 后，尚未推送。

## 复现与原始证据

Git 2.54.0 调用 `git commit-tree <empty-tree> --file <message-file>` 退出 129，输出 `error: unknown option 'file'` 与支持的 `-F <file>`。该命令退出后本地脚本中止，没有创建/推送远端基线。

## 判断与修复

不是依赖或授权失败：此前 git fetch origin 已成功，当前 Git 可执行；错误来自把 git commit 支持的长选项误用于 commit-tree。

改为 `git commit-tree <empty-tree> -F <message-file>` 后脚本退出 0，创建空 main 基线 8f585ab 和功能分支连接提交 e07e4d5。独立比较 HEAD^{tree} 与 172c38e^{tree} 完全一致，未改游戏文件；原提交仍是功能分支祖先。外部推送仍在后续执行，不把本地准备视为已发布。
