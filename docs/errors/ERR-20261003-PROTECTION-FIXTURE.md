# ERR-20261003-PROTECTION-FIXTURE：配置回归夹具的可编辑实例声明与长行

- status: resolved
- channel: automated_test
- category: test
- first_seen: 2026-10-03
- original_run_id: `20261003T123523128Z-13e9408b`
- checkout: `/private/tmp/astra-protection-01a101be`

## 原始证据与原因

首次新增配置回归后立即运行 `node tools/check.mjs --scope game`。报告、冻结夹具、XML 与日志在 `artifacts/test-runs/20261003T123523128Z-13e9408b/`，并保留在修复后不覆盖。`logs/gut.engine.log` 四次记录 `ERROR: Condition "!is_ancestor_of(p_node)" is true.`，堆栈指向 PackedScene.instantiate() 期间 set_editable_instance。两个继承场景各加载两次，均带不正确的 `[editable path="."]`；根节点不是自己的祖先，运行时覆盖属性不需要这一声明。属于夹具错误。

同轮 `logs/lint.log` 报 `test_hit_protection.gd:466: Max allowed line length (100) exceeded`，`logs/format.log` 报该文件 would reformat，二者退出 1。新增 ResourceLoader helper 未先按固定格式器整理，属于测试文件格式问题。依赖版本和 import 已通过，不安装或修改依赖来规避检查。

## 修复与复验

删除两个夹具中的错误 editable 声明，保留继承节点和明确的保护覆盖；用固定 gdformat 整理 test_hit_protection.gd，随后 gdlint / gdformat --check 对全部本轮修改的 GDScript 通过。没有修改 lint 规则、放宽保护预期或删除失败用例。

真实初始化覆盖另在 [PROTECTION-INSPECTOR](ERR-20261003-PROTECTION-INSPECTOR.md) 跟踪；本夹具问题不能解释没有继承夹具的入树前代码配置也被改写。修复后立即复跑完整 game 入口，run_id `20261003T123733949Z-2ef5caf5`：14/14 checks、138 tests / 2813 assertions、0 failures/errors/skipped；lint / format / import / GUT / JUnit 全部通过，GUT 退出 0 且未超时。原始 21 份日志无 SCRIPT ERROR / Parse Error / ERROR，四次继承夹具实例化的原引擎错误未再出现，保存往返也通过。

实际报告、XML、日志与源码核对在本 checkout 的对应 test-runs 目录，关闭仅依据本次可复跑技术证据，不宣称最终 PR 已通过或已合并。原失败报告与夹具源码快照保留，后续相同触发条件复发先重开本记录。

## 本轮重整合的复验

前两条修复的组合 game `20261003T144553250Z-ee277490` 14/14、138 tests / 2916 assertions，零失败/错误/跳过，四个配置往返 case 均执行。原 editable 引擎错误与格式失败未复现；171 项源码/快照哈希及原始 XML/日志经主 agent 复读。最终 head 验收与证据归档入口见 [Inspector 原记录](ERR-20261003-PROTECTION-INSPECTOR.md)，历史 run 不代替本轮报告。
