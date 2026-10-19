# R4 主角与基础移动动画

2026-10-19 用户选择 R4「符印旅装」作为当前主角人设，并授权加入站立、待机和跑步精灵图。角色设定见 [主角基线](../../../docs/protagonist-r4.md)。这是第一版可替换动画素材，画面与手感仍由用户验收。

## 文件与编辑入口

- `concept.png`：本轮选中的 R4 原画，保持原始 PNG 字节。
- `locomotion.png`：内置 image_gen 生成的 1254 × 1254 RGBA 图集，保留原始 alpha 与像素，未代码重绘、缩放或抠图。
- `locomotion.tres`：Godot 原生 SpriteFrames，可在 Inspector/SpriteFrames 面板查看帧与播放速度。`stand` 是第一帧；`idle` 为前两行 8 帧、6 FPS；`run` 为后两行 8 帧、12 FPS。
- [generation.json](generation.json)：原始与修订提示词、生成模式、来源路径、SHA-256、图集区域及实际限制。

图集采用 4 × 4 排列，原图边界为 0/314/627/940/1254。每格通过 AtlasTexture 引用，margin 将逻辑画布统一为 352 × 352，水平中心即角色锚点；接地脚底位于 y=324，站立主体参考高度 288。跑步腾空帧保留离地高度，其他帧统一接地点。以上只改变纹理区域和透明留白，不编辑源 PNG。`filter_clip=true` 防止采样相邻格。

主场景在 Player/Visual 的 `sprite_frames` 指向该资源；`display_height=32`、`frame_body_height=288`、`frame_feet_y=324` 定义显示比例及脚底。左右朝向由视觉节点翻转，碰撞与受击区仍独立。替换图集时同时校准这三个参数与等大帧画布，不按图片自动改变物理尺寸。

## 实际边界

- 黑发、靛蓝直身衣、灰绿短披肩、棕色腰包与小符印是 R4 辨识点。小尺寸下只保留这些轮廓和色块。
- 图集属于像素风格生成素材，并非严格手工低分辨率像素网格；边缘有部分透明像素，局部面部、衣摆和肢体存在轻微帧间形变。nearest 过滤不会把它变成手绘像素资产。
- 仅提供站立、待机、跑步。跳跃、攻击、施法、受击与死亡的专用角色帧尚未制作，暂回退站立；原有技能效果和施法变色提示仍在。
- 模型型号没有由工具披露，不推断。原图来源是本任务自有生成输出，不引入第三方角色包。

## 验证入口

真实状态切换、帧推进、左右朝向、碰墙停止、跳跃/动作/死亡回退、暂停、配置保存重载与重置由 `tests/game/test_player_visual.gd` 验证，统一执行 `node tools/check.mjs --scope game`。图形探针 `tests/probes/player_visual.gd` 捕获真实游戏状态与放大预览；实际报告位置见本轮 [状态记录](../../../docs/status.md)。

## 2026-10-20 起跑与转身

新增 `transitions.png`，内置 image_gen 依据原图集生成，1254×1254 RGBA原字节保留。提示词、SHA-256及每个 AtlasTexture 的区域/留白见 [transitions-generation.json](transitions-generation.json)。选前4帧为run_start（24 FPS），后8帧为turn（32 FPS），不循环；第二行的额外跑步姿势未接入。原始生成网格存在少量偏移，按实际完整人物区域裁取并用原生透明margin统一352画布、y=324脚底；不修改PNG像素。原有stand/idle/run帧不变。

起跑包含站姿、屈膝、推蹬和第一步；转身经过正面至反向。生成素材仍有轻微衣装/肢体变化，最终外观由用户审核。播放和打断规则见player模块。
