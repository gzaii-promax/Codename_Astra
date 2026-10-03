# ERR-20261003-BASELINE-WALK-FIXTURE：设计变更对照碰到恒速测试障碍

- status: resolved
- channel: automated_test
- category: test
- first_seen: 2026-10-03
- checkout: `/private/tmp/astra-baseline-fix-01a10240`
- code_state: `c3908038490d381543e0b033d26d9844bf171cdb` 加本轮基线拆分，精确源码见各报告 `files_sha256`。
- related_record: [SPEED-STEP-SAMPLING](ERR-20261002-SPEED-STEP-SAMPLING.md)，同为速度变化影响测试操作，但本次位置与 case 不同。

## 复现与原始证据

新基线流程生成后立即执行 `node tools/check.mjs --scope game`，首轮 `20261003T143548901Z-75fe7953` 14/14 检查、134 tests / 2844 assertions，0 failures/errors/skipped。随后在忽略的独立实验快照执行 `python3 artifacts/baseline-contrast/run_contrast.py`；实验只把该快照主角速度从 56 改成 64 px/s，并手工把该快照基线对应字段改成 64，正式生产值与正式基线不改。

四阶段首轮 `20261003T143845Z-426b5a17` 的第三阶段仍 exit 1：一步恒速位移为 `59.6763916015625 px`，期望 `64 ± 0.05 px`。原始证据在 `artifacts/baseline-contrast/20261003T143845Z-426b5a17/3-experiment-baseline-reviewed/` 的 `report.json`、`game.xml`、`junit.json` 和 `gut.log`。日志还显示机制积分失败、样本结束速度为 `3.2000000476837158 px/s`，而 JUnit `<failure>` 只保留该 case 第一条失败，不能据 XML 声称只有设计差异。

## 原因与修复尝试

固定工具链已通过 22/22，实验 import 均 exit 0 且没有引擎错误，排除依赖或导入失败。正式训练场 `Step` 左侧为 x=352，身体中心达到 x≈344 即碰墙；64 px/s 的样本终点中心 x≈343.94，采样被碰撞/重新加速干扰。属于测试夹具未与恒速采样隔离，不能通过改回 56、扩大 0.05 容差或删除位移机制断言修复。

修复只在恒速测试创建的训练场实例中释放 `Step`、`Platform`，保留真实地面和边界墙。正式场景及其全部布局数值不改；其他 case 继续检查正式几何、墙阻挡、实际台阶落地/跨越、跳跃和状态转换。重新运行四阶段对照与完整 game，保留首轮故意失败及意外失败报告。

## 当前结论

修复后的真实四阶段 `20261003T144048Z-53866b54` 全部满足各自预期：原设计通过；仅改实验速度为 64 的阶段真实失败且 raw log 只有设计差异；仅手工把实验独立预期改为 64 后通过；禁用实验物理位移后真实失败，raw log 同时保留机制与设计失败。四阶段底层退出码为 `0/1/0/1`，每阶段执行同一个实际 GUT case、13 assertions，0 errors/skipped，import 和 GUT 均无引擎错误或超时。其 aggregate `pass` 只代表检测能力对照符合预期，不能代替完整游戏验收。

最终正式源码完整 game `20261003T144155106Z-3ae17b06`：14/14 检查、134 tests / 2845 assertions，0 failures/errors/skipped；原始报告、XML 和全部 logs 已读取，166 项源码哈希与最终工作文件一致。正式生产目录 diff 为空，基线仍为 56 px/s、16/40 px 跳高与原布局；用户手感仍待单独反馈。技术夹具问题关闭，GUT XML首条限制作为报告阅读约束继续保留。
