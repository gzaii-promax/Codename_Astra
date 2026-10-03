# 独立设计验收数据

`design-v1.json` 只供测试读取，禁止生产代码引用。数据由 agent 手工维护并通过用户设计指令/PR 审查变更，不能从生产常量、场景或运行结果自动生成。

- `schema_version`：读取格式版本；`baseline_id`：稳定基线身份。
- `source_commit`、`authority`：初始来源提交与规则/布局的证据边界；样例坐标不代表手感已获用户验收。
- `unit_scale`：像素尺寸、速度（px/s）、跳高与已有离散采样容差、物理采样频率。
- `training`：正式训练场的独立布局预期，以及测试起跳夹具的位置。
- `map`：样例身份/路由、房间矩形、入口脚底、台阶落地/跨越采样点、调试覆盖层矩形和相机/HUD 布局；所有 `*_px` 使用像素，矩形按 `[x,y,width,height]`。`step_sample.clear_x_px` 是角色越过台阶时的既有判定阈值，不能把它与 `left_px` 的差误当台阶本体宽度。

`tests/support/design_baseline.gd` 只解析这份 JSON 和转换向量/矩形。两套 GUT 用例保留机制断言与精确设计检查；完整 game 快照和哈希包含这些文件。失败与有意调参的完整步骤见 [设计基线流程](../../docs/design-baselines.md)。
