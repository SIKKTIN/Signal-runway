# 信号跑道 v0.4 运行与公共接口

Godot4.7.2 stable打开project.godot，F5。菜单无限挑战Enter确认后自动奔跑，Space/W/上箭头跳跃及蹬墙，短按低跳长按高跳。Esc暂停，R同图完整重试；结算换图挑战使用新种子。两个固定关和测试房保持手动/原计时规则，源工程不打包。

## A冻结公共接口

根RunFlow.is_endless()判断无限模式；level_id='endless'且lab_mode=false，mode仍为'pursuit'以兼容现有追赶表现。start_endless(seed_value=-1)新seed或显式seed；restart_challenge保留seed。run_seed、run_distance（全局最远前进世界单位）、run_score、relay_count、difficulty_stage、best_score、new_record、catchup_bonus为公开只读值。

## 已实现规则

无限无终点，尖刺/坠落/吞没单次结算，失败优先奖励。角色280，追赶基础270/274/278/282，每30秒有效游戏时间一个阶段，2秒启动缓冲/起点后640。持续阶段余量超过1400时公开远距追速：bonus=clamp((gap-1400)/60,0,14)，以8单位/秒平滑变化，总速度最高296，HUD显示实际追速。不修改前沿位置或隐藏夹紧；暂停冻结，接入0.9秒延迟时计时和波形继续。

12个1280单位片段，地形阶段按固定路程8400预算递进，开局安全、难度2以上后安全调整，同段不连续。每5或6片段安排可选中继，不同节点位置造成约22.4–27.9秒基础行程间隔；墙跳增加的实际时间另计。每个奖励间隔最多一次有前进时间成本的墙跳，包含中继B上路，避免两次约0.4833秒的成本超过0.9秒奖励。至少一条稳路可过，中继A跳跃/中继B一次墙跳上路各给0.9秒延迟和100分。

分数=floor(最远前进世界距离/10)+100×节点数，回退和重复节点不重计，时间不加分。R同种子清理本轮，换图保证不同新种子。最高分写user://signal_runway_endless.json（Godot本机用户数据目录），独立schema1及生成器revision；不迁移固定关会话成绩。缺失/损坏默认0，较低分不覆盖；失败结算后新纪录原子保存，保存失败在结果卡提示。

endless_stats_changed(score:int,distance:float,count:int,stage:int)用于HUD/只读表现；world_shifted(distance:float)表示局部所有世界X坐标减去distance，累计路程不变。旧threat_updated、relay_activated、relay_delay_changed、pause_changed、run_failed等签名兼容。无限无run_finished成功终点，失败统一走run_failed。

EndlessCourse.chunks为活动片段快照，元素id、template_id、origin（局部X）、length、difficulty、category；relays仍为id、position（局部Vector2）、activated。course.total_offset为累计X偏移。course信号chunks_changed、chunk_added(chunk:Dictionary)、chunk_removed(chunk_id:String)。D冻结：chunks_changed在整批活动几何/节点同步后发，主美据此读取完整快照；chunk_added/removed为单段通知。根world_shifted在所有角色/镜头/前沿调整后发。节点ID由seed/片段序号/局部ID构成，已回收实例不再生成。主美依活动快照同步缓存，不让历史节点字典随路程增长。前方3200、后方覆盖及玩家各960保留，重定位阈值32768/偏移25600。

地形生成/碰撞/动作/追赶/计分由制作人维护，场景与节点表现由主美维护。表现读取total_offset及world_shifted，保持视差、波形、节点脉冲连续。主美C先独立预览和组件，D完成后F正式接入；不修改主干或地形随机流。

## 当前版本验证

最终候选v0.4.0+d56fd239612f，84个生产文件。100种子×200片段生成检查、148种实际连接路线、19项分数/存档、20项GPU集成及77项旧固定关回归通过。seed404普通跳跃输入完成游戏内30分钟、496781.25距离、72节点，最大7活动段；加速执行108000物理帧，实际墙钟计时另测，不代表真人试玩。详见reports/v0.4/integration.md；主美独立检查和最终交付另见independent-review.md、final-acceptance.md。
