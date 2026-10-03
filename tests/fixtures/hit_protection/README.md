# 主角受击保护保存配置夹具

这两个继承场景仅供 `test_hit_protection.gd` 使用，复用真实主角场景并显式保存 Combatant 属性：`player_zero.tscn` 为 0.0 秒，`player_custom.tscn` 为 0.2 秒。值独立于被测公共常量，加载时忽略该夹具的资源缓存，入树后验证扣血/保护窗口与重置行为；不用于实际地图或改变默认玩法。

同一测试文件另用 PackedScene.pack / ResourceSaver.save 写入本轮 ASTRA_SETTINGS_PATH 所在证据目录，再从磁盘加载验证零秒和自定义值的保存往返。写入不会修改原夹具、主角场景或玩家语言设置。
