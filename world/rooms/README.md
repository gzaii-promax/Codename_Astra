# 第一版灰盒房间

`corridor.tscn` 是 A/C 共用的布局模板（512 × 256 px）；`hall.tscn` 是 B 的长大厅（768 × 256 px）。房间场景不保存世界身份、目标房间或探索记录；实例身份与连接由地图注册配置管理。修改共享走廊模板会同时影响 A/C。

## 编辑入口与职责

直接在 Godot 编辑器打开场景，选中 `Terrain`（`TileMapLayer`），使用瓦片面板编辑地板、墙和台阶。瓦片与碰撞约定见 [占位瓦片说明](../../assets/graybox/README.md)。地形保存在场景的 `tile_map_data`，运行时不由脚本拼接。`MapRoom` 的绘制只提供灰盒底色和 1 U 网格，不创建碰撞。

- 房间根节点：`MapRoom`，`bounds` 是房间局部像素范围，供相机边界和校验读取。
- `Entrances/Start`、`West`、`East`：`MapEntrance`，位置是玩家脚底落点；稳定 `entrance_id` 与进入朝向分别可编辑。绿色标记仅在编辑器显示，不是角色碰撞。
- `Exits/West`、`East`、走廊的 `Return`：`MapExit`，蓝色普通通道、金色返回通道；`Trigger` 是实际 `CollisionShape2D`，节点位置、形状、出口身份和标签可编辑。出口仅发送 `exit_requested(exit_id)`，不储存路由。
- MapWorld 将没有连接的出口设为 `enabled=false` 并隐藏，出口同时关闭 `monitoring`。单独显示禁用的 MapExit 时，其标记绘制为灰色。A/C 共享 Return 节点，但 A 无此连接，不会触发返回。

出口仅接受 `PlayerCharacter` 且 `Combatant.LifeState.ACTIVE`，碰撞层 0、检测 Player 层 2；死亡角色和其他身体不会请求切房。进出树会连接和撤销出口身体信号及语言信号。标签读取 `map.exit_west`、`map.exit_east`、`map.exit_return`。

## 几何约定

统一 1 U = 16 px。`Terrain` 第 15 行是地板，地板上沿 y=240，底部 y=256；第 0 行是顶板，两端一列是 16 px 厚墙。入口脚底 y=240，Start/West x=80，East x=width−80；West 朝右、East 朝左。Start 和 West 是相同安全落点的两个可独立引用入口。

West 出口中心 (32,216)，East 出口中心 (width−32,216)，Return 中心 (256,216)。所有出口检测框为 16 × 48 px，底部与地板上沿对齐；入口与框之间至少 32 px 水平间隙，大于主角半宽 8 px，避免一进入就触发反向切换。

走廊 (160,224)、大厅 (192,224) 各有一个 16 × 16 px 实心台阶。台阶可以利用当前 1–2.5 U 跳跃登上后走下；没有单向平台、穿透下落或攀爬。台阶故意只占一格，不要求当前 56 px/s 移动跨越长平台；实际可达性仍以真实物理测试为准。

## 接口与验证

`get_entrance(id)` / `get_exit(id)` 返回匹配节点或 null；`get_entrances()` / `get_exits()` 递归读取分组下节点。`validate_room()` 检查 bounds 正尺寸与有限值、入口出口空/重复身份、入口局部位置在 bounds 内、入口朝向为 −1/1。模板内的 ID 只需在各自房间内唯一；不会把同一个模板的多个世界实例当作重复房间。

验证由统一 game 入口和地图测试完成；该文档不是已通过证明。用户仍需审核房间比例、行走距离、台阶手感和出口提示。转场、预加载、攀爬表面与技能、房间总览编辑工具列为后续 TODO；本模板保留入口/出口独立节点和场景资源组织，为这些功能留出接口。
