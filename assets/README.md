# 占位素材模块

## 当前用途与职责

`hero_placeholder.png` 是第一版主角的静态占位纹理，仅用于验证移动、跳跃、普通攻击及火球术反馈。深蓝灰外套、皮靴、腰包与少量黄铜装饰是暂定蒸汽朋克视觉提示，不能作为正式角色设定或叙事依据。

此模块存放可替换的视觉素材；碰撞、角色移动、技能和伤害逻辑不应依赖纹理内容、画布大小或透明边距。

下一版增加随工程分发的中日文字体，来源、固定版本、许可和校验见 [fonts/README.md](fonts/README.md)。字体用于菜单、HUD、帮助和地图标签；不依赖本机安装中文或日文字体。

## 来源与生成方式

- 工具：内置 `image_gen.imagegen`，默认 built-in 模式，`transparent_background: true`。
- 日期：2026-10-01。
- 原始工具输出：`/Users/hanguo/.codex/generated_images/01a0f67b-8486-7f22-916e-0f164400c9b5/exec-770e5531-cceb-4a8d-88b2-78374324e064.png`。
- 项目文件：`assets/hero_placeholder.png`，直接复制工具输出，未裁切、缩放、修改 alpha 或通过代码重新绘制。
- SHA-256：`f037f8cc2caa9a9f696f3963bfd2a5065fe2483ec0770543437e0bf51ee81de3`。
- 当前尺寸：1254 × 1254，RGBA 8-bit PNG。
- 模型名称没有由工具结果披露，不推断具体模型版本。

## 最终实际使用的生成 prompt

```text
Use case: stylized-concept
Asset type: replaceable player character sprite for a Godot 2D side-scrolling pixel-art game prototype.
Primary request: generate exactly one full-body idle combat-ready adult steampunk adventurer, strict side profile facing right.
Scene/backdrop: genuinely transparent background with alpha, no environment.
Subject: one adult adventurer, short dark blue-gray coat, leather boots, small leather belt pouch and a small sheathed saber at the hip; subtle Victorian-era steampunk styling, restrained practical outfit, clear readable silhouette.
Style/medium: classic low-resolution pixel art, as if drawn on a 64 by 64 logical pixel grid, large crisp square pixel blocks, limited palette, hard edges, no anti-aliasing, no smooth painted rendering.
Composition/framing: square canvas; single character centered, full body including both boots, occupying most of the canvas height with a small transparent margin; strict orthographic side view facing right, ready idle stance with slightly bent knees and arms clearly separated from torso.
Color palette: dark slate navy, muted blue gray, leather brown, restrained warm brass accents, pale skin, near-black outline.
Constraints: one single static sprite only; no sprite sheet; no extra poses; no ground shadow; no text, border, watermark, floor, props outside worn equipment, or extra characters; preserve real transparency.
```

## 已检查的结果与限制

- 已用 `view_image` 检查完整人物、右侧朝向、透明背景、无文字与水印，文件读取确认含 alpha 通道。
- 这是单张静态图，无行走、跳跃、攻击或施法帧。原型可以给视觉节点添加轻微状态偏移，不能据此声称已有正式角色动画。
- 输出具有像素风格，但不是严格的 64 × 64 像素网格：实际画布更大，边缘含部分 alpha，身体略有侧面透视。正式素材应重新定义逻辑分辨率、视角和动画规格。
- 非零 alpha 的精确边界为 `Rect2(39, 21, 1185, 1209)`，包含很淡的外围像素；alpha ≥ 8 的可见主体边界为 `Rect2(352, 50, 570, 1165)`。使用完整原图或纹理 region 都不会修改原始 alpha；若启用 region，可根据后者留少量边距。
- PNG alpha 数量：完全透明 1,210,905 像素、完全不透明 1,941 像素、部分透明 359,670 像素。主体主要 alpha 值为 253（270,042 像素）。这些读数只检查文件格式与边界，不是美术品质验收。

## 替换接口建议

- 通过主角视觉节点的纹理引用替换；朝向用该节点翻转，不修改角色碰撞。
- 角色原点建议放在脚底，视觉缩放与偏移独立于物理节点。当前可见主体高度 1165 像素；按目标游戏身高设置视觉缩放，不直接采用画布宽高计算碰撞。
- 纹理过滤使用 nearest 以避免运行时额外平滑；这不能把生成图转换为严格低分辨率像素画。
- 后续若采用 `AnimatedSprite2D` 或 `SpriteFrames`，保留控制逻辑与动作状态接口，将静态纹理替换为动画资源；对应更新此说明、角色模块文档与实际运行验证。

## 验证与遗留

文件已保存并完成外观查看、PNG 格式/alpha 只读分析；游戏导入和场景中显示由主 agent 的统一测试与运行检查负责。正式素材规格、动画帧、美术一致性与用户视觉反馈仍待定。
