extends Control
const Main=preload("res://scenes/main/main.tscn")
const Profile=preload("res://scripts/level/generation_profile.gd")
const Skill=preload("res://scripts/level/skill_library.gd")
var trial: Node2D
var chrome: VBoxContainer
var resource_choice: OptionButton
var speed_choice: OptionButton
const RECORD="user://signal_runway_prototype_v08.json"
func _ready() -> void:
	preload("res://scripts/core/input_bindings.gd").configure()
	process_mode=Node.PROCESS_MODE_ALWAYS
	theme=load("res://scenes/ui/skins/chase_theme.tres")
	var background:=ColorRect.new()
	background.color=Color("0b141c")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(background)
	chrome=VBoxContainer.new()
	chrome.position=Vector2(120,100)
	chrome.size=Vector2(720,340)
	add_child(chrome)
	var title:=Label.new()
	title.text="信号冲刺 · 三段玩法原型"
	title.add_theme_font_size_override("font_size",26)
	chrome.add_child(title)
	var text:=Label.new()
	text.text="SPACE跳跃 · Shift向前冲刺 · 两个新节点补充一次\n资源与跑速为调试注入，成绩隔离。R同图重试，F8返回。"
	chrome.add_child(text)
	resource_choice=OptionButton.new()
	for i in 3:
		resource_choice.add_item("起跑冲刺 %d 次（注入）"%i,i)
	resource_choice.select(1)
	chrome.add_child(resource_choice)
	speed_choice=OptionButton.new()
	for speed in [280,330,380]:
		speed_choice.add_item("固定跑速 %d（注入）"%speed,speed)
	chrome.add_child(speed_choice)
	for kind in ["shortcut","relay","rescue"]:
		var button:=Button.new()
		button.name=kind.capitalize()
		button.text=Skill.NAMES[kind]
		button.pressed.connect(func():play(kind))
		chrome.add_child(button)
func play(kind: String) -> void:
	stop()
	chrome.hide()
	trial=Main.instantiate()
	trial.generation_profile=Profile.defaults()
	trial.record_path=RECORD
	trial.dash_prototype_kind=kind
	trial.trial_speed=float(speed_choice.get_selected_id())
	add_child(trial)
	trial.start_endless(404)
	trial.player.dash_charges=resource_choice.get_selected_id()
	var hint:=Label.new()
	hint.position=Vector2(24,170)
	hint.text=Skill.NAMES[kind]+" · 资源/跑速注入 · 成绩隔离 · F8返回"
	hint.add_theme_color_override("font_color",Color("ffd166"))
	trial.ui.add_child(hint)
func stop() -> void:
	if is_instance_valid(trial):
		get_tree().paused=false
		remove_child(trial)
		trial.queue_free()
		trial=null
	for action in ["jump","dash"]:
		Input.action_release(action)
	for suffix in ["",".tmp",".bak"]:
		if FileAccess.file_exists(RECORD+suffix):
			DirAccess.remove_absolute(RECORD+suffix)
	if is_instance_valid(chrome):
		chrome.show()
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_F8 and is_instance_valid(trial):
		stop()
		get_viewport().set_input_as_handled()
