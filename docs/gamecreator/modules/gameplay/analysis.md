# 测试3

> 文档生成时间：2026-10-01T03:18:51.906Z
> 文档内容基准：d4ea0829c8b40dc8141634a6baf70f78b4f1636598178bc499808aad19c38f76

> 项目版本：v0.4.1
> 由 GameCreator 同步，供开发查阅。

[返回目录](../../README.md)

更新项目前先读 [项目规范](../project-management/standards.md)。

## 数值分析

### 移动手感与首关节奏初始假设

初始调参假设（均未验证）：水平最高速度约280 px/s，试验范围180–420；参考跳高96 px，试验范围64–144；离地补跳约0.10 s，试验范围0.05–0.18；提前按键缓冲约0.12 s，试验范围0.05–0.20；死亡到重新可操作目标不超过0.8 s。每次只调整少量参数，记录构建版本与实际感受。试玩记录首次通关用时、各段死亡数、危险误判、重试次数与是否主动追求更短用时；未测数据不写成达标。

- 关联玩法：f64db0c1-acae-4d73-8362-a25630145b76
- 参数 run_speed（最大水平速度）：{"kind":"constant"}；单位 px/s；范围 180～420
- 参数 jump_height（参考跳跃高度）：{"kind":"constant"}；单位 px；范围 64～144
- 参数 coyote_time（离地补跳窗口）：{"kind":"constant"}；单位 s；范围 0.05～0.18
- 参数 jump_buffer（提前按键缓冲）：{"kind":"constant"}；单位 s；范围 0.05～0.2
- 参数 respawn_delay（死亡至可操作间隔目标）：{"kind":"constant"}；单位 s；范围 0～1.5
- 一秒水平位移：`run_speed`；单位 px；目标 null～null
- 输入容错窗口总量：`coyote_time + jump_buffer`；单位 s；目标 null～null

#### 当前配置
- 当前值：{"run_distance_1s":280,"forgiveness_window":0.22}
