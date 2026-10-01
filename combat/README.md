# 公共战斗模块

## 职责和边界

此模块定义攻击结果与可受击接口，不依赖主角、稻草人或某种技能。技能负责产生 `HitData`，`DamageReceiver` 接受有效攻击并发出事件；生命、统计、反馈由所属目标负责。首版没有敌人 AI、抗性、暴击、生命系统和击退响应，`knockback` 是明确保留的参数。

## 文件与接口

- `hit_data.gd`：`HitData extends RefCounted`，一次命中的数据。`source` 为发动者，`skill_id` 是技能标识；`damage` 默认 `0`；`damage_type` 默认 `physical`；`origin` 默认 `(0, 0)`；`direction` 默认右；`knockback` 默认 `0`，单位为像素/秒。伤害与击退必须有限且非负，位置与方向必须为有限向量。
- `damage_receiver.gd`：`DamageReceiver extends Area2D`。目标提供 `CollisionShape2D`。`receive_hit(hit: HitData) -> bool` 表示是否接受本次命中；有效且启用时发出 `hit_received(hit)`。`enabled` 默认 `true`；无效、空的攻击和攻击者自身/子节点拒绝接收。关闭 receiver 不会发出事件。

碰撞位约定：场景实体 `1`，主角 `2`，受击区域 `4`，火球 `8`；稻草人实体可使用 `16`。这些数字是 bitmask 值。Receiver 默认 `collision_layer = 4`、`collision_mask = 0`、`monitoring = false`、`monitorable = true`；由攻击查询接触目标，不使用 receiver 的主动监测。

## 扩展方法

新增目标时为其添加 receiver 和碰撞形状，并连接 `hit_received`。目标可以从统一攻击数据更新生命、累计伤害或播放反馈，技能不需要知道目标类型。新增命中字段须同时明确默认值、单位、校验以及哪些接收者使用它，修改此文档并回归已有攻击。

## 验证与当前状态

固定测试入口与证据读取方法见 `../docs/testing.md`。实际结果以 `../artifacts/test-runs/latest.json` 指向的本轮报告为准，模块代码落盘不能视为测试通过。自动测试应覆盖合法/非法数据、禁用 receiver、自伤拒绝、近战与火球对相同接口造成一次有效命中。

玩法手感由用户反馈。首版 `DamageReceiver` 只报告命中，不自行扣血或施加击退。
