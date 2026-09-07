extends RefCounted
## Authored chapter data. Coordinates are local to each 46 m puzzle bay.
const IDS := ["workshop", "laundry", "thread_vault", "clocktower"]
const CHECKPOINTS := ["room_1", "room_2", "room_3", "room_3_mid", "room_4", "room_5", "room_5_mid", "room_6", "room_6_mid"]
const TITLES := ["午夜工坊", "染洗间", "悬线库", "钟楼"]

static func control(id: String, kind: String, x: float, needs: Array = [], extra: Dictionary = {}) -> Dictionary:
	var result := {"id":id, "kind":kind, "x":x, "y":0.8, "z":-0.9, "needs":needs}
	result.merge(extra, true)
	return result

static func item(id: String, kind: String, x: float, y: float = 0.08, z: float = 0.5) -> Dictionary:
	return {"id":id, "kind":kind, "x":x, "y":y, "z":z}

static func room(title: String, objective: String, devices: Array, items: Array, goal: Array, hints: Array, extra: Dictionary = {}) -> Dictionary:
	var result := {"title":title,"objective":objective,"devices":devices,"items":items,"goal":goal,"hints":hints}
	result.merge(extra, true)
	return result

static func rooms(id: String) -> Array:
	match id:
		"workshop": return [
			room("藏在木箱之后", "找回维修通道的电力", [control("hatch","latch",16,["fuse_socket"]),control("fuse_socket","socket",12,[],{"accept":"fuse"})], [item("fuse","fuse",8.2,0.08,1.05)], ["hatch"], ["木箱后有一束微弱的蓝光。","箱子既能推，也能向后拉；保险丝可以带走。","按住互动键拉开箱子，把保险丝装进蓝色插座，再打开维修闩。"], {"crate":7.0,"crate_target":3.0}),
			room("一根电缆，两条路", "从上层配电室接通货运通道", [control("route","selector",8,[],{"modes":3}),control("upper_latch","latch",26,[],{"y":4.0}),control("cargo","latch",36,["upper_latch","route:2"])], [], ["cargo"], ["配电旋钮连接着灯和升降台。","升降台通往上层，那里能打开回程梯；货运线路需要另一档电力。","先选升降档，乘台到上层开闩，下梯后切换到第二档，再去出口。"], {"upper":true,"lift":"route:1","ladder_lock":"upper_latch"}),
			room("逆行的传送带", "把货箱送到隔栅另一侧", [control("belt","selector",8,[],{"modes":3}),control("cargo_plate","plate",26,[],{"mass":3.0}),control("delivery","latch",35,["cargo_plate"])], [], ["delivery"], ["黄铜踏板与货箱一样宽。","输送带可以反转，另一端的开关会锁存货箱到位状态。","将货箱推上输送带，选择向右的档位，等货箱压住踏板，再打开货运闩。"], {"crate":12.0,"belt":true,"mid":"cargo_plate"}),
			room("压机的牙齿", "让压机停在可穿行的位置", [control("power","selector",7,[],{"modes":2,"initial":1}),control("limiter","plate",23,[],{"mass":3.0}),control("service","latch",34,["limiter","power:1"])], [], ["service"], ["电机旁的指示灯决定压机是否运行。","支撑车只有在压机断电时才能进入工作区。","断电后把车推入黄框，再接通电源，让机械限位撑住压机。"], {"crate":15.0,"press":true}),
			room("双路重启", "重启主轴与应急照明", [control("socket_a","socket",10,[],{"accept":"fuse"}),control("socket_b","socket",32,[],{"accept":"fuse"}),control("junction","latch",38,["socket_a","socket_b"])], [item("fuse_a","fuse",5),item("fuse_b","fuse",24,3.28)], ["junction"], ["应急回路在楼上还有一只保险丝。","装好第一只后升降台才有电。携带物品时不能爬梯。","装好左侧保险丝，乘升降台上楼，带着第二只保险丝乘台返回，接通右侧回路。"], {"upper":true,"lift":"socket_a","mid":"socket_a"}),
			room("最后一车", "封住追来的脚步，离开工坊", [control("belt","selector",9,[],{"modes":3}),control("barrier","latch",28,["belt:2"]),control("chute","latch",38,["barrier"])], [], ["chute"], ["回转的传送带能拖慢追逐。","远处的门闩控制追逐通道。","将皮带切到反转档，奔向闸门落闩，再打开货运滑槽。"], {"chase":true,"mid":"barrier"})
		]
		"laundry": return [
			room("被淹没的楼梯", "找到水槽下方的出口", [control("inlet","selector",7,[],{"modes":2,"initial":1}),control("drain","latch",15,["inlet:0"]),control("outlet","latch",33,["drain"])], [], ["outlet"], ["进水和排水不是同一个阀。","先切断水源，排水阀才能降低水位。","关闭进水，开启排水，再沿露出的槽底穿到出口。"], {"water":true}),
			room("空槽中的木筏", "借助水位登上高台", [control("float_plate","plate",18,[],{"mass":3.0}),control("fill","latch",12,["float_plate"]),control("high_valve","latch",28,["fill"],{"y":4.0})], [], ["high_valve"], ["水面能抬起浮箱。","干燥时才能把浮箱推到标记下方。","先把浮箱推到黄框，开灌水阀，再乘浮台到上层开阀。"], {"crate":16.0,"upper":true,"lift":"fill","water":true}),
			room("连通的两座水箱", "平衡两边水位，接通出口", [control("transfer","selector",8,[],{"modes":4}),control("left_valve","latch",24,["transfer:1"],{"y":4.0}),control("right_valve","latch",34,["left_valve","transfer:3"])], [], ["right_valve"], ["同一份水会在两座水箱之间移动。","第一档抬起左侧浮台，第三档给右侧出口提供压力。","转到第一档乘台开上层阀，下梯回来后转到第三档，再开右阀。"], {"upper":true,"lift":"transfer:1","water":true,"mid":"left_valve"}),
			room("失落的阀轮", "把阀轮带回干燥的机房", [control("basket","selector",8,[],{"modes":2}),control("valve_socket","socket",34,[],{"accept":"wheel"}),control("return","latch",38,["valve_socket"])], [item("wheel","wheel",27,3.28)], ["return"], ["断开的阀门轴需要一个轮子。","轮子在上层；双向货篮能让你携物返回。","启动货篮上楼，拾取阀轮后乘篮下楼，安装轮子并转动出口阀。"], {"upper":true,"lift":"basket:1"}),
			room("压力旁路", "释放密封闸门的压力", [control("bypass","socket",10,[],{"accept":"wheel"}),control("pressure","selector",16,["bypass"],{"modes":3}),control("vent","latch",27,["pressure:1"],{"y":4.0}),control("seal","latch",38,["vent","pressure:2"])], [item("wheel","wheel",5)], ["seal"], ["压力表指向不同的管道。","安装旁路轮，再去上层释放困住的空气。","装轮，切到第一档乘台开排气阀，回来选第二档开启密封门。"], {"upper":true,"lift":"pressure:1","water":true,"mid":"vent"}),
			room("蒸汽的呼吸", "让水轮与蒸汽错开节拍", [control("wheel_drive","socket",9,[],{"accept":"gear"}),control("timing","selector",17,["wheel_drive"],{"modes":3}),control("steam_lock","latch",36,["timing:2"])], [item("gear","gear",5)], ["steam_lock"], ["蒸汽喷口会在安静与喷发之间交替。","水轮的第二档会让三组喷口依次休息。","装齿轮、选第二档，在每块安全踏板等待下一组蒸汽关闭后前进。"], {"hazards":"steam","mid":"timing:2"})
		]
		"thread_vault": return [
			room("两个砝码", "让空中的货篮停在正确高度", [control("tray_a","socket",10,[],{"accept":"weight"}),control("tray_b","socket",14,[],{"accept":"weight"}),control("landing","latch",28,["tray_a","tray_b"],{"y":4.0})], [item("weight_a","weight",5),item("weight_b","weight",19)], ["landing"], ["一枚砝码不够抬起货篮。","两个托盘共同给绳轮施力。","将两枚砝码分别放入托盘，乘平衡篮到上层开闩。"], {"upper":true,"lift":"tray_a&tray_b"}),
			room("上下托盘", "用同一枚砝码完成两次停靠", [control("lower","socket",10,[],{"accept":"weight"}),control("stop","latch",28,["lower"],{"y":4.0}),control("upper","socket",34,["stop"],{"accept":"weight"})], [item("weight","weight",5)], ["upper"], ["一次停靠之后，棘爪会记住货篮的位置。","上层开闩后可以返回取回下层砝码。","装下盘、乘篮开闩、下梯取回砝码，再送到右侧托盘。"], {"upper":true,"lift":"lower","ladder_lock":"stop"}),
			room("插销与回路", "锁住桥面，再取回配重", [control("tray","socket",9,[],{"accept":"weight"}),control("pin","latch",27,["tray"],{"y":4.0}),control("reuse","socket",36,["pin"],{"accept":"weight"})], [item("weight","weight",5)], ["reuse"], ["插销能独立承受桥面的重量。","先在上层锁桥，配重就可以取走。","装配重、乘篮到上层插销，下梯取回配重，再把它送到下一托盘。"], {"upper":true,"lift":"tray","ladder_lock":"pin","mid":"pin"}),
			room("深井货运", "让砝码通过狭窄竖井", [control("hoist","selector",8,[],{"modes":2}),control("receiver","socket",28,[],{"accept":"weight","y":4.0}),control("shaft_gate","latch",38,["receiver"])], [item("weight","weight",5)], ["shaft_gate"], ["井口太高，梯子无法携带砝码。","把货篮当成移动的地面。","开启绞盘，带着砝码乘篮上楼，装进高处托盘，再下梯开门。"], {"upper":true,"lift":"hoist:1"}),
			room("铃声的另一侧", "让守卫离开货运通道", [control("bell","latch",9),control("hoist","selector",16,["bell"],{"modes":2}),control("quiet_gate","latch",28,["hoist:1"],{"y":4.0})], [], ["quiet_gate"], ["铃声会把守卫引向左边。","摇铃后货篮的路线比地面安全。","摇铃，打开绞盘，乘篮避开守卫，在上层落闩。"], {"upper":true,"lift":"hoist:1","chase":true,"mid":"bell"}),
			room("三段悬桥", "让三个绳结依次承重", [control("winch_a","socket",9,[],{"accept":"weight"}),control("pin_a","latch",18,["winch_a"]),control("winch_b","socket",22,["pin_a"],{"accept":"weight"}),control("pin_b","latch",31,["winch_b"]),control("far_latch","latch",39,["pin_a","pin_b"])], [item("weight","weight",5)], ["far_latch"], ["桥面可以插销固定，砝码可以重复使用。","先固定第一段，再取回砝码驱动第二个绞盘。","配重装左绞盘、固定第一闩、取回配重装右绞盘、固定第二闩，最后打开远端门。"], {"bridges":true,"mid":"pin_a"})
		]
		"clocktower": return [
			room("缺齿的传动", "让第一根主轴重新转动", [control("gear_socket","socket",10,[],{"accept":"gear"}),control("direction","selector",18,["gear_socket"],{"modes":3}),control("gear_door","latch",35,["direction:2"])], [item("gear","gear",5)], ["gear_door"], ["齿轮座上留着一圈空痕。","传动的方向与有没有动力同样重要。","装上齿轮，将旋钮拨到反向档，再打开主轴门。"]),
			room("离合器", "从摆锤线路借来升降动力", [control("clutch","selector",8,[],{"modes":3}),control("shortcut","latch",28,["clutch:1"],{"y":4.0}),control("pendulum_gate","latch",38,["shortcut","clutch:2"])], [], ["pendulum_gate"], ["离合器只能驱动一条线路。","先借升降台打开上层捷径。","第一档上楼开闩，下梯后换到第二档，穿过摆锤线路。"], {"upper":true,"lift":"clutch:1"}),
			room("摆锤之间", "为两组摆锤找到安全相位", [control("brake_a","brake",12),control("brake_b","brake",25,["brake_a"]),control("phase_gate","latch",38,["brake_b"])], [], ["phase_gate"], ["制动只会维持一小段时间。","两组摆锤之间有不会被扫到的停靠点。","先制动第一组并穿到中岛，再制动第二组，抓住停摆时间通过。"], {"hazards":"pendulum","mid":"brake_a"}),
			room("快轴与慢轴", "把两枚齿轮带到对应的轴上", [control("lift_power","socket",9,[],{"accept":"gear"}),control("slow_axis","socket",34,[],{"accept":"gear"}),control("fast_axis","latch",38,["lift_power","slow_axis"])], [item("gear_a","gear",5),item("gear_b","gear",27,3.28)], ["fast_axis"], ["慢轴的齿轮在上层工作台。","第一枚齿轮也能给货篮供能。","装第一枚齿轮，乘篮取回楼上齿轮，装入慢轴，然后联动两轴。"], {"upper":true,"lift":"lift_power"}),
			room("钟面上的记号", "让钟锤与刻度重新对齐", [control("counterweight","socket",10,[],{"accept":"weight"}),control("phase","selector",18,["counterweight"],{"modes":4}),control("clock_brake","brake",27,["phase:3"]),control("hammer","latch",38,["clock_brake","phase:3"])], [item("weight","weight",5)], ["hammer"], ["刻度 III 对着钟锤的释放臂。","配重、相位和制动必须同时成立。","安装配重，拨到第三档，在刻度对齐时制动，并在制动结束前拉下钟锤闩。"], {"mid":"phase:3"}),
			room("晨光之前", "敲响最后一口钟，奔向晨光", [control("release","latch",9),control("brake_a","brake",19,["release"]),control("brake_b","brake",29,["release"]),control("sunrise","latch",39,["release","brake_b"])], [], ["sunrise"], ["钟响后，整座塔都会重新运转。","安全岛可以躲开摆锤；途中仍有制动杆。","释放钟锤，利用两个制动杆穿过运转的机械，抵达最右侧晨光出口。"], {"hazards":"pendulum","mid":"release"})
		]
	return []
