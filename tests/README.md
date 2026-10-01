# 首版自动验收模块

## Agent 开始与结束步骤

1. 读取 `AGENTS.md`、`docs/testing.md`、`tests/manifest.json` 和 `docs/errors/README.md`，再检查最新报告的 scope 与代码 hash。
2. 项目根目录执行 `node tools/check.mjs --scope game`；本机按 ENV-0004 使用获准的沙箱外环境。新建或修改测试流程后立即执行。
3. 读取 stdout JSON 的 `report_path`，核对 `expected_check_ids` 全部执行、`tests/manifest.json` 的全部预期测试均出现，且 JUnit 没有失败/错误/跳过；核对源码 hash、原始日志、Git 状态和报告时间。当前名册保留既有 34 项战斗用例和 19 项多语言/界面用例，新增 26 项生命/阵营/敌人验收，共 79 项。
4. 失败先查公共错误目录，分类依赖/环境/配置/代码/测试问题；记录假设与修复证据，再复跑。交接提供 `run_id`、状态、报告路径、原始日志与开放错误。

## 职责与接口

| 文件 | 内容 | 采用的实际接口 |
| --- | --- | --- |
| `game/test_actions.gd` | 等级/配置合法性、阶段边界、单次激活、零时长、大 tick、冷却、取消、不同技能绑定与重置 | `SkillDefinition`、`PhasePolicy`、`ActionController` |
| `game/test_combat_physics.gd` | 真正物理世界中的扫掠命中、左右方向、遮挡、寿命/射程、近战范围/单次命中、接收器校验 | `Fireball`、`MeleeStrike`、`SkillExecutors`、`DamageReceiver` |
| `game/test_player_scene.gd` | 主场景节点/输入、落地/移动/跳跃/墙体、主角动作命中真实稻草人、等级切换、训练重置、逆向输入/重置当帧/贴左右墙发射回归 | `TrainingArena`、`PlayerCharacter`、`TrainingDummy` |
| `game/test_localization_service.gd` | 独立设置恢复、错误容错、缺译回退、命名参数、第四语言、完整三语语料和字体 glyph 覆盖 | `LocalizationService`、ConfigFile、FontFile |
| `game/test_localization_ui.gd` | 实际三语 HUD/菜单/说明、picker 保存、暂停/继续/重置/帮助/Esc、字体与布局测量 | 正式 `TrainingHUD` 与引擎 Control / Font |
| `game/test_health_combat.gd` | 四种目标规则、三阵营与本人矩阵、减伤加算、归属转移、死亡/击倒/恢复、技能配置传递 | `Combatant`、`HitData`、`DamageReceiver`、`SkillDefinition`、`SkillExecutors` |
| `game/test_health_scene.gd` | 真实敌人攻击、双方生命与血条、受击阶段中断、重置、暂停和三语显示 | `TrainingArena`、`PlayerCharacter`、`PeriodicEnemy`、`HealthBar` |
| `fixtures/localization/` | 手写独立验收数据：默认 en、三语局部译文、新增 fr、损坏目录与无效清单 | 独立 JSON 数据，不从业务实现自动复制预期 |
| `manifest.json` | 审核后的完整预期 case 名称，拒绝空执行或漏执行 | runner 和 JUnit 对照 |

## 验收基线与可证明范围

- 首版普通攻击 20 伤害；火球术 35 伤害，一级前摇 0.5 秒、二级 0.2 秒。升级不改变伤害；这些是首版可调整的技术基线。
- 动作属性测试使用公开 API 驱动受控时间；物理测试使用实际引擎 physics frames，覆盖超高速火球越过目标、墙体先于目标、每次近战窗口至多命中一次。
- Player 集成加载正式场景，并额外通过 Input.action_press 验证输入映射到实际移动。测试只断言基础可操作性、阻挡、受击与时序，不判断好不好玩。
- fixture target 通过真实 DamageReceiver 和 CollisionShape2D 接收攻击；另外真实 TrainingDummy 在正式场景中验证统计与伤害来源。不是用伪造命中替代物理命中。
- 多语言用例依据用户授权范围（`docs/localization-v2.md`）确定。fixture 的缺条目、空/空白译文、缺命名参数都有手写期望；只在生产三语目录要求相同参数集合与非空完整译文，扩展语言允许按约定回退。
- 独立服务用真实临时 ConfigFile 再构造新实例，验证保存恢复、其他配置段保留，以及损坏数据不被覆盖。同步解析前后的 `Engine.print_error_messages` 必须保持原值。
- 完整生产语料逐字符调用 `Font.has_char`；并要求实际字体为 `FontFile` 且 `allow_system_fallback=false`，避免依靠本机字体掩盖素材缺字。UI 另检查每种语言实际采用的字体资源。
- 实际界面从正式场景创建，通过真实按钮和语言 picker 信号驱动交互。GUT 运行使用 runner 的每轮 `ASTRA_SETTINGS_PATH`；独立服务另用临时设置路径，不改用户偏好。测试期间暂停 scene tree，测试节点保持 process always 并在结束时恢复。
- 布局使用真实 Control 全局矩形和 Font 多行测量验证三语 HUD/菜单/帮助面板不越出 viewport、正文不被控件裁剪；帮助正文允许位于可滚动容器内。尺寸误差仅容许 1 像素。
- 新服务实例恢复不等同操作系统进程重启。`tests/probes/` 由主 agent 维护，公共 runner 的 `restart-write` / `restart-read` 使用同一独立文件启动两个 Godot 进程，并由报告提供恢复标记；不要把 GUT 用例数量与外部进程检查混计。
- 当前自动检查不判断翻译风格、像素视觉质量、动画观感、音效、实际键盘硬件、导出包、跨平台兼容或手感。主 agent 另做有画面的三语截图核查；这些不由 headless 成功推定。

## 生命与阵营验收

- 默认目标规则为仅不同阵营，规则 2 的自伤减伤和规则 3 的同阵营减伤默认 50%，零血量行为默认死亡。矩阵逐一覆盖友方、敌方、中立为来源，本人、同阵营其他单位和其他两阵营为目标；中立没有额外免伤。
- 用户给出的独立数值基线：100 点火焰伤害、20% 火焰抗性、50% 自伤减伤，最终扣 30 点生命；同阵营减伤与通用/类型减伤同样加算。总减伤超过 100% 时最终伤害为 0，不转为治疗。
- 目标资格不通过或无敌时不发伤害事件。实际来源重绑定后立即以新归属判定；来源消失仍保留最后阵营身份，不自动成为环境伤害。环境必须显式使用 ALL。
- 击倒单位不能补刀；剧情死亡可绕过无敌与击倒配置。友方协助起身必须给正数生命，恢复上限为最大生命；默认没有定时恢复，只有明确安排时计时，死亡会取消恢复。
- 正式训练场通过真实物理近战验证敌人满间隔后开始攻击、重复扣主角生命且不追击；玩家既有近战和火球能伤害并击杀敌人。死亡主角不能控制或开技能，死亡敌人停止攻击；训练重置恢复双方生命/状态并重新计时。
- 非致命受击在允许中断的 ACTIVE 阶段取消真实近战窗口，并保留技能冷却；不可中断阶段仍继续攻击。进入原攻击范围的目标不能被已撤销窗口命中。
- 真实训练稻草人的累计伤害必须记录结算后的伤害：中立来源规则 3 的原始 10 点伤害计入 5 点，原始 HitData.damage 仍为 10，避免统计和真实生命扣除规则不一致。
- 暂停菜单冻结敌人动作和可选恢复计时。双方血条的填充、数值、死亡标记和重置由真实场景验证；三语文本参数、字形和视口边界使用实际字体测量。
- 双方相距 50 像素的近战位置还测量血条条框、字体 ascent/height 和描边合并后的完整绘制范围；三语正常、死亡与击倒长标签不得彼此相交。固定场景通过错开血条高度避免贴近时重叠，不宣称支持任意密集单位自动排布。
- `probes/health_combat_visual.gd` 在图形引擎延后加载正式场景，捕获三语受伤、敌人死亡、主角击倒共九张 viewport。截图报告只证明保存完成，需查看全部图片并单独记录视觉审核；不将截图数量计入 GUT 用例。

## 扩展与维护

- 新行为测试应来自需求和可观察结果；新增不同技能的同控制器用例用于验证现有机制的组合能力。
- 修改技能规则时维护技能模块文档和相关测试预期。新增 case 手动维护 manifest；不要用重新生成清单消除漏测警报。
- 超时、故意失败与报告读取能力由工具链自检验证，不混入游戏通过数量。游戏正常验收不接受预期之外的失败或超时。
