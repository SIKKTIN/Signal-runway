extends "res://reports/v0.6/independent-checks/check_tools.gd"
## Only the G label fix; earlier failing evidence remains untouched.
func matches_manifest(actual: Dictionary,manifest: Dictionary) -> bool:
	return manifest.files.all(func(row):return actual.get(row.path,"")==row.sha256)
func run() -> void:
	print("F_FIXED_VISIBILITY_PID ",OS.get_process_id())
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://reports/v0.6/version-manifest.json"))
	var suffix: String=str(manifest.version).split("+")[1]
	var before:=hashes()
	check("105_new_frozen_hashes_match_before",matches_manifest(before,manifest))
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
	var draft_hash:=Profile.fingerprint(editor.draft)
	await press_button("PlaySelected")
	var isolated_path:=isolate_trial("fixed-visibility")
	await frames(12)
	var trial: Node2D=editor.trial
	var panel: Control=trial.ui.get_node("EditorReturnHint")
	var label: Label=panel.find_children("*","Label",true,false)[0]
	var panel_rect: Rect2=panel.get_global_rect()
	var label_rect: Rect2=label.get_global_rect()
	var screen:=Rect2(0,0,960,540)
	var actual: Dictionary={"selected_index":selected.index,"text":label.text,"label_visible":label.is_visible_in_tree(),"panel_visible":panel.is_visible_in_tree(),"panel_rect":str(panel_rect),"label_rect":str(label_rect),"label_minimum_size":str(label.get_combined_minimum_size()),"line_count":label.get_line_count(),"route_rect":str(trial._route_status.get_global_rect()),"life_rect":str(trial._survival_status.get_global_rect())}
	check("selected_label_visible_and_all_three_messages",panel.is_visible_in_tree() and label.is_visible_in_tree() and label.text.contains("定点起跑 · 第%d段"%selected.index) and label.text.contains("距离注入 · 成绩隔离") and label.text.contains("F8返回") and label.get_line_count()==3,actual)
	check("960_label_complete_inside_screen_and_panel",screen.encloses(panel_rect) and panel_rect.encloses(label_rect) and label.size.x>=label.get_combined_minimum_size().x and label.size.y>=label.get_combined_minimum_size().y,actual)
	check("960_hint_avoids_life_and_route_HUD",not panel_rect.intersects(trial._route_status.get_global_rect()) and not panel_rect.intersects(trial._survival_status.get_global_rect()),actual)
	await shot("tool-selected-start-"+suffix+"-960")
	await tap(KEY_F8)
	check("actual_F8_returns_same_draft_and_cleans_trial",not is_instance_valid(editor.trial) and editor.chrome.visible and not paused and Profile.fingerprint(editor.draft)==draft_hash and not FileAccess.file_exists(isolated_path))
	root.remove_child(editor)
	editor.free()
	await frames(8)
	OS.delay_msec(150)
	var after:=hashes()
	check("105_new_frozen_hashes_match_after_and_unchanged",before==after and matches_manifest(after,manifest))
	var passed: bool=checks.all(func(row):return row.passed)
	var file:=FileAccess.open(OUT_F+"selected-visibility-"+suffix+"-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"checks":checks,"version":manifest.version,"sha256":manifest.sha256,"before":before,"after":after,"actual":actual,"method":"Targeted G fix only: actual synthetic Enter on PlaySelected/F8, fixed60 GPU, 960x540, no production writes. The selected start is positional/distance/speed debug injection; not natural balance evidence. Original 9d failure, six routes and 17 mechanical checks preserved and inherited, not rerun."},"\t"))
	file.close()
	quit(0 if passed else 1)
