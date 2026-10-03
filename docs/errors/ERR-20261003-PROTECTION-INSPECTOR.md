# ERR-20261003-PROTECTION-INSPECTOR：主角初始化覆盖保存的受击保护

- status: resolved
- channel: user_feedback, automated_test
- category: code
- first_seen: 2026-10-03
- base_commit: `a3401f6e62e2c11cb2f4cd30af1836afb32ae4fe`
- checkout: `/private/tmp/astra-protection-01a101be`
- original_run_id: `20261003T123523128Z-13e9408b`

## 复现与原始证据

用户要求复核：Inspector 导出的 `Combatant.hit_protection_seconds` 被 `PlayerCharacter._ready()` 无条件写成公共常量 0.5，保存值不能生效。本轮先保留该业务代码，新增独立场景覆盖与入树前配置回归，立即执行 `node tools/check.mjs --scope game`。

工具准备报告为 `artifacts/worktree-setup/20261003T123306849Z-1596725d-ca11-4917-8218-e239020c5f2e/report.json`；固定工具链验收 `20261003T123336922Z-003f551b` 实际 22/22 通过。Godot 4.7.2、GUT 9.7.1、Python 3.12.14、gdtoolkit 4.5.0，沿用已授权的沙箱外执行环境。

原始 game 报告、XML、日志和冻结源码在 `artifacts/test-runs/20261003T123523128Z-13e9408b/`。实际 14 项检查完成，137 tests / 2796 assertions，3 failures、0 errors/skipped，GUT 退出 1 且未超时；lint、format 也失败，夹具原因另记 [PROTECTION-FIXTURE](ERR-20261003-PROTECTION-FIXTURE.md)。原 134 项回归通过，三个新增 case 失败，不能把此轮当成通过。

`logs/gut.engine.log` 记录：场景加载后、入树前分别为 0.0 / 0.2；入树后均为 0.5。零秒角色第二次正伤害被拒绝，生命停在 2.5 而非 2.0。自定义 0.2 秒角色在 14 个实际物理帧后仍剩约 0.267 秒；入树前代码设置 0.0 / 0.15 同样被改为 0.5。冻结的旧主角脚本 SHA-256 为 `b9a0d7e9e9b7940607a8ace0dd168b0b703e11c3618243ceee83866882f91837`。

## 原因与修复

依赖、固定版本与 headless import 已通过；值在对象入树前正确、进入 Player._ready 后改变，并有脚本中的无条件写入，确认属于代码配置所有权问题。不是缺依赖、类缓存或用户数值无效。夹具中的 root editable 声明导致额外引擎错误，不能与此代码覆盖混为同一原因；没有夹具的入树前代码配置 case 也独立复现覆盖。

修复仅删除 Player._ready 的赋值，在 `player_character.tscn` 的 Combatant 节点显式保存 0.5。公共常量保留默认基线；实际配置以每个 Combatant 导出属性为准，通用组件默认仍为 0.0。合法零秒不作为“未配置”标志，训练重置不重新覆盖参数。未改变移动、跳跃、默认保护或伤害数值。

增加第四项真实保存往返：从主角实例修改属性，经 PackedScene.pack / ResourceSaver.save 写到本轮隔离证据目录，再忽略缓存从磁盘重新加载、入树并实际受伤。与独立保存的 0.0 / 0.2 继承场景、0.0 / 0.15 入树前配置和现有 0.5 默认基线形成独立覆盖；预期不用被测实现值反向生成。

## 复验与当前结论

修复与夹具清理后立即复跑相同完整入口，run_id `20261003T123733949Z-2ef5caf5`，实际 14/14 checks、138 tests / 2813 assertions、0 failures/errors/skipped，全部用例有断言且名称与 manifest 完全一致。四个新增 case 分别有 20 / 24 / 8 / 19 assertions；默认 0.5、其他角色零秒及其余既有战斗/移动/地图/语言回归仍通过。

该轮 `report.json`、`game.xml`、21 份原始日志和 `source-report-review.json` 位于本 checkout 的对应 test-runs 目录。GUT 退出 0、未超时，原始日志无 SCRIPT ERROR / Parse Error / ERROR。166 项报告源码 SHA-256 与当前文件和存在于冻结工程的相应文件一致。`protection-0.tscn` / `protection-20.tscn` 是实际引擎保存产物：零秒值等于通用声明默认值，保存时可省略属性，重新加载后仍为零；0.2 文件明确存有该字段。两个文件重新加载入树后的实际命中结果均符合独立预期。

技术关闭依据是原失败项与完整回归通过，不因错误文本改变自动关闭。主目录的 project.godot 用户修改未在此独立 checkout 中迁移或改写，最终组合与 PR head 仍由主 agent 复验；该历史独立提交未进入 main；2026-10-03 用户重新授权修复前两条，本轮在 c390803 基础重新整合，适用 AGENTS 的持续提交/合并授权。历史 run 只证明原快照；当前组合另行完整复验。手感由用户另行反馈。

## 重新授权后的组合验证（2026-10-03）

旧独立修复没有进入 main；用户本轮明确要求修复前两条。在 `c390803…` 的独立 worktree 重新整合配置修复，并补入跨模块配置归属契约与设计基线。组合 game `20261003T144553250Z-ee277490` 实际 14/14、138 tests / 2916 assertions，零失败、错误、跳过；四个保存/重载回归及默认/零秒完整机制均运行。主 agent 从 XML 独立解析、复读原始引擎日志，并核对 171 项源码与快照哈希，未发现引擎错误。

当前组合报告位于 `/Users/hanguo/.codex/worktrees/config-baseline-fix-01a10240/Godot-project/artifacts/test-runs/20261003T144553250Z-ee277490/`；最终 PR head 与 main 的独立证据另存主目录 `artifacts/config-baseline-fix-01a10240/`。历史独立原始证据已保存在 `artifacts/rollback-workflow-01a10226/preserved/standalone-protection/`，原临时 checkout 路径仅为首次上下文，不要求它继续存在。持续提交/合并授权适用，用户手感仍独立验收。
