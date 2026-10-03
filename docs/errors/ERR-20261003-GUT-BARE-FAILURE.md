# ERR-20261003-GUT-BARE-FAILURE：详细日志漏计无提示布尔断言

- status: resolved
- channel: automated_test
- category: test_tool
- first_seen: 2026-10-03
- source_head: `121984d74f285cccf06baaf9ec71210ee622f68d`
- detection_run_id: `20261003T145251808Z-374b53be`

## 原始证据与影响

独立测试 agent 在已通过完整 game 的复制快照中只重插 Player 启动覆盖，四项新配置回归真实失败，GUT exit 1、4 cases / 71 assertions、0 errors/skipped、未超时且无引擎错误。原始证据位于 `/private/tmp/astra-config-baseline-tests-01a10240/artifacts/independent-regression/20261003T145251808Z-374b53be/` 的 `mutation.engine.log`、`mutation.log`、`mutation.xml`、`report.json`。

原日志详细段有 32 个失败断言，其中 4 个无提示布尔断言输出 `[Failed]`，不带冒号；旧分类器只匹配 `[Failed]:`，因此只补读 28 条。原正常验收并未误报通过，但若 XML 首条是设计差异，后续裸布尔失败可能未保留为未分类，不能据此排除机制问题。JUnit 首条限制见 [BASELINE-WALK-FIXTURE](ERR-20261003-BASELINE-WALK-FIXTURE.md)。

## 原因、修复与复验

固定 GUT 9.7.1 的真实输出格式已确认；依赖与环境成功，不换工具版本规避。详细日志读取同时接受有/无冒号的 Failed，裸消息保留为 unclassified；Passed 等断言边界同样识别无冒号，避免将通过消息并入失败。仍按真实 suite/name 对应并排除 summary 重复，不更改 XML 或验收状态。

新增第 11 个分类器 Node 用例，覆盖“XML 只有设计首失败 + 日志裸失败 + 裸 Passed 边界 + summary 重复”。生成后立即运行11/11通过，完整 Node44/44通过；root复读真实 mutation.engine.log，四个失败 case 全部 unclassified，原32条失败均保留（含4条裸失败），证据为本轮 `artifacts/repair-review/bare-failure-real-log.json` 和 `node-44.log`。

技术诊断缺口关闭依据为原日志实测与新回归通过。新的冻结 head 与 PR/main完整验证另行执行；故意失败报告只证明检测能力，不代替正常 game。任务结束前原始证据保存在主目录 `artifacts/config-baseline-fix-01a10240/independent/`，原绝对路径保留执行上下文。
