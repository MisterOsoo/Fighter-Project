
extends AudioStreamPlayer2D
class_name RandomPitchHitSound


#region Pitch Settings

@export_group("Pitch Settings")

@export var pitch_variations: Array[float] = [
	0.85,
	0.95,
	1.05,
	1.15
]

#endregion


#region Audio Settings

@export_group("Audio Settings")

@export var max_simultaneous_sounds: int = 16

#endregion


#region Internal Variables

var audio_container: Node2D
var active_sounds: Array[AudioStreamPlayer2D] = []

#endregion


#region Initialization

func _ready() -> void:
	audio_container = Node2D.new()
	audio_container.name = "HitSoundInstances"

	get_tree().current_scene.add_child.call_deferred(audio_container)

#endregion


#region Sound Playback

func play_random_hit() -> void:
	if stream == null:
		return

	if not is_instance_valid(audio_container):
		return

	cleanup_finished_sounds()

	if active_sounds.size() >= max_simultaneous_sounds:
		return

	var sound_instance := AudioStreamPlayer2D.new()
	sound_instance.process_mode = Node.PROCESS_MODE_ALWAYS

	sound_instance.stream = stream
	sound_instance.pitch_scale = get_random_pitch()
	sound_instance.volume_db = volume_db
	sound_instance.bus = bus

	sound_instance.max_distance = max_distance
	sound_instance.attenuation = attenuation
	sound_instance.panning_strength = panning_strength

	audio_container.add_child(sound_instance)

	sound_instance.global_position = global_position

	active_sounds.append(sound_instance)

	sound_instance.finished.connect(
		_on_sound_finished.bind(sound_instance)
	)

	sound_instance.play()

#endregion


#region Pitch Selection

func get_random_pitch() -> float:
	if pitch_variations.is_empty():
		return 1.0

	return pitch_variations.pick_random()

#endregion


#region Sound Management

func _on_sound_finished(sound_instance: AudioStreamPlayer2D) -> void:
	active_sounds.erase(sound_instance)

	if is_instance_valid(sound_instance):
		sound_instance.queue_free()


func cleanup_finished_sounds() -> void:
	for sound_instance in active_sounds.duplicate():
		if not is_instance_valid(sound_instance):
			active_sounds.erase(sound_instance)

#endregion


#region Hit Confirm Signals

func _on_light_1_hit_confirmed(_attack_animation: StringName) -> void:
	play_random_hit()


func _on_light_2_hit_confirmed(_attack_animation: StringName) -> void:
	play_random_hit()


func _on_light_3_hit_confirmed(_attack_animation: StringName) -> void:
	play_random_hit()


func _on_air_light_hit_confirmed(_attack_animation: StringName) -> void:
	play_random_hit()

#endregion
