# E补充：恢复站当帧显示同步

主美，2026-10-01。制作人在RunFlow._resolve_result处理有效路线事件后立即调用_update_ui，修正首次补血接入帧的生命/得分显示延迟；奖励判定未改。

本次只运行capture_heal_same_frame.gd，同seed404首站404:22、380速度、定点起跑与预置2生命/前沿间隔fixture，沿实际物理路线及合成SPACE接入heal。**首次收到station事件的处理帧立即取样，没有再等待物理帧，没有手动调用_update_ui**：实际health3、显示health3、hurt_count1、表现clock4.05秒，恢复站消息“生命+1”。same-frame-healed-960.png已目视确认3/3与反馈一致。

same-frame-results.json记录通过结果和该RunFlow源码SHA256。GPU正常退出0，无脚本或资源释放警告；仅已知shader缓存和证书沙盒日志。未改生产文件，未重跑E其余22项或F。原E的2/3瞬时帧和等两帧后的3/3证据保留，本补充证明制作人最新同步修复。

本补充形成时E原反馈已经验收，未追加或改变原证据版本；作为后续F/G的显示修复证据保存。F使用包含该Root修复的冻结候选。
