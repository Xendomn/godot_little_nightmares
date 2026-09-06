extends Node

var ambient: AudioStreamPlayer
var chase: AudioStreamPlayer
var effects: Dictionary = {}
var chase_mix: float = 0
var desired_mix: float = 0
@export var ambience_name: String = "ambient"

func _ready() -> void:
	ambient = make_player(ambience_name, true)
	chase = make_player("chase", true)
	ambient.volume_db = -13
	chase.volume_db = -60
	ambient.play()
	chase.play()
	for sound in ["step", "push", "pickup", "switch", "caught", "win"]:
		effects[sound] = make_player(sound, false)

func make_player(sound: String, looping: bool) -> AudioStreamPlayer:
	var result := AudioStreamPlayer.new()
	var path := "res://assets/audio/" + sound + ".wav"
	if ResourceLoader.exists(path):
		var stream = load(path).duplicate()
		if looping and stream is AudioStreamWAV:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_end = int(stream.get_length() * stream.mix_rate)
		result.stream = stream
	add_child(result)
	return result

func _process(delta: float) -> void:
	chase_mix = move_toward(chase_mix, desired_mix, delta * 0.6)
	chase.volume_db = linear_to_db(maxf(0.001, chase_mix * 0.45))
	ambient.volume_db = lerpf(-13, -21, chase_mix)

func play_effect(sound: String, quiet: bool = false) -> void:
	if not effects.has(sound):
		return
	var effect: AudioStreamPlayer = effects[sound]
	effect.volume_db = -19 if quiet else -8
	effect.pitch_scale = randf_range(0.9, 1.1) if sound == "step" else 1.0
	if not effect.playing or sound != "push":
		effect.play()
