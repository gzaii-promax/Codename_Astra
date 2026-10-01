# 多语言独立验收数据

- `languages.json` 指定 en 为默认，en/ja/zh_CN 三语与额外 fr；catalog 路径故意使用相对 manifest 的路径，font 留空以隔离数据行为和字体资源。
- 译文由测试作者手写。日本语目录缺 `fallback.absent`、`fallback.empty` 为空、`fallback.whitespace` 只含空白，分别要求回退到 en。未知 key 返回原 key；未提供的命名参数保留占位符。
- `languages_broken_catalog.json` 的 de 指向语法损坏的 `invalid_catalog.json`，要求默认目录有效时仍可初始化并回退，保留诊断且无非预期引擎错误。
- `invalid_manifest.json` 是可解析但 schema 不合法的对象，必须拒绝初始化。
- 损坏设置由测试写入临时 ConfigFile 路径，要求不覆盖原内容。持久化测试也验证其它配置段保留。
- 生产目录、字体和真实界面由正式资源测试验证；本 fixture 不用来声称正式翻译内容、美术或手感已经审核。
