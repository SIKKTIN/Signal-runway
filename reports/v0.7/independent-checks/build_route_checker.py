from pathlib import Path
import re
folder=Path(__file__).resolve().parent
root=folder.parents[2]
s=(root/'reports/v0.6/independent-checks/check_routes.gd').read_text(encoding='utf-8-sig')
s=s.replace('reports/v0.6/','reports/v0.7/').replace('Natural v4 routes','Natural v5 routes').replace('105_','109_')
s=s.replace('return {"v06":file_hash(Record.DEFAULT_PATH),"v05":file_hash(Record.V05_PATH),"earlier":file_hash(Record.LEGACY_PATH)}','return {"v07":file_hash(Record.DEFAULT_PATH),"v06":file_hash(Record.V06_PATH),"v05":file_hash(Record.V05_PATH),"earlier":file_hash(Record.LEGACY_PATH)}')
begin=s.index('func step_input()')
end=s.index('func run()',begin)
step='''func step_input() -> void:
	held_frames+=1
	if held and held_frames>4 and app.player.velocity.y>=0:
		released()
	if held or not app.player.is_on_floor() or app.fall_recovery_remaining>0:
		return
	for chunk in app.course.chunks:
		var x: float=app.player.position.x-chunk.origin
		if x<0 or x>chunk.length:
			continue
		for window in chunk.geometry.jump_windows:
			if window.kind!="primary" and route_choice!="upper":
				continue
			var a: Vector2=window.from
			var b: Vector2=window.to
			var lead: float=24 if b.x>a.x+8 else 60
			if x>=a.x-lead and x<a.x+8 and absf(app.player.position.y+15-a.y)<7:
				key(KEY_SPACE,true)
				held=true
				held_frames=0
				presses+=1
				return

'''
s=s[:begin]+step+s[end:]
begin=s.index('\tvar accelerated: bool=')
end=s.index('\tfor seed_value in [404,77,9001]:',begin)
s=s[:begin]+'\tvar accelerated := true\n'+s[end:]
s=s.replace('\t\t\tif results.any(func(row):return row.seed==seed_value and row.strategy==choice):\n\t\t\t\tcontinue\n','')
s=s.replace('\t\t\tvar last_route_events := 0','\t\t\tvar last_route_events := 0\n\t\t\tvar seams: Array[Dictionary]=[]\n\t\t\tvar captured_seam := false')
s=s.replace('\t\t\t\tstep_input()','\t\t\t\tvar previous_x: float=app.player.position.x+app.course.total_offset\n\t\t\t\tstep_input()')
point='\t\t\t\tawait frames(1)\n'
insert='''				var global_x: float=app.player.position.x+app.course.total_offset
				for incoming in app.course.chunks:
					var boundary: float=incoming.origin+app.course.total_offset
					if previous_x<boundary and global_x>=boundary and incoming.geometry.connection.upper_from:
						var expected: float=incoming.geometry.connection.upper_entry_y
						var feet: float=app.player.position.y+15
						seams.append({"incoming_id":incoming.id,"boundary":boundary,"global_x":global_x,"feet_y":feet,"expected_upper_y":expected,"difference":absf(feet-expected),"on_high_route":absf(feet-expected)<6,"elapsed":app.elapsed,"health":app.player.health,"completed":app.routes.completed})
						if seed_value==404 and choice=="upper" and not captured_seam:
							await shot("natural-404-upper-seam-960")
							captured_seam=true
'''
s=s.replace(point,point+insert,1)
s=s.replace('"generator_revision":app.generation_profile.generator_revision','"seams":seams,"generator_revision":app.generation_profile.generator_revision')
needle='\t\t\tprint("F_NATURAL_FINISHED '
pos=s.index(needle)
s=s[:pos]+'''\t\t\tif choice=="upper":
				check("natural_%d_actual_upper_seams"%seed_value,not seams.is_empty() and seams.all(func(row):return row.on_high_route),seams)
'''+s[pos:]
s=s.replace('app._route_status.presentation_state()]','app._route_status.presentation_state(),app.world.get_node("SpatialVisual").presentation_state()]')
method='Actual frozen default v5 Main, all six GPU fixed60 accelerated game time with per-run game/wall seconds. Public same-seed start only; actual Player and synthetic SPACE/Esc. No position/speed/health/front/elapsed-state injection on natural routes. Independent controller plans from actual jump windows, keeps keys at least four frames, and jumps same-height gaps. Live upper seam foot height is recorded at real crossing. Three strategies reach beyond first station. Tool/debug fixtures separate. No human experience or normal wall-clock claim; no Root long/legacy reruns.'
s=re.sub(r'"method":"[^"]+"','"method":"'+method+'"',s)
(folder/'check_routes.gd').write_text(s,encoding='utf-8')
print('Created v0.7 independent route checker')
