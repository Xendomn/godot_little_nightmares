extends Node3D
## Presentation only: gameplay flags and collision remain owned by the chapter.
@export var kind := "drain"
var active := false
var amount := 0.0
var feedback_age := 10.0
var indicator := 0.0
var pivots: Dictionary = {}
var rest: Dictionary = {}
var audio: AudioStreamPlayer3D

func _ready() -> void:
	cache_pivots()
	audio = AudioStreamPlayer3D.new()
	audio.max_distance = 18
	audio.unit_size = 3
	audio.volume_db = -12
	var sound := "bell" if kind in ["bell", "last_bell"] else ("valve" if kind in ["drain", "fill", "steam_pipe"] else "ratchet")
	var path := "res://assets/audio/prop_" + sound + ".wav"
	if ResourceLoader.exists(path): audio.stream = load(path)
	add_child(audio)
	apply_pose()

func cache_pivots() -> void:
	for name in ["Rotor", "Lever", "Door", "Bell", "Hammer", "Needle", "Deck", "Fuse"]:
		var part := find_child(name, true, false) as Node3D
		if part and not pivots.has(name):
			pivots[name] = part
			rest[name] = part.transform

func set_active(value: bool, immediate: bool = false) -> void:
	active = value
	if immediate:
		amount = 1.0 if active else 0.0
		feedback_age = 10.0
		if audio: audio.stop()
		apply_pose()

func play_feedback() -> void:
	feedback_age = 0
	if audio and audio.stream: audio.play()

func set_indicator(value: float) -> void:
	indicator = clampf(value, 0, 1)

func _process(delta: float) -> void:
	amount = move_toward(amount, 1.0 if active else 0.0, delta * 1.5)
	feedback_age += delta
	apply_pose()

func apply_pose() -> void:
	for name in pivots:
		pivots[name].transform = rest[name]
	var envelope := maxf(0, 1.0 - feedback_age / 2.4)
	var swing := sin(feedback_age * 12) * envelope
	if pivots.has("Rotor"):
		pivots.Rotor.rotate_object_local(Vector3.FORWARD, -amount * TAU * 1.5 - swing * .08)
	if pivots.has("Lever"):
		pivots.Lever.rotate_object_local(Vector3.FORWARD, -(amount * .8 + swing * .12))
	if pivots.has("Bell"):
		pivots.Bell.rotate_object_local(Vector3.FORWARD, swing * .5)
	if pivots.has("Hammer"):
		pivots.Hammer.rotate_object_local(Vector3.FORWARD, -(amount * .35 + swing * .4))
	if pivots.has("Needle"):
		pivots.Needle.rotate_object_local(Vector3.FORWARD, -(indicator if kind == "steam_pipe" else amount) * 2.1)
	if pivots.has("Deck"):
		pivots.Deck.position.y -= amount * .065
	if pivots.has("Door"):
		pivots.Door.rotate_object_local(Vector3.UP, -amount * .85)
	if pivots.has("Fuse"):
		pivots.Fuse.visible = active
