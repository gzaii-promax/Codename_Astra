# PR #17 的精简历史证据

这是 2026-10-05 从既有报告保存的历史摘录，不是本轮重新运行，也不证明后续代码或用户手感通过。完整快照继续留在原任务的忽略 artifacts 中；本目录让新 checkout 可以核对关键失败和最终提交身份。

- [原始生命周期日志片段](original-lifecycle.log)：旧实现的三个实际引擎用例、14 条失败断言，包含嵌套攻击在重置、切房与敌人中断时漏清理；只摘录该 suite，不是完整 GUT 日志。
- [原失败 JUnit](original.xml)：完整原始 XML；同一失败 case 的其他断言需结合上述日志片段读取。
- [main JUnit](main.xml)：实际 main `6fe3492` 的原始 XML，171 tests / 3175 assertions，零失败、错误、跳过。
- [来源与哈希](provenance.json)：原报告及完整日志 SHA-256、摘录原始行号、main 报告摘要、源码哈希和已归档文件哈希。摘要经过字段选择，不能冒充原始完整 report.json。

交付来源为 [PR #17](https://github.com/gzaii-promax/Codename_Astra/pull/17) 和 [实际 main CI 37221178853](https://github.com/gzaii-promax/Codename_Astra/actions/runs/37221178853)。上述 XML 可用 `tools/read-junit.py` 独立读取；完整复验入口仍是 `node tools/check.mjs --scope game`，规则见 [测试协议](../../testing.md)。
