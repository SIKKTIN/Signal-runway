extends RefCounted
const Legacy = preload("res://scripts/level/endless_library.gd")
const STRUCTURES := {"step": "阶梯抬升", "safe_b": "下沉回升", "gap": "断层桥接", "rhythm_a": "连续平台链", "relay_a": "上下双路线", "relay_b": "高处接入回落"}
static func build(id: String, height: float = 48, spacing: float = 80, variant: int = 0) -> Dictionary:
	var d := Legacy.definition(id)
	d.structure = STRUCTURES.get(id, "原有片段")
	d.variant = variant
	d.parameters = {"height": height, "spacing": spacing}
	d.vertical = id in STRUCTURES
	d.routes = []
	d.validation = "发布参数库有实际动作验收，当前预览未实时动作模拟"
	if not d.vertical:
		return d
	d.walls = []
	d.spikes = []
	d.gaps = []
	d.platforms = []
	d.relays = []
	var h := height
	match id:
		"step":
			d.floors = [Rect2(0,448,304,160), Rect2(304,448-h,224,160+h), Rect2(528,448-2*h,224,160+2*h), Rect2(752,448-h,224,160+h), Rect2(976,448,304,160)]
		"safe_b":
			d.floors = [Rect2(0,448,304,160), Rect2(304,448+h,224,160), Rect2(528,448+2*h,224,160), Rect2(752,448+h,224,160), Rect2(976,448,304,160)]
		"gap":
			# Broad bridge surfaces allow both slow and fast landing, no mandatory wall jump.
			d.floors = [Rect2(0,448,320,160), Rect2(960,448,320,160)]
			d.platforms = [Rect2(320+spacing,448-h,240,24), Rect2(640+spacing/2,448-h,240,24)]
			d.gaps = [Rect2(320,448,640,92)]
		"rhythm_a":
			d.floors = [Rect2(0,448,1280,160)]
			d.platforms = [Rect2(288,448-h,200,20), Rect2(488+spacing,448-2*h,200,20), Rect2(768,448-h,208,20)]
			# Primary ground route remains a safe exit if a platform jump is missed.
		"relay_a", "relay_b":
			d.floors = [Rect2(0,448,1280,160)]
			d.platforms = [Rect2(288,448-h,200,20), Rect2(488+spacing,448-2*h,200,20), Rect2(768,448-h,208,20)]
			# Shared landing after the upper platform lets both routes collect the
			# base reward. A 64-high upper route must not trade away that reward.
			d.relays = [{"local_id":"low", "position":Vector2(1010,410)}, {"local_id":"high", "position":Vector2(588+spacing,448-2*h-34)}]
			if id == "relay_b":
				d.relays.append({"local_id":"crest", "position":Vector2(860,448-h-34)})
	var surfaces: Array = d.floors + d.platforms
	for i in surfaces.size():
		var rect: Rect2 = surfaces[i]
		d.routes.append({"surface":i,"from":rect.position,"to":Vector2(rect.end.x,rect.position.y),"kind":"upper" if i >= d.floors.size() else "primary"})
	return d
