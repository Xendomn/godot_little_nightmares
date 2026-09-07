extends RefCounted
## Contextual vocabulary for the 24 authored bays; editor specs can override it.
const NAMES := {
	"workshop": [
		{"hatch":"维修通道闩", "fuse_socket":"维修电源插座"},
		{"route":"配电旋钮", "upper_latch":"上层回程梯闩", "cargo":"货运通道闩"},
		{"belt":"传送带方向旋钮", "cargo_plate":"货箱踏板", "delivery":"货运出口闩"},
		{"power":"压机电源开关", "limiter":"压机限位踏板", "service":"检修通道闩"},
		{"socket_a":"升降台电源插座", "socket_b":"应急照明插座", "junction":"双路联动闩"},
		{"belt":"追逐传送带旋钮", "barrier":"追逐通道闸门闩", "chute":"货运滑槽闩"}],
	"laundry": [
		{"inlet":"进水阀", "drain":"排水阀", "outlet":"水槽出口阀"},
		{"float_plate":"供水踏板", "fill":"灌水阀", "high_valve":"高台出口阀"},
		{"transfer":"水箱连通旋钮", "left_valve":"上层左水箱阀", "right_valve":"右水箱出口阀"},
		{"basket":"货篮升降开关", "valve_socket":"出口阀轮轴", "return":"机房出口阀"},
		{"bypass":"旁路阀轮轴", "pressure":"压力分配旋钮", "vent":"上层排气阀", "seal":"密封闸门阀"},
		{"wheel_drive":"水轮齿轮座", "timing":"蒸汽节拍旋钮", "steam_lock":"蒸汽出口闩"}],
	"thread_vault": [
		{"tray_a":"左配重托盘", "tray_b":"右配重托盘", "landing":"上层停靠闩"},
		{"lower":"下层配重托盘", "stop":"货篮停靠棘爪", "upper":"右侧配重托盘"},
		{"tray":"桥面配重托盘", "pin":"上层锁桥插销", "reuse":"出口配重托盘"},
		{"hoist":"竖井绞盘开关", "receiver":"高处配重托盘", "shaft_gate":"竖井出口闩"},
		{"bell":"引开守卫的铃", "hoist":"货篮绞盘开关", "quiet_gate":"上层安全门闩"},
		{"winch_a":"左绞盘配重座", "pin_a":"第一段桥插销", "winch_b":"右绞盘配重座", "pin_b":"第二段桥插销", "far_latch":"远端出口闩"}],
	"clocktower": [
		{"gear_socket":"主轴齿轮座", "direction":"主轴方向旋钮", "gear_door":"主轴门闩"},
		{"clutch":"动力离合旋钮", "shortcut":"上层捷径闩", "pendulum_gate":"摆锤通道闩"},
		{"brake_a":"第一组摆锤制动杆", "brake_b":"第二组摆锤制动杆", "phase_gate":"摆锤出口闩"},
		{"lift_power":"升降传动齿轮座", "slow_axis":"慢轴齿轮座", "fast_axis":"快慢轴联动闩"},
		{"counterweight":"钟锤配重座", "phase":"钟面相位旋钮", "clock_brake":"钟锤制动杆", "hammer":"钟锤释放闩"},
		{"release":"终钟释放闩", "brake_a":"晨光第一制动杆", "brake_b":"晨光第二制动杆", "sunrise":"晨光出口闩"}]
}
const STATES := {
	"workshop/1/route":["断电", "升降台供电", "货运通道供电"],
	"workshop/2/belt":["停止", "向右输送", "向左反转"],
	"workshop/3/power":["压机断电", "压机通电"],
	"workshop/5/belt":["停止", "正向运转", "反转阻挡追逐"],
	"laundry/0/inlet":["关闭进水", "开启进水"],
	"laundry/2/transfer":["停止输水", "左侧浮台升起", "中间水位", "右侧出口加压"],
	"laundry/3/basket":["货篮停用", "货篮运行"],
	"laundry/4/pressure":["停止供压", "上层升降供压", "密封门供压"],
	"laundry/5/timing":["未同步", "第一节拍", "喷口依次休息"],
	"thread_vault/3/hoist":["绞盘停止", "货篮运行"],
	"thread_vault/4/hoist":["绞盘停止", "货篮运行"],
	"clocktower/0/direction":["停止", "正向传动", "反向传动"],
	"clocktower/1/clutch":["动力断开", "升降台动力", "摆锤线路动力"],
	"clocktower/4/phase":["刻度 0", "刻度 I", "刻度 II", "刻度 III · 钟锤对齐"]
}
const PARTS := {"fuse":"保险丝", "wheel":"阀轮", "gear":"齿轮", "weight":"砝码"}

static func describe(theme: String, index: int, object_id: String, spec: Dictionary) -> Dictionary:
	var names: Array = NAMES.get(theme, [])
	var authored: Dictionary = names[index] if index >= 0 and index < names.size() else {}
	var fallback: String = {"selector":"档位旋钮", "socket":"部件插座", "brake":"制动杆", "latch":"机关闩", "plate":"重物踏板"}.get(spec.get("kind", ""), "机关")
	return {"display_name":spec.get("display_name", authored.get(object_id, fallback)), "state_names":spec.get("state_names", STATES.get("%s/%d/%s" % [theme,index,object_id], []))}
