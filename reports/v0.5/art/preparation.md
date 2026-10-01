# v0.5 F 资源与状态栏准备

主美，2026-10-01。按制作人授权先做资源/UI草稿，**未提交正式F开始或验收**；等待A/C通过及接口冻结通知。没有修改业务、随机、生命、成绩、project.godot、旧美术代码或进行Git操作。

## 交付

- scenes/ui/v05_status.tscn、v05_status.gd，继承Control，签名update_state(health:int,target_speed:float,actual_speed:float,invulnerable:bool,hurt_count:int=0)。根安装/模式可见性由制作人维护。
- 三点生命数字+图形、实际/目标跑速、受伤/无敌/加速文字及短速度条；默认(24,450)380×60。旧操作说明y497需根另移或隐藏，常规y448落脚白沿在其上方保留。
- 可选set_feedback_active(bool)供根菜单/结果关闭局部动画，暂停读取get_tree().paused；初始静默、重复快照去重、重开清理反馈。默认不启用伤害音效。
- assets/visual/v05/platform_cap.svg(128×16)、ground_side.svg(64×64)、route_upper.svg(80×28)，白顶沿/弱侧面/金色上路语言；只读贴最终几何的画法在docs/art/v0.5.md。
- assets/audio/v05/hurt_tick.wav，0.16秒/48kHz/16bit mono，峰值约-14dBFS，播放器额外-6dB，非致命短cue，默认不自动播。

## 草稿验证

Godot4.7.2 / D3D12 Forward+ / RTX4050 Laptop正常GPU CLI，check_status.gd，fixed-fps60，10项准备检查全部通过：初始静默、actual/target区分、伤害去重、暂停clock/pulse冻结、提示到期、低生命/最大目标、新局清理、根结果gate、位置尺寸、零生命不播非致命反馈。status-preparation.json有原值。

1280×720与960×540使用同一960×540逻辑画布截图，目视全部生命数、图形、实际/目标与第二行文字可读。满血、加速、受伤、低生命、空生命及灰度图均在本目录；两张暂停PNG全图变更像素0，数值/资源尺寸及六项源码hash在status-pixels.json。UI内短局部红色提示不全屏闪白，不遮盖场景白顶沿。

示范平台和路线是为审资源而设的人工布局，不是C的真实生成几何或可达路线，状态值也是直接模拟快照，不证明伤害、加速、掉坑恢复、无敌时长或碰撞规则成立。样例通过Image.load_from_file读取SVG，Godot提示该方式不适合导出；它仅位于检查脚本，正式Course须按标准Godot资源导入/load使用，不复制此临时加载方式。当前交付源工程，不打包。

声音仅做PCM长度/峰值技术分析；未验证正式伤害触发链或主观试听。初次检查脚本的类型推断错误仅在独立样例内修复，最终退出0。沙箱shader目录/根证书读取报错仍是环境限制；资源SVG读取有上述明确样例加载警告，未掩盖。

## 后续

F正式开始后消费A/C冻结实际状态/几何，核对平台/角色/危险边界、真正主场景两尺寸、暂停重试和工具F8避让。G按正式任务对至少3种子、上下路收益、受伤挽回和工具/入口做同版本独立操作，明确注入状态与时钟；当前准备不替代F/G验收。
