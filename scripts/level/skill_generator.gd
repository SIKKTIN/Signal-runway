extends RefCounted
const Profile=preload("res://scripts/level/generation_profile.gd")
const Spatial=preload("res://scripts/level/spatial_library.gd")
const Skill=preload("res://scripts/level/skill_library.gd")
var base: RefCounted
var profile: Dictionary
var rng:=RandomNumberGenerator.new()
var last_skill:=-100
func reset(seed_value: int,settings: Dictionary) -> void:
	profile=settings.duplicate(true)
	base=load("res://scripts/level/spatial_generator.gd").new()
	var old:=Profile.v07_defaults()
	for key in old:
		if key!="generator_revision":
			old[key]=profile[key]
	base.reset(seed_value,old)
	rng.seed=absi((str(seed_value)+":skill6").hash())
	last_skill=-100
func next() -> Dictionary:
	var row: Dictionary=base.next()
	var original: Dictionary=row.geometry
	var skill_due: bool=original.has("challenge") and profile.skill_weight>0 and int(row.index)-last_skill>=int(profile.relay_min)*int(3-profile.skill_limit)
	if skill_due and rng.randf()<float(profile.skill_weight)/float(profile.skill_weight+1):
		var kind:="shortcut"
		if row.stage==1:
			kind="relay" if rng.randf()<0.5 else "shortcut"
		elif row.stage>=2:
			kind=["shortcut","relay","rescue"][rng.randi_range(0,2)]
		var h: float=original.parameters.height
		var d:=Skill.build(kind,original.connection.entry_y,h,int(profile.combo_bonus))
		d.category=original.category
		d.phase=row.stage
		if kind=="rescue":
			base.remaining=0
		else:
			var y: float=d.platforms.back().position.y
			base.upper_y=y
			d.connection.upper_to=original.connection.upper_to
			d.connection.upper_exit_y=y if d.connection.upper_to else -1.0
			d.connection.chain_id=original.connection.chain_id
		var errors:=Spatial.errors(d)
		if errors.is_empty():
			row.geometry=d
			row.reason+=" · 技能："+Skill.NAMES[kind]+" · 入口最低%d次，实时储备不改变布局"%int(d.skill.required)
			last_skill=int(row.index)
		else:
			row.reason+=" · 技能兜底："+"；".join(errors)
			base.remaining=0
			original.connection.upper_to=false
			original.connection.upper_exit_y=-1
	row.skill_candidate=skill_due
	return row
