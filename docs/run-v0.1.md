# 信号跑道 v0.1 运行说明

在 Godot 4.7.2 中导入本目录的 project.godot，按 F5 运行即可进入开始界面。主入口为 scenes/main/main.tscn；完整首关为 scenes/levels/level_01.tscn。本版交付源工程，不需要导出或打包。

| 操作 | 按键 |
| --- | --- |
| 移动 | A/D 或左右箭头 |
| 跳跃和蹬墙 | Space、W 或上箭头；短按低跳，长按高跳 |
| 新挑战 | R |
| 暂停和继续 | Esc，也可点击 HUD 暂停按钮 |
| 开始或结算后再玩 | Enter 或界面按钮 |
| 控制测试房 | F2 或开始界面的测试房按钮 |

首关分四段：安全教学、单项练习、组合挑战、终点冲刺。青色角色由玩家控制；浅色顶边是可站立平台，珊瑚色尖刺和空隙致命，金色门是终点。两处高墙需要先普通跳跃，再在贴墙时再次按跳跃；同侧墙不能连续无限攀升。落地或接触另一侧墙面会恢复该侧机会。

首次移动或跳跃开始本轮计时。死亡自动回到起点，保留本轮时间与死亡数，恢复时间也计入用时；暂停不计时。R 和结算后的再次挑战清零本轮统计，保留当前程序会话的最佳通关成绩。最佳以用时更短优先，时间相同取死亡更少。退出程序后不保留成绩。

本机验证配置：Godot 4.7.2 stable，Forward+，D3D12，NVIDIA GeForce RTX 4050 Laptop GPU；逻辑画布960×540，初始窗口1280×720，60Hz物理。未验证其他显卡、平台或手柄。

程序首次运行自动注册输入动作和 SFX 音频总线。美术资源在 assets/visual 和 assets/audio；角色表现只消费公开事件。真实画面截图及逻辑验证结果在 reports/v0.1，资源规格与清单在 docs/art。

开发用独立测试房入口为 scenes/test_room/test_room.tscn。CLI 逻辑检查可运行：Godot console --headless --path 本工程 --fixed-fps 60 --script res://scripts/core/validate_movement.gd，或 res://scripts/level/validate_v01.gd。后者包含不传送的全关卡输入通关检查；自动输入证明规则与主路径可达，不能替代真人体验研究。
