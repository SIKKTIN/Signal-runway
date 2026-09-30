extends SceneTree


func _initialize() -> void:
	call_deferred("_verify")


func _verify() -> void:
	var player := AudioStreamPlayer.new()
	root.add_child(player)
	var failed := false
	for action in ["jump", "wall_jump", "land", "death", "finish"]:
		var path := "res://assets/audio/sfx_%s.wav" % action
		var stream: AudioStream = load(path)
		if stream == null:
			print("AUDIO_CHECK_FAIL %s load" % action)
			failed = true
			continue
		player.stream = stream
		player.play()
		await create_timer(0.04).timeout
		var started := player.playing
		print("AUDIO_CHECK %s duration=%.3f playing=%s" % [action, stream.get_length(), started])
		failed = failed or not started
		player.stop()
	quit(1 if failed else 0)
