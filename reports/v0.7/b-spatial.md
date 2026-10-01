# v0.7 空间结构与路线组合验收

2026-10-01。生成revision5包住原revision4段落编排，四结构按距离阶段/空间权重采样；地面净高度随机但有界，入/出地面一致。挑战片段保持原三节点/出口奖励，新增高路延续和汇回片段，不增加节点或追赶延迟；恢复站附近限制延续长度。

generation-results.json记录100种子×200段，通过坡度/高度/内部主路/跨段主路及高路、确定性、挑战连续上限、中继与恢复站间隔。四结构均有样本；旧2/3/4各100种子×200段与保存的旧生成器精确快照一致。

geometry-results.json合并90组通过轨迹：四结构及两片段高路、3高度/间距包络×280/330/380×正常/显式受伤。真实Player/move_and_slide与真实碰撞，自动跳跃、headless fixed60，不是人工操作。高路三个实际节点接入并在接缝保持对应高度，再汇回主路。

初次控制器过早释放按键，修正后发现高台灰盒漏接64单位地面；补齐实体连接并增加内部连续检查。下一轮高台和高路通过，断桥最高档缺少同高第二平台起跳窗；补齐该窗并只重跑剩余6组。最终90是84继承加6复验，原三轮结果保留，不声称一次全通过。窗口只表达起跳/落脚候选，不是实时规划器或所有随意按键都能成功的保证。

几何契约：ground_segments元素{from,to}是局部Vector2主地面顶沿；polygons是局部PackedVector2Array实体轮廓；routes元素{from,to,kind}，kind为primary/upper/merge；jump_windows含Rect2 takeoff/landing及Vector2 from/to与kind。connection保存入口/出口地面、可选高路高度(-1为无)、upper_from/upper_to及chain_id。spatial_id是slope/terrace/bridge/basin，zone为坡地区/高架区/下沉区/恢复区。chunk.origin是重定位后的局部横坐标，geometry纵坐标为实际世界y；global_x=origin+total_offset+local_x。

challenge仍属于原单片段，出口x976结算；高路延续只是路线连接，原片段完成后不继续连段、不重复声音/分数/延迟。前方至少保留可达主路，高路可随时落回安全主路；桥接的主路在真实平台上。
