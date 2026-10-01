extends "res://reports/v0.6/independent-checks/check_tools.gd"
## Targeted visible-label supplement; no production mutations.
func run() -> void:
	print("F_VISIBILITY_PID ",OS.get_process_id())
	var before:=hashes()
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size=Vector2i(960,540)
	root.size=Vector2i(960,540)
	editor=load("res://scenes/tools/generation_editor.tscn").instantiate()
	root.add_child(editor)
	await frames(4)
	editor.count_control.value=30
	editor.regenerate()
	var selected: Dictionary=editor.rows.filter(func(row):return row.geometry.has("challenge"))[0]
	editor.select_chunk(int(selected.index))
	editor.speed_choice.select(2)
	await press_button("PlaySelected")
	isolate_trial("visibility")
	await frames(12)
	var trial: Node2D=editor.trial
	var hint_panel: Control=trial.ui.get_node("EditorReturnHint")
	var hint: Label=hint_panel.find_children("*","Label",true,false)[0]
	var result:= {"selected_index":selected.index,"notice_text":trial.ui.notice.text,"notice_visible":trial.ui.notice.is_visible_in_tree(),"notice_parent_visible":trial.ui.notice.get_parent().is_visible_in_tree(),"hint_text":hint.text,"hint_visible":hint.is_visible_in_tree(),"run_distance":trial.run_distance,"elapsed":trial.elapsed,"trial_speed":trial.trial_speed,"world_position":str(trial.player.position),"source_version":"v0.6.0+9d61537a86e4"}
	result.passed=(result.notice_visible and result.notice_text.contains("定点")) or (result.hint_visible and result.hint_text.contains("定点"))
	await shot("tool-selected-start-visibility")
	await tap(KEY_F8)
	root.remove_child(editor)
	editor.free()
	await frames(8)
	OS.delay_msec(150)
	result.sources_unchanged=before==hashes()
	result.method="Actual focused Enter on PlaySelected, synthetic input, fixed60 GPU. Read is_visible_in_tree and screenshot after 12 frames. Public selected start is a debug injection; no production or formal-record writes. Supplement replaces the original text-only coverage claim."
	var file:=FileAccess.open(OUT_F+"selected-visibility-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	file.close()
	print(JSON.stringify(result))
	quit(0)
