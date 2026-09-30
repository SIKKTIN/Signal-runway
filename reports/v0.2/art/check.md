# v0.2 主美 C 资源预览检查

日期 2026-09-30（Asia/Shanghai），工程 `E:/Project/Godot/测试3`，Godot 4.7.2 stable official，Windows D3D12 / NVIDIA RTX4050 Laptop GPU；逻辑960×540、窗口1280×720。

实际执行 `build_v02_assets.py` 生成8张纹理和4个48kHz WAV，Godot 导入并检查脚本。非 headless 图形进程运行 `capture_v02_preview.gd`，生成六种状态截图；逐张查看 urgent、failure_skins、caught，另查看 urgent_grayscale、urgent_half。HUD文字/图标可辨，前沿后方变暗，前方角色、尖刺和落点保持原样；三种失败皮肤文字无裁切。

`check_lifecycle.gd` 在同一图形配置运行，13项全部通过，退出码0。检查使用冻结接口的模拟 flow/chase，验证公开信号消费与声音生命周期，不验证主干判定：

| 检查 | 结果 |
| --- | --- |
| 不发事件直接 bind，读取属性 | front_x222、gap546、urgent立即同步 |
| 单循环与资源 | 一个ThreatLoop、两个短提示播放器，循环资源LOOP_FORWARD |
| 重复同级30次更新 | 循环/提示位置从0.0453前进到0.0560，没有重启 |
| 暂停 | 循环stream_paused=true，动画时钟不变，短提示停止 |
| 继续 | 同一循环恢复，无新增播放器 |
| 原计时模式 | 循环停止，HUD隐藏 |
| stopped随后caught结果 | 循环停止，HUD隐藏，吞没提示只触发一次 |
| 成功结果 | 所有追赶音效停止 |
| 菜单初态 | 静音且HUD隐藏 |
| ready/grace重开 | 清除结果态，缓冲HUD显示、循环保持停止 |
| 重新绑定5次 | threat_updated只有一个订阅 |
| 失败原因 | 三个独立形状图标 |
| 移除场景 | 播放器停止且stream清空；最终运行无ObjectDB/音频资源泄漏警告 |

`check_frames.py` 的像素比较确认：世界前沿540对应屏幕720，画面中覆盖变化的最大x=719，安全侧检查区域无变化；循环接缝PCM差129，等于波形正常最大相邻差129。结果文件为 `lifecycle-results.json` 和 `frame-check.json`。

声音峰值与RMS见assets.json，无满幅削波。工具已确认真实Godot播放状态，人工主观试听和玩家紧张感未验证。正式动态关卡、结果业务界面、机制判定及不同硬件未纳入本次独立资源预览。图形进程存在沙箱user://着色器缓存和根证书权限提示；不影响本次渲染/音频资源加载，记录在capture.log/lifecycle.log。
