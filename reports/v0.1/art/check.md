# v0.1 主美独立预览检查

- 日期：2026-09-30（Asia/Shanghai）
- 工程：`E:/Project/Godot/测试3`
- 引擎：Godot 4.7.2 stable official，Windows D3D12 / NVIDIA RTX 4050 Laptop GPU
- 入口：`res://scenes/visual/art_preview.tscn`
- 捕获：`scripts/visual/capture_preview.gd` 在非 headless 图形进程运行，生成待机 `preview.png` 与运动状态 `preview_motion.png`（1280×720）；将运动帧另存灰度与 50% 缩小图用于可读性检查。

## 实际执行

1. `python scripts/visual/build_art_assets.py`：生成 23 张 PNG、5 个 WAV。
2. Godot 编辑器导入资源后，`--headless --scene res://scenes/visual/art_preview.tscn --quit-after 120`：场景及全部资源加载，无脚本错误。该运行使用 dummy 渲染，不能作为视觉截图。
3. `Godot_v4.7.2-stable_win64_console.exe --path E:/Project/Godot/测试3 --fixed-fps 60 --script res://scripts/visual/capture_preview.gd`：D3D12 真正渲染并保存待机和移动状态截图。截图中平台浅顶边、珊瑚尖刺、金色终点与青色角色清楚分离；运动帧灰度图中四类物件仍靠轮廓与明度可辨，50% 缩小图仍可辨危险朝向与终点位置。
4. 用同一图形进程运行 `res://scripts/visual/verify_audio.gd`：`jump` 0.180s、`wall_jump` 0.220s、`land` 0.130s、`death` 0.300s、`finish` 0.620s 均加载成功且 `playing=true`。这是实际播放启动检查；主观听感仍需人工试听。
5. `python scripts/visual/analyze_audio.py`：五类音效均为48kHz/mono，峰值均为 -3.10 dBFS，无数字满幅削波；详见 `audio_metrics.json`。落地音平均能量较低，运行时音量设为 0 dB，其余动作 -3 dB；正式关卡中继续检查混音。

## 已知范围

- 预览场景只验证资源、Theme、动作事件与五类声音的独立触发；它不验证关卡碰撞、真实移动节奏或完整开始至结算流程。
- 捕获时 Godot 因本机受限用户目录提示 `user://` 日志/着色器缓存不能写；图形捕获及场景资源加载成功。后续集成验证须检查其实际运行日志。
- 主美资源的视觉碰撞对齐由制作人在正式关卡接入后检查；如果实际地图改变世界模数或角色锚点，先协调接口再调整资源。
