# ERR-20261005-ENGINEERING-CONTRACTS — 配置、依赖与同步事件边界

- 状态：resolved（本地组合完整回归通过；冻结/CI 交付证据另核对）
- channel：user_feedback / automated_test
- 日期：2026-10-05（报告 run_id 按 UTC 为 2026-10-04）
- 起点：main `037e076ac1faabaa9c3c7e27ecb369cb3090bcb7`
- 范围：优先修复调查确认的输入覆盖、战斗隐式绑定、效果层级清理、动作同步再入、共享命中结果、非法配置。HUD 仅登记工程债，数值、地图结构和玩法不改。

## 原问题与失败证据

工作目录为本轮独立 worktree；固定 Godot 4.7.2、GUT 9.7.1，运行 `node tools/check.mjs --scope game`，报告保留原始日志、JUnit 及实际源码快照/哈希。

| 问题 | 原失败 run_id | 已观察的差异 |
| --- | --- | --- |
| 自定义/空输入绑定被补回默认；同名动作再入重复执行/旧 tick 消耗新动作；非法跳跃非有限值 | `20261004T170222021Z-5803d88f` | 原有138项通过，新增6项全部失败，144 tests / 2936 assertions |
| 来源猜节点名；错误受击路径仍接受；前序 listener 再入使结果与统计丢失 | `20261004T170148384Z-addfe2c2` | 原有138项通过，新增4项全部失败，142 tests / 2928 assertions；原始日志8条失败断言 |
| 嵌套效果在训练 reset、切房及敌人中断中漏清理 | `20261004T170113124Z-74fb9729` | 原有138项通过，新增3项全部失败，141 tests / 2934 assertions；原始日志14条失败断言 |

诊断标签只用于定位，不从 classification 推断原因；GUT XML 可能只保留首条失败，实际原始日志也必须读取。旧 linter/案例通过不足以覆盖这些结构和再入边界。

## 修复契约

输入默认写入编辑器 Input Map，运行只补缺失 action。来源仅通过 Combatant 或 get_combatant provider 解析，缓存合法已发射攻击的身份/阵营；环境伤害显式 set_environment。受击组件绑定必须有效，无生命目标显式启用；validate/last_error/编辑器 warning 提供诊断。hit_resolved 携带本次 amount，稻草人不读取共享 last_damage 拼接统计。

效果显式登记世界、来源和中断策略，使用弱登记避免强制延长节点生命，处理 nested/reparent/暂时离树及多世界隔离；清理同帧禁用处理并队列释放，命中回调清理后停止其余 contacts。动作使用代次隔离同步 reset/cancel/restart，旧栈停止执行。移动/视觉校验有限值与分母，保存非法值时拒绝相关行为，合法零值与重置后配置保留。

## 实现过程中发现的边界

- 战斗 fixture 原先隐式无生命/无来源用法必须显式迁移，保留原伤害/状态断言；遗漏地图两处环境 fixture 的一次报告仍保留，修正后完整子分支验收通过。
- 效果首个命中 callback 清理后，原扫描循环继续伤害第二目标；未加 guard 的反例报告保留，最终按每 contact 检查取消状态。
- 弱登记第一次读取缺失 meta 的 get_meta(key, null) 在引擎记录 ERROR；按 has_meta 检查后读取，不放宽日志/错误验收。

- 组合首轮 `20261004T171532120Z-98ff4fe4`：171项中170通过，仅新增键盘 device 匹配断言失败。测试错误地假定 keyboard device=0；固定 Godot 4.7.2 使用 `InputEvent.DEVICE_ID_KEYBOARD=16`（[官方4.7文档](https://docs.godotengine.org/en/4.7/classes/class_inputevent.html#class-inputevent-constant-device-id-keyboard)）。修正测试使用引擎公开键盘常量，保留引擎原生保存的绑定，不为错误预期改变正式配置。

- 冻结 `1c713267…` 的独立171项验收与PR CI均通过，但额外独立探针发现 get_combatant() 返回42时仍产生两条 SCRIPT ERROR，进程退出0且 is_valid=false。这说明退出码/既有绿灯不能覆盖所有错误类型；证据保存在 artifacts/engineering-safety/independent-initial/nonobject-provider.json。进一步反例确认，已释放的 Node/Combatant 引用直接使用 is 判断也会报错；必须先检查 Variant 是对象，再检查实例有效性，最后判断 Combatant 类型并转换，并扩展原有 broken-provider 用例；不新增case名称，不减少原断言。新head再次独立完整复验及CI，不能沿用旧head绿灯。

provider 补修子分支 game `20261004T172817678Z-f96af722` 为14/14、148 tests / 3014 assertions，零失败/错误/跳过；同一既有case新增25条边界断言，原数字/释放引用探针复跑均 stderr 空。补修仅涉及HitData和该case；组合后仍171个case，最终head的完整证据单独核对。

## 结果与证据入口

组合 game `20261004T171802796Z-b961eb71`：14/14 checks，171 tests / 3150 assertions，零 failures/errors/skipped；179项哈希中178项与当前文件一致，之后仅 tests/README.md 更新旧计数文字，业务/测试源码保持一致。原始 GUT/import/startup 日志无脚本/引擎错误。toolchain `20261004T170045565Z-80a78159` 为22/22，Node44/44；实际 worktree 正常编辑器 headless import 退出0，无引擎错误。冻结提交增加引擎生成的 design_baseline.gd.uid，最终完整文件集合由独立复验和CI核对。

组合源码、冻结独立验证与最终 PR/main CI 报告在本轮 `artifacts/engineering-safety/` 交接中记录；尚未完成的验证不能写成通过。临时 HUD 的可编辑性/职责集中仍是 [ui/README.md](../../ui/README.md) 工程债，用户手感保持独立待验收。
