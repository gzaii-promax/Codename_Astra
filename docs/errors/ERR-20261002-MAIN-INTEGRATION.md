# ERR-20261002-MAIN-INTEGRATION：主分支缺少已交付的心形与跳跃更新

- status: resolved
- resolution_scope: 缺少已交付代码的主分支整合技术问题；用户手感仍待反馈
- channel: user_feedback
- first_seen: 2026-10-02
- code_state: main/origin/main=`a3015e26de62b2c584969d0596ca8fe33bf5505e`

## 原始反馈与复现

用户反馈“为什么我运行最新的版本，血量还是在用血条的形式，没有改成最新的心形的统计形式，是代码被覆盖了吗”，切回主分支后又反馈“为何跳跃的更新也没有同步”。本轮随后明确授权“以上两个分支都合并进主分支”。

原目录最初位于 codex/hit-protection（eb7ee1f），绘制血条；心形代码完整保留在 codex/heart-health-v5（1f18d5d）独立 worktree。切回并快进 main 后，main 与 origin/main 一致，但不包含跳跃提交05efebb、心提交46f3f8c或保护提交98ab99e。

## 原因与证据

只读 GitHub PR API 和 git ancestry 均确认：#6→生命、#4→多语言、#7→尺度、#8→生命。main 的 #3 合并只有多语言旧 head66a143e，功能后续提交不会自动流入 main。不存在本次观察中“心代码被覆盖”的证据；根因是依赖分支的后续合并未整合到 main。

## 修复与验证

在 codex/integrate-game-updates 保留多语言c9293b7、生命d211fa9、尺度/心形fa1324e的合并历史。公共Combatant保留半心存储和REFILL，叠加受击保护；receiver保留完整伤害与同步回调外层结果。保护测试迁移到心单位，场景第二次伤害和图形探针等待实际保护到期。

完整游戏运行 `20261001T185434427Z-1a47966d` 已通过14/14 checks、112 tests、2172 assertions，126项源码哈希一致，21份日志无引擎错误。实际原目录导入/启动及三语12图亦通过（artifacts/integration-workspace/20261001T185442Z）。当前提交阶段待最新head远端CI及main包含关系确认；本地功能整合已验证。用户手感不由自动测试关闭。

## 2026-10-02 整理时的技术闭环

原文末尾“待远端 CI/main 包含关系确认”为当时状态。现已读回 [PR #9](https://github.com/gzaii-promax/Codename_Astra/pull/9) 为 MERGED，实际合并提交 `5d3310364a162a0021de7ca71debc0328d68566c`，并由 `git merge-base --is-ancestor` 核对其及原跳跃/心形/保护实现均属于当前 main `da2cb24639a77d7ff9b122600aa1d47c0cc9b22c`。

当前游戏基线的 main push [CI 36995028275](https://github.com/gzaii-promax/Codename_Astra/actions/runs/36995028275) 原始报告 `20261002T102213779Z-f7e3cf9e` 对应同一 main：14/14 检查、134 tests / 2742 assertions，无失败/错误/跳过。报告在主目录 `artifacts/speed-handoff/ci-runs/36995028275/checks-36995028275-1/artifacts/test-runs/20261002T102213779Z-f7e3cf9e/report.json`；原整合启动/三语心图证据保留在上节位置。

据此关闭“main 没有包含已交付心形/跳跃”的技术问题，保留原反馈、原因和失败时点，不把技术闭环当作用户手感验收。若同一症状复发，先读取实际启动目录、HEAD、源码和缓存，按公共协议追加复现并重新打开记录。
