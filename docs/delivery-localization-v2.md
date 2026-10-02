# 多语言下一版交付与草稿 PR 描述

> 原草稿交付快照：以下 OPEN/draft 与“不合并”描述按原交付时点阅读，限制已被 2026-10-02 明确整合授权取代，内容已进入 main。当前结果见 [status.md](status.md)，原始验收和 PR 描述保留。

实际[草稿 PR #3](https://github.com/gzaii-promax/Codename_Astra/pull/3)已创建并附加到当前 Codex 任务，核实为 OPEN、isDraft=true；功能实现提交 `23c64a28b1237df2cd8c3f7dee46fabf623d7bec`。后续仅在同一 PR 更新文档，不合并或发布。

## 实现

现有训练场增加简体中文、英文和日文的语言入口，覆盖暂停菜单、HUD、技能名称/说明、操作帮助与地图标签。Esc 或菜单按钮暂停战斗，菜单可继续、重置、选择语言、打开帮助；长说明可滚动。语言选择保存，下次启动恢复。

新增 localization 模块把 JSON 目录转为 Godot Translation 资源；语言清单、译文和字体可独立配置，增加语言不改业务分支。缺失或空译文回退默认简体中文，未知键保持原样，命名参数支持译文语序变化。技能资源保存 name_key/description_key，替代原 display_name；控制器、伤害与时序不依赖语言。ConfigFile 保留其他模块数据，坏文件与保存失败提供诊断。工程附带固定来源及许可的 Noto CJK SC/JP 字体，关闭系统字体 fallback。

没有新增故事、技能行为或玩法数值。当前语言设置之外没有游戏进度存档；正式翻译润色、像素美术与手感仍待用户反馈。

## 验证

- `node tools/check.mjs --scope game`：`20261001T103447218Z-fb5fe550`，14/14 检查，53 tests / 649 assertions，0 failures/errors/skipped；93 项文件哈希匹配。保留原 34 项回归，新增资源、回退、参数、第四语言、设置与 UI/字体/布局验证。
- 两个真实进程使用独立配置，写入 ja 后新进程直接恢复；PID 38715/38716，日志与结果保留在上述报告目录。测试和截图均隔离玩家设置。
- `node tools/check.mjs --scope toolchain`：`20261001T102523641Z-7c23a1c9`，22/22；成功、故意失败、超时、报告读取的实际底层状态保留。
- 三语真实 HUD/菜单/帮助共九张 PNG 已打开查看，图形日志无错误，额外 review.json 记录结论：`artifacts/localization-visual/20261001T102716473Z/`。完整字体和布局另有 GUT 测量，截图不代替手感。
- 首轮 HUD 溢出和独立截图探针启动错误已保留失败报告并复验关闭，见 docs/errors。没有接入 CI 或发行验证。

## 权限与接续

本轮最新授权只允许创建或更新 draft PR，不合并或发布，优先于旧的持续合并授权。分支 feat/localization-v2；实际 PR URL、状态与 head 以 GitHub 读取结果为准。继续开发前读取 AGENTS、最新提交、当前状态、报告和公共错误；语言扩展方法见 localization/README.md。
