# v0.2.1 主美动态表现交付与自检

检查人：主美，2026-09-30。任务212a0ed2-4887-407e-9f78-f1da13accd71，允许art-director自验收。工程已接入制作人Course/RunFlow接口。交付源：`scripts/visual/chase_visual.gd`、`scripts/visual/environment_visual.gd`；实现与兼容说明：`docs/art/dynamic-presentation.md`。旧v0.2资源与证据没有覆写。本轮没有Git提交或推送。首版提交后用户指出保留的竖直线仍使前沿死板，主美已正式退回反馈7021832d并修订：移除直线和平直红色填边，所有覆盖与内部流动沿波形裁切。本报告、连续帧和像素JSON已在这次修订源码上刷新。

## 方法与环境

Godot4.7.2 stable，Windows / D3D12 Forward+ / RTX4050 Laptop GPU。最终对应制作人清单版本 `v0.2.1+b67d4c1e161a`，两个主美运行脚本SHA256与清单对应项一致，原值在pixel-results.json。正常图形CLI（不使用headless）运行 `reports/v0.2.1/art/check_motion.gd`，fixed-fps60。正式main场景中固定摄像机、角色和追赶front，观察独立动画；直接设置位置、phase和候选属于表现/生命周期fixture，不证明普通输入路线或真人体验。

两个脚本check-only退出0。正常GPU自检退出0，16项检查均通过。图形日志 `motion.log`有环境中的user://着色器缓存和根证书读取信息，无GDScript解析、资源加载失败或退出音频/ObjectDB泄漏。`check_pixels.py`退出0。像素结果内记录两个运行脚本的文件长度与SHA256，最终版本由制作人生成清单。

复现：

```powershell
& 'E:\Godot\4.7\Godot_v4.7.2-stable_win64_console.exe' --path 'E:\Project\Godot\测试3' --fixed-fps 60 --script res://reports/v0.2.1/art/check_motion.gd --log-file 'E:\Project\Godot\测试3\reports\v0.2.1\art\motion.log'
python reports/v0.2.1/art/check_pixels.py
```

## 生命周期实际检查

| 步骤 | 预期 | 实际 |
| --- | --- | --- |
| 主菜单实例化EnvironmentVisual | identity、z=-10、替代旧背景；菜单有运动 | 组件已接入，三项属性一致，10帧clock增加 |
| 新轮世界重建 | 两个表现组件clock从零开始 | 同步读取均0 |
| fixed front560/player820/camera480，24次采样，每次4物理帧 | 前沿位置不受表现改动，两个组件时钟前进 | front560未变，两个clock均1.6秒 |
| 暂停24帧 | 两个clock及威胁循环冻结 | 时钟快照[1.6,1.6]保持；stream_paused=true |
| 恢复8帧 | 时钟、循环恢复 | 两时钟前进、循环取消暂停 |
| 查询ChaseVisual旧字段 | 13个原字段保留 | 全部存在 |
| caught失败候选后等待20帧 | 失败冻结环境/波形，停止威胁循环 | failed，两clock稳定，loop停止 |
| 重开 | 新表现clock清零 | 两clock均0 |
| 成功候选后等待20帧 | 成功也冻结两个组件、停止循环 | finished，两clock稳定，loop停止 |
| 原计时模式 | 环境clock继续，无追赶HUD或循环 | 环境clock>0、HUD隐藏、循环停止；真实截图无覆盖 |
| 摄像机投影数学抽查：镜头平移800 | 远层0.14、近层0.57各有不同位移 | 相对屏幕位移112 /456，符合因子 |
| 同组件各重绑4次 | 不重复订阅 | pause_changed共2个表现订阅；threat_updated仅1个 |
| 测试房 | 2400长度的Course仍安装动态环境 | lab/长度/绑定正确，图形可启动 |
| 返回主菜单 | 无威胁HUD与循环 | 均关闭 |
| 移出场景并释放 | 订阅清空，音频stream释放 | pause订阅为空，ThreatLoop停止且stream=null；正常退出 |

共16个单项（部分表格合并关联步骤），逐项名称/实际值见 `lifecycle-results.json`。测试没有改玩家、判定、速度、关卡几何或历史报告。

## 连续运动与边界像素

24张连续GPU帧在 `frames/motion-00.png` 至 `motion-23.png`，每帧间隔4/60秒游戏时间。摄像机、角色和front保持固定，因此变化来自表现自身：

- 波形区域每对相邻帧至少14793个像素变化；环境区域每对相邻帧至少577个像素变化，运动不是只有偶尔亮灭。
- 两张正式暂停画面 `paused-a.png` / `paused-b.png` 相隔24物理帧，全图变化像素 **0**。
- 波形clock=0、0.23、0.51、0.94、1.43、2.0六个时刻，分别冻结并将ChaseVisual绘制开/关比较。环境与HUD相同；front世界/画布x560，PNG1280/960比例得到边界x746.6667。
- 六组最右变更列为732–737，最大 **737**；747列起所有像素完全一致，原直线附近744–747列亦完全不变。覆盖、主波、光晕和信号包没有越过front_x，原竖直标记已经消失。数学上主波中心偏后13–63、光晕半宽6，外缘保守上界front-7；覆盖实际跟随曲线，逻辑front_x不另画直边。

像素原值见 `pixel-results.json`。成品预览 `motion-preview.gif` 为960×540，24帧、每帧67ms；GIF循环展示固定场景的1.6秒片段，首尾重新播放不代表运行动画重置。运行动画连续使用自身clock。

## 画面观察与实际范围

已查看连续帧0/10、墙跳、终点，以及640×360半尺寸追赶和墙跳截图。珊瑚波峰、青色回波和覆盖内部波带层次分开；右侧角色、尖刺、平台白边清楚；工业面板灯、线路信号和粒子有变化但对比低于玩法对象。墙跳的青色边缘与教学文字、终点门和金色箭头均可辨认。菜单和结果卡片仍沿用已有样式。fixture中保留的“首次移动”notice和0秒计时不是运行状态缺陷；该fixture直接设置phase并冻结业务循环。

制作人已在最终无直线源码上刷新另外13项GPU接入检查、36帧动效序列和原33项规则回归通过；其波形区域变化11877像素、环境1644、暂停差0。主美本报告16项GPU与像素/视觉证据也已刷新，不使用带细线首版证据作为最终验证。主美重点补充6时刻边界、视差数学、成功冻结、重绑/退出及半尺寸视觉证据；最终整体清单与集成收口由制作人负责。

没有发现本范围剩余缺陷。主美可接受本制作交付；最终集成、版本冻结、Git同步及源工程验收由制作人负责。未组织真人试玩，未测其他GPU/平台和主观听感，本报告不将fixture、截图或像素变化当趣味性结论。
