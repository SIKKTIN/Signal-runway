# v0.8 M1 冲刺与三段原型交付

2026-10-01，制作人。实现真实Player地面/空中向前冲刺与唯一节点充能，三段原型通过同一Main/Course运行。打开scenes/tools/dash_prototypes.tscn按F6，选择捷径、接力或脱险，起跑次数与固定速度均公开注入，成绩隔离；Shift冲刺、Space跳跃、R同图重试、F8返回。

## 实际规则与接口

冲刺0.20秒、水平800，保留重力与垂直速度，无额外无敌、永久速度或延迟。开始扣一次，容量2，开局1；每两个唯一节点补一次，进度0至1，满储备不藏额外次数。伤害取消不返还，恢复保留，重试回初始，暂停和终局不能新启动。流式回收按活动片段清理已充能身份，原片段回跑不能充能。

Player只读字段dash_enabled/dash_charges/dash_progress/dash_remaining/dash_active/dash_used/dash_refilled；dash_snapshot返回enabled/charges/progress/remaining/active/used/refilled。dash_state_changed(snapshot:Dictionary)在业务变化发出，含reason：started/finished/empty/charging/refilled/hurt/death/recovery/control_disabled；RunFlow只转发一次，同名信号，run_started时重新读取新Player。动画逐帧读取remaining，不要求业务逐帧发信号。

SkillLibrary几何skill含kind、required（入口最低储备）、dash_cost（路径总消耗）、expected_refill、entry_x、reward_nodes、stable和dash_windows。空中接力使用两次，但可靠接入前两节点可补一次，因此初始进度0时最低1次能完成；储备/节点未满足时显示不足并可走稳定路线，不承诺玩家失误后仍能完成高路。正式路线与连接接口由B补齐。

## 原型与证据

a-results.json共29断言通过：11资源/优先级/兼容单元与三种原型×三速度×稳定/技能18实际Main路线。headless fixed60，合成SPACE/Shift按实际窗口操作，初始种类、固定速度与稳定路线零储备是明确fixture；脱险技能故意短跳后冲刺救回，无途中位置/前沿/计时注入。

最后证据由a-second-results的未改变项与a-fix-results三档捷径复验合并，原失败a-first/second保留，不称最终版本整套重跑。首轮380首次窄台跳过，通过提前第一起跳区修正；随后380在下降后的第三平台上方错过节点，把捷径末节点移动至真实落地段末端再三速度复验。旧配置比较改为已保存旧生产Profile归一化结果，避免把JSON整数/浮点类型差当生产错误。

dash-motion-results另7个真实CharacterBody/碰撞fixture通过，地面/空中三速度、墙体：0.2秒冲刺后额外采一个正常移动帧，位移164.667至166.333，墙体限制48.443；按住只一次、暂停冻结、真实伤害取消/降速不退款通过。不是纯计算轨迹或瞬移。

Main批量快速创建/销毁的headless原型检查退出有音频WAV播放引用提示，verbose定位为AudioStreamPlaybackWAV/AudioStreamWAV；独立Player动作测试退出无该提示。A不据此声称正式GUI退出生命周期全部通过，后续独立GPU/重试/退出检查核对。本轮技术证据不证明真人趣味性；M1确认动作和选择机会可操作，批准进入B验证无限供给与收益假设。

当前工程默认仍v0.7生成5，M1原型显式使用6；固定模式与旧配置不启用冲刺。实际版本与默认切换由后续实现/最终交付登记，不打包。
