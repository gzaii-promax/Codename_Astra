# 训练界面模块

`training_hud.gd` 是 CanvasLayer 下的被动训练界面，读取 Player 的有效火球定义/动作阶段/剩余冷却，以及 TrainingDummy 的累计伤害和命中次数。它不驱动战斗、不修改技能数据、不保存成长。

界面包含按键说明、Lv.1/2 火球的前摇/后摇/伤害/冷却以及目标统计。F2 的映射与等级切换归 world/shared；HUD 仅显示变化。界面使用 Godot 默认字体与系统 fallback；实际文字渲染需要图形运行检查，headless 不证明文字可见。

后续正式技能后台可复用 SkillDefinition.get_resolved_attributes() 显示完整属性；当前 HUD 只显示试玩需要的部分，完整阶段策略在资源 Inspector 与 skills/README.md 中可查。未来界面布局/动画可以独立替换。本模块无正式 HUD 美术。

验证入口 `node tools/check.mjs --scope game` 覆盖场景启动；截图检查当前训练信息可读，手感不属于自动验收。
