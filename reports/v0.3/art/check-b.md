# v0.3 中继表现B：实际自检与交付

主美，2026-09-30；任务4c6d3ddd-8266-425c-b3c3-e1e5a93aabea，art-director允许本人制作自验收。源范围符合工作包；没有改scripts/level、scripts/player、scripts/ui，也没有覆写v0.2/v0.2.1证据或Git提交。

交付：3张48×48透明PNG、1个0.30秒48kHz短声、RelayVisual、ChaseVisual延迟HUD、独立预览。清单/锚点/导入/生命周期详见 `docs/art/v0.3-assets.md`、relay-assets.json。

## 方法

Godot4.7.2 stable，Windows D3D12/Forward+，RTX4050 Laptop GPU，逻辑960×540，PNG1280×720。两个GPU测试使用fixed-fps60、正常图形进程。`check_relay.gd`为冻结公开接口预览；`check_relay_root.gd`为正式RunFlow候选事件fixture，不作碰撞、收益或路线可达证明。业务关卡布局仍在C制作，B没有最终完整工程版本放行结论。

check-only、15项独立预览、5项正式接口抽查均退出0。正常GPU日志只有本机user://着色器缓存/根证书读取信息，无资源加载或GDScript错误、无退出音频/ObjectDB泄漏。headless导入曾记录AppData编辑器目录/缓存/设置不可写信息，但资源导入后已在GPU实际加载通过，不将编辑器缓存信息归为节点加载失败。

复现：

```powershell
python scripts/visual/build_relay_assets.py
& 'E:\Godot\4.7\Godot_v4.7.2-stable_win64_console.exe' --path 'E:\Project\Godot\测试3' --fixed-fps 60 --script res://reports/v0.3/art/check_relay.gd --log-file 'E:\Project\Godot\测试3\reports\v0.3\art\relay.log'
& 'E:\Godot\4.7\Godot_v4.7.2-stable_win64_console.exe' --path 'E:\Project\Godot\测试3' --fixed-fps 60 --script res://reports/v0.3/art/check_relay_root.gd --log-file 'E:\Project\Godot\测试3\reports\v0.3\art\relay-root.log'
python reports/v0.3/art/check_preview_pixels.py
```

## 实际预览检查

| 步骤 | 预期 | 实际 |
| --- | --- | --- |
| 初始读取两个节点 | 都未接入 | 两个available |
| 首次接入左节点 | activating、一次短声 | state/trigger1/playing正确 |
| 同步0.9秒延迟 | HUD第三行显示 | visible=true、remaining0.9 |
| 固定front95，12组每3帧 | 延迟前沿固定，波形clock继续 | front95未变、clock增加>0.5秒 |
| 接入后0.42秒 | 闭环低亮已接入 | activated |
| 重发同ID事件 | 不重播 | sound_triggers不变 |
| 第二节点接入后暂停18帧 | 节点、波形、延迟、短声冻结 | clock和delay不变、sound_paused=true |
| 恢复8帧 | 继续时钟/声音 | clock前进、短声取消暂停 |
| 等待延迟与toast结束 | 不遗留提示 | 两个提示均隐藏 |
| failed后晚到事件 | 时钟冻结，无声和toast | 全部符合 |
| reset节点并重绑 | clock、三态、延迟、声音清零 | available/clock0/trigger0/HUD隐藏 |
| time_trial接入 | 反馈/计数存在，added_delay=0 | toast/短声存在，无延迟HUD |
| finished后等待 | clock冻结、声音和toast清理 | 全部符合 |
| 重绑4次 | 订阅不堆叠 | relay_activated1，delay_changed2（节点与HUD各1） |
| 移出场景 | 短声stream释放、断开订阅 | stream=null/停止/订阅为空 |

完整结果：relay-lifecycle.json。GPU连续帧在frames/relay-00.png至11.png，relay-preview.gif来自这12帧；不是实时玩家操作证明。

## 正式接口抽查

制作人A冻结签名已接入正式root。5项relay-root.json均通过：正式候选激活传到RelayVisual；正式delay事件传到HUD；已存在0.9秒延迟后重绑HUD立即读取；原计时计数但延迟0；lab_mode布尔兼容且节点列表为空。不假设level_id='lab'，不改业务判定。

## 视觉与范围

已实际查看available/activating/activated/time-trial四张GPU图、半尺寸接入图和灰度已接入图。节点断续金环/明亮接口/闭环勾可区分；危险仍为珊瑚尖刺，角色冷青。扩散环、HUD与toast没有遮住预览角色/落点，根统计位于左侧，延迟行与toast位于右侧。

暂停两张截图相隔18帧，全图变化像素0，记录在relay-pixels.json。WAV规格/峰值由生成器记录，短声资源确实加载和触发；没有真人试听，不宣称响度舒适或音色效果通过。

本检查范围未发现缺陷，可接受B制作交付。C完成布局后才开始D包装，最终位置与正式镜头下的可读性在D及F继续确认；全关路线、收益、玩法压力和真人理解度尚不由本B预览证明。
