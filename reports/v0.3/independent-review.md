# v0.3 断线中继：独立技术与表现检查

主美，2026-09-30。任务34e93674-c4e4-4b57-a53c-bf798a0a1c66；制作人验收报告。运行工程只读，新增内容仅 `reports/v0.3/independent-review.md` 与 `independent-checks`，未修改生产代码、资源、几何或Git。

## 构建、实际结论与范围

被测冻结版本 **v0.3.0+8f8f69c021f9**，完整SHA256 `8f8f69c021f9df9b733292c71936b21eb8ebca8baa7fb682df39fdaa90158d35`，入口 `res://scenes/main/main.tscn`。逐个独立读取version-manifest.json的66个运行文件，核对长度/哈希并重新计算聚合哈希；运行前、运行后均一致，未混入B/D早期候选。`independent-checks/version-check.json`记录最终结果。

真实图形进程 **21项独立抽查全部通过**，暂停配对截图全图差0。在本次抽查范围内未发现剩余阻塞缺陷。可以提交F报告，由制作人审核证据有效性并进行G收口；报告完成不等于真人趣味性或所有平台通过。

本报告区分：真实键盘路径；定点后保留真实身体、碰撞和流程的接触/危险fixture；晚到候选事件fixture；制作人完整路线与回归引用；视觉观察和未做的主观试听。没有用定点接触或暂停实验宣称正常路线通关。

## 方法与复现

Godot4.7.2 stable，Windows / D3D12 Forward+ / NVIDIA RTX4050 Laptop GPU，960×540逻辑画布、1280×720PNG。正常图形CLI，没有headless；使用fixed-fps60确定有效游戏时间序列，未独立重新校对墙钟。实际键盘通过Input.parse_input_event注入，经过正式菜单/GUI/输入/物理循环。

```powershell
python reports/v0.3/independent-checks/verify_version.py
& 'E:\Godot\4.7\Godot_v4.7.2-stable_win64_console.exe' --path 'E:\Project\Godot\测试3' --fixed-fps 60 --script res://reports/v0.3/independent-checks/check_runtime.gd --log-file 'E:\Project\Godot\测试3\reports\v0.3\independent-checks\runtime.log'
python reports/v0.3/independent-checks/check_pixels.py
python reports/v0.3/independent-checks/verify_version.py
```

最终GPU进程退出0，所有check为true。日志只有本机user://着色器缓存与系统根证书读取环境信息，无GDScript解析、资源加载或退出音频/ObjectDB泄漏错误。完整数值与每项方法在 `runtime-results.json`。

## 步骤、预期与实际

下表针对同一冻结版本；部分关联检查合并列出，JSON保留21个单项及实际值。

| 步骤 | 预期 | 实际 |
| --- | --- | --- |
| 主入口实际Enter，等待60帧不动 | 默认新中继站追赶；首次动作前安全 | ready/relay_station/pursuit；elapsed0、front-544、count0 |
| 实际D20帧再释放10帧 | 一次启动，2秒缓冲先消耗 | running、elapsed0.5、grace1.5、front仍-544 |
| 实际Esc暂停18帧 | 缓冲、计时、角色、三个表现clock冻结 | 前后快照完全一致 |
| 暂停中实际R | 解除暂停、重置本轮，等待动作 | ready、elapsed/count/delay0，front-544，两节点未激活 |
| 再D起步，等待缓冲结束 | 接触前基线追赶已经推进 | grace0、front-526、running |
| 将真实角色放到第一节点中心并同步_previous_position；运行2帧 | 真实接触候选激活一次 | count1、delay0.883333、sound_triggers1；实际激活脉冲/HUD可见 |
| 持续留在节点附近20帧 | 持续重叠不刷新奖励或重播短声 | count1/trigger1，剩余由0.883333降到0.55 |
| 延迟仍有效时观察时间/前沿/波形 | 前沿固定，游戏用时和波形clock继续 | 20帧front保持-521.5，用时与clock都增加0.333333 |
| 0.55秒延迟中实际Esc，等待18帧 | 延迟、计时、角色/三组件clock和威胁循环冻结 | 全快照相同，循环stream_paused=true；暂停PNG全图差0 |
| 实际Esc继续，等待50帧 | 延迟结束，恢复前进且不后退、不留HUD | delay0、front-427、HUD隐藏 |
| 用接触前实际front/elapsed构造无延迟固定270基线 | 独立时间预算差接近243 | 无延迟基线front-184，实际-427，少推进242.999999999998单位 |
| 再暂停、实际R | 节点、delay、反馈全部清零 | count0、available、trigger0、toast隐藏、ready |
| 返回菜单实际Down/Enter选择计时入口，D启动；第一节点接触fixture | 新关计时也计数，不给追赶延迟 | time_trial/relay_station、count1、delay0、短声1、追赶HUD隐藏 |
| 放真实角色到x5536/y433尖刺区，运行5帧再24帧 | 真实危险自动恢复，同一轮已接入不重置 | recovering/deaths1/count1 → running、存活、relay_one仍activated |
| 计时模式实际R | 创建新一轮，已接入节点恢复可用 | ready/deaths0/count0/available |
| 实际F2 | 使用lab_mode布尔，测试房无节点及新关包装 | lab=true，即使level_id保留relay_station，节点为空、station_enabled=false |
| 返回菜单实际Enter/D开始；接触节点后坠落fixture；失败后提交第二节点候选与反馈事件 | 已失败不能继续奖励/声音/提示 | failed/count仍1/trigger仍1，toast和延迟HUD隐藏 |
| 失败界面实际Enter | 完整重开当前新关 | ready/count0/relay_station，角色存活 |

中继/危险定点检查没有关掉碰撞、没有冻结主干或追赶；将_previous_position同步为同一位置，避免把跨地图传送线段当普通走过节点。它们仍是位置fixture，不用于说明选路操作难度、绕路耗时或全程可达。晚到事件部分直接调用公开根候选方法与事件，专门检查终止状态过滤。

## 收益与路线证据来源

本独立实验只验证一次接触后0.9秒显式延迟的推进差，实测约243单位；没有绕路成本。真实分支净收益和完整路线引用制作人C最终 `route-budget.md` / `route-results.json`：

- 四种追赶组合及计时全节点共五条普通方向/跳跃路线，50.8833–51.3667秒，不传送、不冻结追赶。
- 第一汇合x2940，两路同为10.2333秒，节点净增约243单位。
- 第二汇合x8960，中继路多耗时0.4833秒，净余量增加约113.821单位。
- 稳/稳无节点也能通关；两节点不构成必选通关条件。

制作人E同版本24项图形主干、A13项规则、旧首关33项集成+20项计时回归均引用对应reports/v0.3记录，本轮没有重跑这些无关整套。两节点累计、同帧/起步边界、关卡/模式成绩隔离等超出本21项抽查的完整覆盖，以这些制作人记录为依据，不能写成本人重测。

## 图形与声音观察

已看本轮menu、relay-active、failure原图和640×360缩小图；同时读取制作人最终first-branch/second-branch截图，并在本目录生成半尺寸图查看，来源记录在pixel-results.json。正式第一处上路平台/节点与下层稳路有区分，第二处悬空墙、墙跳文字、高处落点与公共坑清楚；金色收益、珊瑚尖刺、冷青角色与白色平台边分层。接入HUD和左侧中继计数可读，菜单选择项/按钮、失败原因/计数/再玩入口均在画面内。

本轮实际节点接触画面显示激活脉冲与数量1/2、delay0.5秒，角色和落点仍可辨认。制作人分支截图中的位置、0.15秒用时或会话最佳是其定点fixture数据，不能当真实关卡通关成绩。本轮自身传送到节点的进度/时间同样不作路线证据。

声音仅检查资源加载、首次触发一次、重复接触不重播、暂停循环冻结、R与结果停止/清理。fixed-fps游戏时间与音频墙钟播放时间不同，不据playing字段推断主观时长或响度。没有真人试听，不宣称接入短声舒适或音乐性通过。

## 缺陷与未覆盖

本次实际检查没有发现需G修复的阻塞或可复现功能缺陷。只读候选与运行前后66文件哈希一致，未因测试改变冻结源。报告证据有效性由制作人独立审核；G最终版本交付另行记录。

未组织外部/真人试玩，没有主观压力、趣味性、分支理解度或听感结论；未测其他平台/GPU、手柄或长时间会话。独立抽查不重复完整路线、全套状态竞争或所有成绩组合；这些覆盖引用制作人记录并明确来源，不把自动fixture、可读性观察和AI制作检查当真人体验。
