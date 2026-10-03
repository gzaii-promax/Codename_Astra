# 独立设计验收数据

`design-v1.json` 只供测试读取，禁止生产代码引用。数据由 agent 手工维护并通过用户设计指令/PR 审查变更，不能从生产常量、场景或运行结果自动生成。

- `schema_version`：读取格式版本；`baseline_id`：稳定基线身份。
- `source_commit`、`verified_against_commit`、`authority`：初始来源提交、本轮重新核对的提交与规则/布局的证据边界；样例坐标不代表手感已获用户验收。
- `unit_scale`：像素尺寸、速度（px/s）、跳高与已有离散采样容差、物理采样频率。
- `training`：正式训练场的独立布局预期，以及测试起跳夹具的位置。
- `map`：样例身份/路由、房间矩形、入口脚底、台阶落地/跨越采样点、调试覆盖层矩形和相机/HUD 布局；所有 `*_px` 使用像素，矩形按 `[x,y,width,height]`。`step_sample.clear_x_px` 是角色越过台阶时的既有判定阈值，不能把它与 `left_px` 的差误当台阶本体宽度。

`tests/support/design_baseline.gd` 只解析这份 JSON 和转换向量/矩形。两套 GUT 用例保留机制断言与精确设计检查；完整 game 快照和哈希包含这些文件。失败与有意调参的完整步骤见 [设计基线流程](../../docs/design-baselines.md)。

## Schema 1 字段契约

JSON 必须是对象，`schema_version` 为 `1`；`baseline_id` 为 `prototype-design-v1`。字段缺失、JSON 无法读取/解析、错误类型或不支持的 schema 都属于测试基线配置错误，不能使用生产值补齐或当作跳过测试的理由。`source_commit` 保留初始设计出处，`verified_against_commit` 记录本轮重新核对的源码提交；后续批准变更在 `docs/design-baselines.md` 留持久记录。所有数字须有限，不接受 null、NaN 或 Infinity。

| 字段 | 含义、形状与约束 |
| --- | --- |
| `authority` / `review_policy` | 规则出处与证据边界 / 人工审核政策；不把交付样例坐标写成已验收手感 |
| `unit_scale.unit_px` / `body_size_px` | 正的 px/U / `[width,height]` 像素判定框，两个尺寸为正 |
| `unit_scale.walk_speed_px_per_second` | 正的基础步行速度，单位 px/s |
| `unit_scale.short_jump_px` / `long_jump_px` | 相对起跳脚底的正像素高度；长跳严格高于短跳 |
| `unit_scale.jump_tolerance_px` / `physics_ticks_per_second` | 原离散采样误差（非负 px）/ 正整数物理频率；变化需解释采样证据，不能用扩大容差掩盖机制故障 |
| `training.jump_origin_px` / `dummy_feet_px` | `[x,y]` 脚底像素位置；前者也供受控起跳夹具使用 |
| `training.envelope_px` / `solid_rects_px` | `[x,y,width,height]` 外框 / 按正式地形节点名索引的矩形；宽高为正 |
| `map.initial_room` / `initial_entrance` / `routes` | 样例初始身份和入口 / 非空的有向路由列表，每项为 `[source_room,exit,target_room,entrance]` |
| `map.camera_zoom` / `hud_reserved_height_px` | 两个正 zoom 分量 / 非负像素保留高度 |
| `map.rooms` | 按 room_id 索引的对象；各房包含正面积 `bounds_px` 与按 entrance_id 索引的 `entrances_px` |
| `map.rooms.*.step_sample` | 可选台阶夹具采样：`left_px` 左侧起跳基准、`top_y_px` 顶面、`clear_x_px` 跨越判定位置，均为像素；不是台阶物体宽度定义 |
| `map.rooms.*.overlay_rects_px` | 可选调试覆盖层样例矩形，按测试名称索引，宽高为正 |

生产节点和 Resource 仍保存运行配置，这份 JSON 只保存独立验收预期。生产文件不得引用 `tests/baselines/` 或 `tests/support/design_baseline.gd`。未来设计变更按用户具体指令逐字段手工更新，不需要对同一指令重复索取批准；不能扫描生产文件后自动重写期望值。
