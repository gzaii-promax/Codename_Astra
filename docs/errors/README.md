# 公共错误记录

## 入口与编号

- 所有验收错误与用户反馈统一在本目录查找；具体记录采用 `docs/errors/<ID>.md`。
- 错误编号稳定、不得复用。建议使用 `ERR-YYYYMMDD-<短标识>`，创建前检查是否已有同一问题。
- 最新测试证据通过 `artifacts/test-runs/latest.json` 定位；具体安装与测试状态见最新报告。
- 同一问题再次出现时追加复现记录并重新打开原记录；仅报错文字相同不能确认同一原因。

## 记录索引（2026-10-05）

以下状态按各记录正文核对；本轮工程契约修复的验证状态见最新记录。`MAIN-INTEGRATION` 只关闭缺少代码的技术问题，用户手感仍单独待反馈。resolved 不代表换环境后不会复发。新增、重开或关闭记录时同步本表，原始证据留在各记录中。

| 记录 | 状态 | 问题 |
| --- | --- | --- |
| [ERR-20261005-ENGINEERING-CONTRACTS](ERR-20261005-ENGINEERING-CONTRACTS.md) | investigating | 输入配置、隐式依赖、效果归属、signal 再入与有限值边界；组合验收进行中 |
| [ERR-20261003-GUT-BARE-FAILURE](ERR-20261003-GUT-BARE-FAILURE.md) | resolved | GUT 无冒号布尔断言漏读；真实日志32条失败复验与Node回归保留 |
| [ERR-20261003-PROTECTION-INSPECTOR](ERR-20261003-PROTECTION-INSPECTOR.md) | resolved | 主角初始化覆盖 Inspector 保存的保护时间；本轮重新整合并复验 |
| [ERR-20261003-PROTECTION-FIXTURE](ERR-20261003-PROTECTION-FIXTURE.md) | resolved | 真实配置回归夹具的错误 editable 声明与格式 |
| [ERR-20261003-BASELINE-WALK-FIXTURE](ERR-20261003-BASELINE-WALK-FIXTURE.md) | resolved | 提速实验撞到恒速采样障碍；JUnit 首条失败不能代表全部断言 |
| [ENV-0001](ENV-0001.md) | resolved | Xcode 许可阻止系统 Git 和 Python 执行 |
| [ENV-0002](ENV-0002.md) | resolved | 沙箱网络限制导致官方域名无法解析 |
| [ENV-0003](ENV-0003.md) | resolved | 沙箱内 Godot 签名检查失败 |
| [ENV-0004](ENV-0004.md) | resolved | 工具链自检受沙箱文件权限限制 |
| [ENV-0005](ENV-0005.md) | resolved | GitHub connector 与本机 CLI 的仓库权限不同 |
| [ERR-20261001-ACTION-FACING-RESET](ERR-20261001-ACTION-FACING-RESET.md) | resolved | 动作朝向与重置效果的集成边界 |
| [ERR-20261001-FIREBALL-SPAWN-WALL](ERR-20261001-FIREBALL-SPAWN-WALL.md) | resolved | 火球释放偏移跳过薄墙 |
| [ERR-20261001-GAME-NOT-READY](ERR-20261001-GAME-NOT-READY.md) | resolved | 首版测试准备期间项目与测试契约未齐备 |
| [ERR-20261001-GIT-BLOB-BUFFER](ERR-20261001-GIT-BLOB-BUFFER.md) | resolved | Git 交付核对缓冲读取大字体失败 |
| [ERR-20261001-GIT-BOOTSTRAP](ERR-20261001-GIT-BOOTSTRAP.md) | resolved | commit-tree 消息文件参数不受支持 |
| [ERR-20261001-HEALTH-BAR-OVERLAP](ERR-20261001-HEALTH-BAR-OVERLAP.md) | resolved | 近战距离的生命与状态文本重叠 |
| [ERR-20261001-HEALTH-TEST-FIXTURE](ERR-20261001-HEALTH-TEST-FIXTURE.md) | resolved | 独立生命测试清理未初始化输入 |
| [ERR-20261001-I18N-GRAPHICS-PROBE](ERR-20261001-I18N-GRAPHICS-PROBE.md) | resolved | 独立图形探针提前引用 autoload |
| [ERR-20261001-LOCALIZATION-HUD-OVERFLOW](ERR-20261001-LOCALIZATION-HUD-OVERFLOW.md) | resolved | 英语切换后 HUD 容器高度溢出 |
| [ERR-20261001-TEST-SCENE-PARENT](ERR-20261001-TEST-SCENE-PARENT.md) | resolved | 测试 fixture 不能成为 current_scene |
| [ERR-20261002-CI-PYTHON](ERR-20261002-CI-PYTHON.md) | resolved | 托管 runner 缺少固定 Python 安装包 |
| [ERR-20261002-HEART-READOUT-OVERLAP](ERR-20261002-HEART-READOUT-OVERLAP.md) | resolved | 击倒文本覆盖第三单位心容器 |
| [ERR-20261002-HEART-TEST-FIXTURE](ERR-20261002-HEART-TEST-FIXTURE.md) | resolved | 半心验收测试解析与HUD刷新时机 |
| [ERR-20261002-MAIN-INTEGRATION](ERR-20261002-MAIN-INTEGRATION.md) | resolved | 主分支缺少已交付的心形与跳跃更新 |
| [ERR-20261002-MAP-CI](ERR-20261002-MAP-CI.md) | resolved | 受击保护精确物理帧用例在 CI 采样越界 |
| [ERR-20261002-MAP-VALIDATION](ERR-20261002-MAP-VALIDATION.md) | resolved | 地图首版完整验收超时与 HUD 切换错误 |
| [ERR-20261002-SCALE-TEST-SAMPLING](ERR-20261002-SCALE-TEST-SAMPLING.md) | resolved | 尺度测试的物理帧采样与等待条件 |
| [ERR-20261002-SPEED-STEP-SAMPLING](ERR-20261002-SPEED-STEP-SAMPLING.md) | resolved | 提速后台阶用例越过采样位置 |
| [ERR-20261002-WORKSPACE-CLASS-CACHE](ERR-20261002-WORKSPACE-CLASS-CACHE.md) | resolved | 工作区旧类缓存导致直接启动失败 |
| [ERR-20261002-WORKTREE-TEST-FIXTURE](ERR-20261002-WORKTREE-TEST-FIXTURE.md) | resolved | 临时路径与清理夹具 |

可用 `rg -n "status:|状态：|channel:|原因" docs/errors` 按状态、来源与原因检索；先读相同触发条件的记录再复跑。

## 每条记录的必需内容

| 字段 | 内容 |
| --- | --- |
| ID / 标题 / 状态 | 固定编号、简要问题；`open`、`investigating`、`blocked`、`resolved` 或 `reopened` |
| channel | `automated_test` 或 `user_feedback`；新增来源可追加，各渠道原始证据分别保留 |
| 首次与再次出现 | 时间、测试 `run_id`、对应提交或明确的代码状态 |
| 复现上下文 | 工作目录、工具路径/版本、命令或操作步骤、触发条件 |
| 原始证据 | 原始报错、退出码、报告/日志路径；用户反馈保留原意 |
| 预期与实际 | 可观察的差异、影响范围及尚未确定的内容 |
| 原因判断 | 依赖/环境/资源或配置/代码/测试的证据；假设与已确认原因分开 |
| 修复尝试 | 每次假设、改动、复跑方式、修复前后结果和关联运行 |
| 当前结论 | 开放事项、阻塞条件或修复验证；涉及手感时保留用户判断 |

## 处理顺序

1. 查本目录已有记录，比较报错、操作、调用位置、工具版本及代码状态。
2. 判断是否缺依赖或存在环境问题，再检查资源/配置、代码及测试本身；将依据写入记录。
3. 实施有明确假设的修复，立即执行相关测试，关联新的报告与日志。
4. 比较前后证据。报错相同则继续检查原因与假设；报错变化则判断原问题是否消失、是否暴露后续问题或引入回归，再决定下一步。
5. 原失败项、受影响回归与本轮必要检查通过，且原问题不再复现后，按证据关闭技术问题。无法复现不等于已经修复；用户手感问题不能仅凭自动测试关闭。
6. 未完成时记录剩余问题与阻塞影响，向主 agent/用户交接；不得把尝试过修复写成验证完成。
