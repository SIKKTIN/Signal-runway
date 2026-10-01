# v0.6 连段与恢复站检查

2026-10-01，B/C 实现 RouteChallenge 状态与 Main 事件顺序。25 项检查通过：高路入口、三个有序节点与出口奖励、乱序/漏点/落下路/伤害中断、防回跑重启；补血上限、满血、互斥选择、重复接触、回收清理；实际 Flow 暂停、重试、致命伤优先和非致命伤先扣再补、四类分数之和。

rules-results.json 使用状态机事件案例以及实际 Main 的明确位置、血量和站点注入。测试补血从接入点前方同一高度开始扫掠，避免把垂直传送经过积分入口误当自然上路。该报告不代表自然跑到恢复站。

routes-results.json 另从正常开局运行三个种子404/77/9001，每个稳妥和高路策略，共六次运行到首恢复站之后，全部通过。使用真实 Player 与实际几何，脚本自动跳跃，未注入位置、时钟、前沿或速度；高路策略在2000距离显式注入一次伤害，验证首次恢复站补回三生命，已明确标注。高路自然完成至少一个连段，稳妥路线选择站点积分而不完成连段。

额外奖励只加分，首次中继片段的0.9秒延迟预算保持。全局身份随活动片段回收清理，禁止在原挑战或站点回跑重复领取。B/C 接口冻结：RunFlow.route_event(kind,data)、route_state_changed(state)、routes.snapshot()；状态含active/progress/total/completed/interrupted/combo_score/station_score/heal_choices/score_choices/last_event/identities。事件为started、progress、completed、interrupted、station。资源只读取这些状态。

早期路线脚本加速退出出现资源警告，初步怀疑预加载关系，生成器改为运行时创建内层旧生成器后短规则退出干净，但完整路线仍有警告。随后单路线verbose诊断明确列出AudioStreamPlaybackWAV/AudioStreamWAV，不能把初步怀疑认定为根因；测试清理加入实际音频线程释放时间，后续结果另记。早期六路线规则通过与退出警告分别报告。
