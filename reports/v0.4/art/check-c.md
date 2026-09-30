# C 模块化场景与HUD草案检查

主美，2026-09-30，任务d335eb76-b39a-4ebd-b052-d4e7fd2b9db5，允许主美自验收。

交付`docs/art/v0.4-assets.md`所列组件和独立场景；原Environment/Relay/Chase、碰撞/生成/计分源文件未修改。当前模板读取制作人已验收safe_b/relay_a/wall_a的定义。预览只绘图，无CollisionObject2D，不算普通操作路线或计分/存档证明。

## 运行证据

正常GPU CLI：Godot4.7.2 / D3D12 Forward+ / RTX4050 Laptop，fixed-fps60，运行`reports/v0.4/art/check_c.gd`，退出0。12项全通过，明细在c-runtime.json：无碰撞对象、初始化静默、接入+100与纪录、距离更新不重复纪录、暂停三组件时钟、提示到期、单模块重定位相位、结算隐藏提示、重置、重绑唯一监听、seed/分数不被装饰改写、退出断监听。

12张连续GPU帧（c-frames）证明背景信号包与前沿独立动画。c-pause-a/b全图逐像素一致；具体变化数及四个源码hash在c-pixels.json。低影响草案检查至此，不扩大为整套玩法测试。

## 目视检查

c-safe/relay/wall/gain/result的1280×720实际PNG、640×360的50%图及灰度图：总分、距离、中继、纪录排列清晰，危险/安全/中继同时依靠轮廓和文字区分，背景背板低于可落脚地形亮度。顶栏右侧留暂停位置，右侧纪录/威胁/中继toast分层没有互相覆盖。结算动作属于文案草案，无可操作按钮。

日志中user://shader缓存目录和Windows根证书读取报错为当前沙箱环境限制；渲染、资源加载与GDScript均完成，无脚本报错。没有主观试听结论。

## 后续F

F消费D已冻结生命周期，将缓存限制在活动chunk/relay快照，适配重定位和暂停，制作人负责根安装/旧顶栏可见性/结果业务。不把C数值fixture作为F正式功能验收。
