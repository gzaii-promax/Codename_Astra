# Ember Trial — 房间地图、心容器战斗与多语言原型

一个 Godot 4.7.2 / GDScript 的 2D 横版灰盒原型，暂用内部名称 Ember Trial。启动进入 3 房间地图，菜单可进入原战斗训练场；角色静态占位图可替换。

## 运行

双击项目中的 `Play.command`，或在此目录执行：

```sh
node tools/play.mjs
```

入口使用 `.tools/` 中已验证的稳定版，不使用系统里现有的开发版。也可以用该稳定版编辑器导入 `project.godot`。当前运行环境依赖本机已准备的 `.tools/` 与 `/usr/local/bin/node`；这是本地可玩的工程，尚未打包成独立发行应用。

开发多项任务时，每个会话使用独立 worktree 和功能分支；工具准备、编辑器启动及合并规则见 [多会话开发](docs/worktrees.md)。

## 操作

| 操作 | 按键 |
| --- | --- |
| 左右移动 | A / D 或 ← / → |
| 跳跃 | 空格、W 或 ↑；短按低跳，长按高跳 |
| 普通攻击 | J |
| 火球术 | K |
| 重置双方生命、位置、目标与冷却 | R |
| 切换火球 Lv.1/2，比较前摇 | F2（调试） |
| 暂停菜单 / 返回 | Esc，或 HUD 的菜单按钮 |

靠近稻草人按 J 测近战，远处按 K 测火球。主角最大 3 心，普攻伤害 0.5 心、火球伤害 1 心；一颗完整心能承受两次半心伤害。稻草人有 10 个心容器，归零立即回满，屏幕命中与累计伤害统计继续保留，训练重置才清零。火球 Lv.1 前摇 0.5 s，Lv.2 为 0.2 s，伤害均 1 心。

训练场右侧的红色敌人固定面朝左，每 1.5 秒尝试近战，前摇 0.3 秒、每击 0.5 心，不追踪或移动。主角与敌人各有 3 个心容器，头顶显示完整、半颗和空心；主角正伤害后有 0.5 秒受击保护，其他角色默认零秒；双方默认零血死亡，死亡后按 R 或菜单重置即可重新试玩。允许自伤或友伤的攻击直接按配置心数扣除，当前不计算旧增伤、减伤或类型抗性。

菜单可选择简体中文、English、日本語；语言保存到用户设置，下次启动恢复。菜单中的帮助包含操作与技能说明，长文本可滚动。新增语言、自定义译文、字体与回退规则见 [localization/README.md](localization/README.md)。

## 工程入口

地图关系为 A ↔ B ↔ C，C 中央黄色通道单向回 A。进入蓝色出口即可切房；有台阶时用当前跳跃登上。地图 R 回 A 并清空本次探索，F3/F4/F5 跳至 A/B/C，F6 显示碰撞；正常切房保留生命、技能等级与剩余冷却。地图没有磁盘存档，切出再返回也开始新探索。房间在 Godot 选中 Terrain 编辑地形，在入口/出口节点编辑标记，在 sample_world.tres 编辑连接；见 [地图契约](docs/map-system.md)、[房间编辑](world/rooms/README.md) 和 [连接配置](world/maps/README.md)。

开发规则/模块索引见 AGENTS.md；第一版基线见 docs/first-version.md；多语言范围见 docs/localization-v2.md；生命与定时敌人范围见 docs/health-combat-v3.md；心容器重设计范围见 [docs/heart-health-v5.md](docs/heart-health-v5.md)；主分支整合见 [docs/integration-main.md](docs/integration-main.md)；实际验证和遗留见 docs/status.md。测试与错误协议见 docs/testing.md、docs/errors/README.md。

统一尺度初值见 [docs/scale-movement-v4.md](docs/scale-movement-v4.md)：1 U=16 px，主角与稻草人受击框 16×32 px，训练场及 A/C 外框 512×256 px，B 为 768×256 px，基础移动 56 px/s，无遮挡短至长跳上升 16–40 px。公共单位职责在 [shared/README.md](shared/README.md)。

```sh
node tools/check.mjs --scope game
node tools/check.mjs --scope toolchain
```

报告在 `artifacts/test-runs/latest.json` 指向的目录。macOS 文件系统沙箱限制可能阻止 Godot/Python 读取工程或写引擎用户缓存；agent 应按已记录 ENV-0004 在同一入口使用授权环境复跑，不削弱断言。

## 当前限制

当前没有完整技能树、互动道具、敌人决策 AI、存档、音乐或正式场景。反弹只提供归属切换接口，击倒协助/定时恢复只提供可复用接口，未新增反弹技能、友方交互单位或自动复活玩法。角色为单帧图片，移动偏移/施法光点/攻击轨迹是程序反馈。正式美术与用户手感验收仍待后续反馈，自动通过不能代替试玩判断。
