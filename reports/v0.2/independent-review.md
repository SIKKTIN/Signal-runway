# 信号跑道 v0.2 独立技术与表现检查

检查人：主美（art-director），2026-09-30。任务：68970662-1e71-45a5-b606-b1ddb7ff77c3。运行工程只读；本次新增脚本、截图、日志和报告均在任务指定证据范围内。

## 版本与结论

最终被测版本 **v0.2.0+0dd12888c9bf**，完整 SHA256：`0dd12888c9bf9798ce1ca9f5fe5511a569fefb452b827f3d04e850b38f7e6023`。入口 `res://scenes/main/main.tscn`。依据 `reports/v0.2/version-manifest.json` 独立逐个读取56文件，检查文件长度、SHA256与清单聚合哈希；运行前及运行后全部一致，无运行源改动。证据：`independent-checks/version-check.json`。

最终图形进程32项独立关键检查全部通过；前沿像素对比通过。在实际检查范围内未发现剩余阻塞缺陷。可以将本报告提交制作人验收，并作为技术实验源工程交付的依据。报告是否有效由制作人验收；本结论仅覆盖下述测试和观察，不能据此宣布玩家体验成立。

较早候选6433013766cf的一次28项图形运行结果保留为 `independent-checks/runtime-6433013766cf.json`，不作为最终版本证据。最初候选0e5b34e41c9a已被制作人暂停竞态修复替代。

## 环境与复现

Godot `4.7.2-stable (official)`，Windows，D3D12 / Forward+，NVIDIA GeForce RTX4050 Laptop GPU。逻辑画布960×540，实际保存PNG1280×720。测试正常启动图形进程，无 `--headless`，使用 `--fixed-fps 60` 确定物理序列；本脚本不测墙钟准确性。

在工程根目录运行：

```powershell
python reports/v0.2/independent-checks/verify_version.py
& 'E:\Godot\4.7\Godot_v4.7.2-stable_win64_console.exe' --path 'E:\Project\Godot\测试3' --fixed-fps 60 --script res://reports/v0.2/independent-checks/check_runtime.gd --log-file 'E:\Project\Godot\测试3\reports\v0.2\independent-checks\runtime.log'
python reports/v0.2/independent-checks/check_pixels.py
python reports/v0.2/independent-checks/verify_version.py
```

结果在 `independent-checks/runtime-results.json`（含32项名称、实际值、方法和版本）、`pixel-results.json`、`runtime.log`。进程退出码0。日志中的user://着色器缓存目录及系统根证书读取错误为本机受限运行环境信息；图形与声音资源正常加载，无脚本解析、资源加载或退出音频/ObjectDB泄漏错误。

输入检查通过 `Input.parse_input_event` 注入真实按键事件，经过正式菜单焦点、GUI、流程和物理循环；不是仅调用开始或重开函数。标记fixture的检查会直接设置位置或提交候选，用于确定状态竞争和分支；不是正常路线通关或真人体验证明。边界像素检查在真实Esc暂停后暂时隐藏暂停卡片、切换ChaseVisual绘制，保持同一帧世界/HUD比较。

## 实际检查步骤、预期与结果

下表均针对最终冻结版。具体单项与数值见runtime-results.json；失败时按表中步骤和脚本可复现。本轮各项实际均符合预期。

| 检查与步骤 | 预期 | 实际 |
| --- | --- | --- |
| 主入口菜单；按Enter；不操作90物理帧 | 默认追赶，进入ready；首次动作前计时和前沿不动 | pursuit/ready；elapsed=0，front=-544，grace=2 |
| D按住20帧并释放12帧 | 首次移动启动一次，缓冲期间前沿不动 | elapsed=0.5333，grace=1.4667，front=-544；角色x186.1667 |
| 再等待100帧 | 缓冲结束，前沿按最终速度推进 | grace=0，front=-490，speed=270；ThreatLoop已加载并播放 |
| A按住12帧、释放6帧 | 回退和追赶共同缩短距离 | 角色x186.1667→133.9167；gap666.1667→532.9167 |
| 实际Esc暂停，等待45帧 | 用时、前沿、角色、表现动画和威胁循环冻结 | 前后快照完全一致；音频位置0.1946667未变，stream_paused=true |
| 暂停中实际R，等待60帧 | 解除暂停，清空本轮并等待新动作；不沿用旧威胁声 | ready，elapsed/deaths=0，front=-544，grace=2，chase关闭、循环停止 |
| 新轮D移动后放开，缓冲结束后抽样6帧 | 固定速度270，停留真实耗距 | 实测速度270.000000000001，无夹距或变速 |
| 持续停留，观察near/urgent与HUD | 等级消费控制器；余量按实际gap/speed估算；最终被吞一次 | near与urgent均出现；gap153.1667 /270显示0.6秒；4.68秒caught，gap=-4.3333，失败1次、成功0次 |
| caught结果及重复提交goal/失败 | 卡片明确原因，计时/前沿冻结、循环停止；重复候选不二次结算 | “被崩塌吞没”，00:04.68，循环停止；caught短声正在播放；重复候选后仍失败1次 |
| 结果页实际Enter | 完整重开，不遗留死亡状态 | ready，failure_reason清空，player.dead=false |
| 同一回调提交goal、caught、fall、player.die(spike) | 失败胜过终点，原因优先spike，只发布一次，不更新成功最佳 | failed/spike；累计失败2次、成功0次；best=-1（事件fixture） |
| 新轮将角色放在y700，经过真实物理循环 | 超过坠落阈值结束追赶，显示对应图标和文字 | failed/fall，“坠入空隙”（位置fixture） |
| 返回菜单，实际Down与Enter选第二按钮 | 键盘可进入原计时模式；无追赶表现 | ready/time_trial，非测试房；chase关闭，HUD隐藏，ThreatLoop停止 |
| 原模式将角色放到x622/y433尖刺区；等待5帧再24帧 | 真实危险碰撞进入恢复；回起点，死亡数累计、计时继续 | recovering/deaths1 → running/deaths1，elapsed1.0167，x96，角色存活（位置fixture） |
| 运行中player.die(spike)，同一回调toggle_pause | 已提交危险不得因暂停丢失；失败并解除暂停 | failed/spike，tree.paused=false，发布一次失败，表现也解除暂停（竞态fixture） |
| 先暂停，再player.die(fall) | 晚到死亡也结束追赶，不停在死角色状态 | failed/fall，tree.paused=false（竞态fixture） |
| 先_on_goal(player)，立即暂停，再实际Esc继续 | 暂停保留候选；继续后成功一次 | paused且_goal_pending=true；继续后finished，候选清除（竞态fixture+实际继续） |
| 先暂停，再_on_goal(player)，实际Esc继续 | 晚到终点也保留候选；继续后成功一次 | paused/pending=true；继续后finished，成功计数仅增加1（竞态fixture+实际继续） |
| 原模式先暂停，再player.die(spike)，实际Esc继续 | 保持暂停，恢复源状态改为recovering；继续后正常重生 | paused/recovering/deaths1 → running/deaths1，存活且回到x96（竞态fixture+实际继续） |
| 返回菜单并退出场景 | 不遗留威胁HUD、循环或退出音频资源 | HUD隐藏、循环停止；释放场景并等待后正常退出 |

## 旧暂停缺陷与修复复测

制作人报告的旧缺陷，严重度 **P1，阻塞**：在原候选0e5b34运行状态调用player.die('spike')提交失败，然后在deferred仲裁前立即toggle_pause。旧仲裁排除paused并清除候选，会留下死角色而没有失败结果；继续后仍不能完成正常本轮流程。关联风险还有暂停后晚到死亡、已排队或晚到终点、原模式晚到死亡恢复。

这项旧缺陷由制作人发现和修复；本轮未独立运行旧源码重现，不能把旧版实际失败归为独立发现。本轮按同一回调顺序在最终0dd128版完成上述8项独立复测，全部通过，旧阻塞在这些复现路径下已解决。制作人的历史与新增33项集成记录见 `integration.md`、`integration-results.json`。未修改制作人源码或主美已冻结资源。

## 视觉与音效观察

最终版本捕获12张真实GPU截图：菜单、ready、grace、pause、near、urgent、前沿开/关、caught、spike、fall、time_trial。逐张检查菜单、警告、暂停和三种失败页面；名称与图标一致，结果卡片正文和再玩/返回按钮均在画面内，无裁切。Enter、Down、Esc、R已走真实按键路径。安全等级图标与字体资源的预览和加载另见C资源报告；本轮独立局部停留轨迹主要观察near、urgent。

灰度及640×360缩小图检查：角色轮廓、地面边缘、尖刺和警告图形仍可辨认；三种失败图标和原因标题可区分。HUD位于右上，和计时条、主要角色/地面区域分开；较小操作说明在缩小图中字号较小，未据此认定所有低分辨率设备可读。

正式主场景前沿像素对比：世界front=23；画布x23乘1280/960得到PNG边界x30.6667；绘制开关造成的最右变更列为30，右侧从31列起所有像素完全相同。角色左边缘176.1667，前沿未画在角色或前方地面。`pixel-results.json`记录实际PNG尺寸；不使用纹理句柄报告的1707×960计算比例，避免混淆DPI与导出像素。自然caught发生时gap<=0，和真实碰撞左边缘判定一致。

声音结论仅为引擎状态检查：ThreatLoop单播放器已加载，暂停位置冻结；重开、失败、原模式和菜单正确停止，caught时短声触发；退出无资源遗留警告。C另有循环接缝数值检查和13项生命周期检查。本轮没有人的试听，不能宣称响度舒适、音色效果或音乐性通过。

## 引用范围与未覆盖项

制作人同版本集成说明引用33项集成、20项原模式回归、5条普通输入路线和正常图形墙钟检查，本轮未重复整套运行。全程通关48.6167秒、两处分别停止移动2秒后的50.6333/50.6167秒结果引用 `route-budget.md` / `route-budget-results.json`；两处停止是分别测试，不声称同一条路线同时停两次。最终版本0dd128正常图形进程3.000702秒墙钟对应游戏3.0166667秒，差0.0159647秒；引用 `realtime-clock.json`（deliveryVersion与本报告一致，passed=true）。本轮fixed-fps测试只验证状态和有效游戏时间逻辑。

尚未独立覆盖全程真人操作、外部玩家研究、紧张感/趣味性、主观听感、其他系统/GPU、手柄、长期存档。本轮没有用位置/事件fixtures、自动路线或AI画面观察代替这些结论。最终工程发布与F收口由制作人负责。
