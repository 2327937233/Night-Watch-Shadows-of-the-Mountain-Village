# 沈月兰脚印追踪

## 实际场景连接

`InteriorPlaceholder.tscn` 使用 `main_hall.gd`。吊绳房的真实入口是正堂左回廊
`BREAK_DOOR_POSITION = (-6.77, 0, -4.32)`，沿用原有破门/进入交互，加载
`HangingSideRoom.tscn`。庭院的 `LeftWingInterior3D.tscn` 是寻找主屋钥匙的另一间
厢房，不连接吊绳房，因此本路线走现有左回廊，不导向庭院的另一间房，也不新增门。

- 正堂路段：女人站位旁 → 柱脚外侧 → 左回廊 → 原有吊绳房门口。
- 室内路段：原有出生点/门口 → 左侧通道 → 绕开中央香炉 → 绕开倾倒木凳 → 梁下。
- 门口两端分别覆盖可操作门的位置和室内原有出生点，不修改出生点或门。

## 状态

- 原有 `main_hall_yuelan_footprints_available`：女人完全消失后启用两段脚印。
- 原有 `main_hall_yuelan_footprints_examined`：保留原起点 E 调查，任务变为
  “沿着脚印寻找女人”，不影响后续脚印是否显示。
- `yuelan_trail_door_heard`：抵达门口时仅播放一次 3D 轻抽泣，短淡入淡出。
- `yuelan_trail_room_reached`：进入既有吊绳房时，任务变为“调查吊绳房的异常”。
- 返回正堂、重载任一路段保留全局状态；`GameState.reset_run()` 清除新状态。
- 此控制器不设置结局状态，不触发旧剧情，不修改背包或角色脚本。

## 调整

统一控制器：`scripts/yuelan_footprint_route.gd`。
可单独打开 `scenes/story/YuelanFootprintRoute.tscn` 调整步距、鞋长/鞋宽、横向
落脚偏移、水渍对比、抽泣音源和时长。默认步距 0.42m、鞋长 0.236m。
编辑场景内 `HallPath` / `HangingPath` 下的 Marker3D 可分别调整两段路径，节点顺序
就是行走顺序；也可用 `route_points` 覆盖当前路段的三维控制点。
生成时以小幅弯曲连接控制点，左右脚交替，轻微改变角度、间距与吸水程度。

脚印直接进入场景独立的既有砖面 ShaderMaterial，使用原地面法线、光照和砖缝，
没有悬空贴片、Z-fighting、新碰撞体或逐帧重建。每段最多96枚，实际远低于上限；
先检查路段范围，再只在每枚鞋印附近计算边缘噪声。其他房间材质默认不启用。

## 验证

`tmp/validate_yuelan_trail.gd`：实际胶囊体沿两段路线行走、密集碰撞查询、原门切换、
脚尖朝向/交替/步距、抽泣3D音频PCM、任务推进、返回场景和一次性触发。
`tmp/validate_yuelan_footprints.gd`：原调查逻辑、完全消失之后才显示、手电交互、
原生 Forward+ 渲染差异和状态恢复。
