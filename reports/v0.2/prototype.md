# v0.2 追赶规则原型

2026-09-30，制作人实现 chase_controller.gd，并从真实主场景接入玩家、输入、暂停和失败重开。Godot 4.7.2 stable。规则初始值为起点后640px、首次有效输入后2秒缓冲、260px/s推进；最终速度在首关预算任务决定。

validate_chase.gd 的12项检查通过：等待不推进、缓冲与剩余delta、零有效时间冻结、前进拉距、回退耗距、大步长越界、反向进入已吞区域、20轮重置、停留被吞和警告回差。结果为 prototype-results.json。

validate_chase_flow.gd 的8项主场景检查通过：默认追赶入口、等待首次动作、真实D键启动缓冲、真实Esc暂停冻结、暂停中真实R重开、原地开始后最终被吞、失败冻结、再玩清理。原地轨迹在4.4333秒失败，只发布一次结果。结果为 prototype-flow-results.json。

控制器公开属性 front_x、gap_px、warning_level、grace_remaining；reset(spawn_x)、set_enabled(value)、advance(active_delta,player_left_x)；threat_updated(front_x,gap_px,warning_level,grace_remaining)。warning_level为grace/safe/near/urgent/stopped。流程输出mode_changed(mode)、pause_changed(paused)、run_failed(reason,elapsed,furthest_ratio)、原run_finished(elapsed,deaths,best)。模式time_trial/pursuit，原因spike/fall/caught。

主干优先级在玩家物理运动后取碰撞体左边缘，填充半平面判定避免薄触发器跳过。暂停时不向控制器提供有效delta；重开同时重建World、角色、镜头、追赶和表现，清除旧结果候选。失败仲裁由流程统一处理，下一步在集成任务检查同帧竞争及双模式完整回归。

本轮结果说明规则和真实输入原型可运行。尚未把这20项检查当作首关可达、正式视听或主观趣味性的证明。
