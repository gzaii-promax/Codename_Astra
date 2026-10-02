# ERR-20261002-SPEED-STEP-SAMPLING：提速后台阶用例越过采样位置

- status: resolved
- channel: automated_test
- category: test
- first_seen: 2026-10-02
- run_id: `20261002T101149739Z-8e3800cd`
- checkout: `/private/tmp/astra-speed-01a0fc17`

用户要求基础速度从 24 改为 56 px/s。首次完整 game 134 tests 中唯一失败为 `test_map_player_jumps_onto_and_crosses_actual_corridor_and_hall_steps`；A/B 房间在固定等待52帧后各有落地和 y=224±0.1 两项失败。真实 x 分别为185.75697/217.75697，已经越过台阶右侧并开始下落，y=224.295257568。速度用例实测一秒55.9991455px，符合56±0.05px。

旧操作持续右移，提速后在采样前已经走下台阶，属于测试操作与目标位置不匹配。修复逐个真实物理帧观察位置，到达台阶左沿后停止横向输入，保留持键长跳并等待落地；随后继续右移验证走下。保持真实碰撞、落地、224/240±0.1高度与跨越位置要求，不放宽容差或修改业务物理。

复验命令为 `node tools/check.mjs --scope game`；最终 `20261002T101426979Z-f05abfa9` 14/14检查通过，134 tests / 2742 assertions，0 failures/errors/skipped；原失败项及所有回归通过，163项源码哈希一致。首次失败 report.json、game.xml、logs/gut.log 保留在该 checkout 的 `artifacts/test-runs/20261002T101149739Z-8e3800cd/`，交付前复制至主目录 `artifacts/speed-handoff/`。用户手感另行验收。
