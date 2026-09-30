# v0.2.1 美术动态优化

用户要求在 v0.3 前让信号崩塌像信号波滚动，让场景动起来。复用冷青/珊瑚红工业信号风格、HUD、音效和事件；修改静态前沿与背景；新增独立环境表现；归档：无。玩家动作、追赶速度、关卡几何与失败判定沿用 v0.2。

## 工作范围

- 主美：scripts/visual、assets/visual、scenes/visual、docs/art、reports/v0.2.1/art。滚动起伏的信号波、覆盖内部流动，多层视差、灯光脉冲和微粒。EnvironmentVisual.bind_flow(flow,camera,course)，World 下 identity transform、z_index=-10。presentation_state() 暴露 animation_time。ChaseVisual 保留全部既有接口与音效生命周期。
- 制作人：Course/RunFlow 接线、版本、运行说明、最终验证与交付。Course.dynamic_environment_enabled 默认 false，只控制旧背景绘制。组件存在并接入后跳过旧背景，碰撞不变。

## 验收

波形和环境有明显连续运动，致命覆盖不越过 front_x；暂停与结算冻结自有动画时钟；重建清零；计时模式没有追赶覆盖。落点、尖刺、墙跳和玩家保持清楚。首关、菜单、测试房可启动。提交图形截图/动画与实际运行报告，自动检查不替代真人试玩。

## 服务状态

开始时 GameCreator CLI 服务不可用，已尝试启动本地应用。用户已授权本次优化及主美调度，先按本地范围执行，服务恢复后补录任务及交付，不直接修改管理存档。

用户启动软件后连接已恢复，正式任务已派发：主美 `212a0ed2-4887-407e-9f78-f1da13accd71`，制作人 `c311f12f-452b-4e87-ae41-3a300bec1a38`。制作与实际验收分别登记。

用户在主美聊天追加纠正：去掉保留的直线。主美按同一制作任务修订，制作人另建最终接入复测 `bdd86fef-8296-47da-b0dc-8e30a9bd18f5`，刷新证据与源清单；初始带直线候选记录保留，但不作为最终交付。
