# Ember Trial — 战斗与多语言原型

一个 Godot 4.7.2 / GDScript 的 2D 横版训练房间，暂用内部名称 Ember Trial。角色静态占位图可替换，地图是 gray box。

## 运行

双击项目中的 `Play.command`，或在此目录执行：

```sh
node tools/play.mjs
```

入口使用 `.tools/` 中已验证的稳定版，不使用系统里现有的开发版。也可以用该稳定版编辑器导入 `project.godot`。当前运行环境依赖本机已准备的 `.tools/` 与 `/usr/local/bin/node`；这是本地可玩的工程，尚未打包成独立发行应用。

## 操作

| 操作 | 按键 |
| --- | --- |
| 左右移动 | A / D 或 ← / → |
| 跳跃 | 空格、W 或 ↑ |
| 普通攻击 | J |
| 火球术 | K |
| 重置角色、目标与冷却 | R |
| 切换火球 Lv.1/2，比较前摇 | F2（调试） |
| 暂停菜单 / 返回 | Esc，或 HUD 的菜单按钮 |

靠近稻草人按 J 测近战，远处按 K 测火球。目标无限生命，屏幕显示命中与累计伤害。火球 Lv.1 前摇 0.5 s，Lv.2 为 0.2 s，伤害均 35；普攻伤害 20。当前数值均为待试玩反馈的初值。

菜单可选择简体中文、English、日本語；语言保存到用户设置，下次启动恢复。菜单中的帮助包含操作与技能说明，长文本可滚动。新增语言、自定义译文、字体与回退规则见 [localization/README.md](localization/README.md)。

## 工程入口

开发规则/模块索引见 AGENTS.md；第一版基线见 docs/first-version.md；下一版多语言范围见 docs/localization-v2.md；实际验证和遗留见 docs/status.md。测试与错误协议见 docs/testing.md、docs/errors/README.md。

```sh
node tools/check.mjs --scope game
node tools/check.mjs --scope toolchain
```

报告在 `artifacts/test-runs/latest.json` 指向的目录。macOS 文件系统沙箱限制可能阻止 Godot/Python 读取工程或写引擎用户缓存；agent 应按已记录 ENV-0004 在同一入口使用授权环境复跑，不削弱断言。

## 当前限制

首版没有完整技能树、互动道具、敌人 AI、存档、音乐或正式场景。角色为单帧图片，移动偏移/施法光点/攻击轨迹是程序反馈。正式美术与用户手感验收仍待后续反馈，自动通过不能代替试玩判断。
