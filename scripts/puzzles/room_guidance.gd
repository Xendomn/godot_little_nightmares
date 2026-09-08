extends RefCounted
## Derive the next useful step from the same requirements used by the puzzle.
const PART_NAMES := {"fuse":"保险丝", "gear":"齿轮", "weight":"砝码", "wheel":"手轮"}

static func objective(room: Node3D, actor: Node3D) -> String:
	if room.completed: return "通道已开启 · 沿亮起的引导向右前进"
	if room.theme == "workshop" and room.index == 0 and not room.fuse_revealed:
		return "移开木箱，寻找后面的保险丝"
	for goal in room.spec.goal:
		if not room.met(str(goal)): return requirement(room, str(goal), actor, 0)
	return str(room.spec.objective)

static func requirement(room: Node3D, expression: String, actor: Node3D, depth: int) -> String:
	if depth > 12: return str(room.spec.objective)
	for term in expression.split("&"):
		if room.met(term): continue
		var parts := term.split(":")
		var device = room.objects.get(parts[0])
		if device == null: return str(room.spec.objective)
		for need in device.spec.get("needs", []):
			if not room.met(str(need)): return requirement(room, str(need), actor, depth + 1)
		var title: String = device.display_name()
		if device.spec.kind == "socket":
			var part: String = str(PART_NAMES.get(device.spec.accept, "部件"))
			var held = actor.get_node("Interactions").carried
			if held != null and held.item_kind == device.spec.accept and held in room.objects.values():
				if device.position.y > 2.8 and room.to_local(actor.global_position).y < 2.8 and room.lift:
					if not room.met(str(room.spec.lift)): return requirement(room, str(room.spec.lift), actor, depth + 1)
					return "携带" + part + "乘右侧升降台，装入" + title
				return "将" + part + "装入" + title
			for item in room.objects.values():
				if "item_kind" in item and item.item_kind == device.spec.accept and item.socket != device:
					if item.position.y > 2.8 and room.to_local(actor.global_position).y < 2.8 and room.lift:
						if not room.met(str(room.spec.lift)): return requirement(room, str(room.spec.lift), actor, depth + 1)
						return "乘升降台取回上层的" + part + "，再送往" + title
			return "取回" + part + "，送往" + title
		if device.position.y > 2.8 and room.to_local(actor.global_position).y < 2.8 and room.lift:
			if not room.met(str(room.spec.lift)): return requirement(room, str(room.spec.lift), actor, depth + 1)
			return "乘右侧升降台前往上层，操作" + title
		if device.spec.kind == "plate":
			if room.spec.get("press", false) and room.met("power:1"):
				return "先关闭压机电源，再把货箱推入黄铜框"
			return "将货箱送入" + title + "的黄铜框"
		if device.spec.kind == "selector":
			return "调整" + title + "：" + device.state_label(int(parts[1]) if parts.size() > 1 else 1)
		if device.spec.kind == "brake": return "操作" + title + "，趁停摆时通过；青灯亮起时可通行"
		return "操作" + title
	return str(room.spec.objective)
