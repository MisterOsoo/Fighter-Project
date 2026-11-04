
@tool
extends Node2D
class_name ActiveFrameSpawner


#region Signals

signal object_spawned(instance: Node2D)

#endregion


#region Animation Settings

@export_group("Animation Settings")

@export var animated_sprite: AnimatedSprite2D:
	set(value):
		animated_sprite = value
		notify_property_list_changed()
		update_configuration_warnings()

@export_custom(PROPERTY_HINT_ENUM, "")
var spawn_animation: String = "attack":
	set(value):
		spawn_animation = value
		update_configuration_warnings()

@export var spawn_frames: Array[int] = [0]:
	set(value):
		spawn_frames = value
		update_configuration_warnings()

#endregion


#region Spawn Settings

@export_group("Spawn Settings")

@export var scene_to_spawn: PackedScene
@export var spawn_marker: Marker2D
@export var spawn_offset: Vector2 = Vector2.ZERO
@export var spawn_parent: Node2D

#endregion


#region Ownership Settings

@export_group("Ownership")

@export var shooter: Node2D

#endregion


#region Debug Settings

@export_group("Debug Settings")
@export var debug_enabled: bool = false

#endregion


#region Internal Variables

var spawned_frames: Array[int] = []
var last_animation: StringName = &""
var last_playing: bool = false

#endregion


#region Animation Dropdown

func _validate_property(property: Dictionary) -> void:
	if property.name != "spawn_animation":
		return

	if not is_instance_valid(animated_sprite):
		return

	if animated_sprite.sprite_frames == null:
		return

	var animations: PackedStringArray = (
		animated_sprite.sprite_frames.get_animation_names()
	)

	property.hint = PROPERTY_HINT_ENUM
	property.hint_string = ",".join(animations)

#endregion


#region Configuration Warnings

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []

	if not is_instance_valid(animated_sprite):
		warnings.append("Assign an AnimatedSprite2D.")
		return warnings

	if animated_sprite.sprite_frames == null:
		warnings.append("AnimatedSprite2D needs SpriteFrames.")
		return warnings

	if not animated_sprite.sprite_frames.has_animation(
		spawn_animation
	):
		warnings.append("Spawn animation does not exist.")
	else:
		var frame_count: int = (
			animated_sprite.sprite_frames.get_frame_count(
				spawn_animation
			)
		)

		for frame_number in spawn_frames:
			if frame_number < 0 or frame_number >= frame_count:
				warnings.append(
					"Spawn frame %d is out of range."
					% frame_number
				)

	if scene_to_spawn == null:
		warnings.append("Assign Scene To Spawn.")

	return warnings

#endregion


#region Initialization

func _ready() -> void:
	if Engine.is_editor_hint():
		return

	if not is_instance_valid(animated_sprite):
		push_warning("ActiveFrameSpawner needs AnimatedSprite2D.")
		return

	animated_sprite.frame_changed.connect(_on_frame_changed)
	animated_sprite.animation_changed.connect(_on_animation_changed)
	animated_sprite.animation_finished.connect(_on_animation_finished)
	animated_sprite.animation_looped.connect(_on_animation_looped)

	last_animation = animated_sprite.animation
	last_playing = animated_sprite.is_playing()

	_check_spawn_frame()

#endregion


#region Frame Tracking

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if not is_instance_valid(animated_sprite):
		return

	var current_animation: StringName = animated_sprite.animation
	var currently_playing: bool = animated_sprite.is_playing()

	if current_animation != last_animation:
		spawned_frames.clear()

	if currently_playing and not last_playing:
		spawned_frames.clear()

	if currently_playing:
		_check_spawn_frame()

	last_animation = current_animation
	last_playing = currently_playing


func _check_spawn_frame() -> void:
	if not is_instance_valid(animated_sprite):
		return

	if animated_sprite.animation != spawn_animation:
		return

	if not animated_sprite.is_playing():
		return

	var current_frame: int = animated_sprite.frame

	if current_frame not in spawn_frames:
		return

	if current_frame in spawned_frames:
		return

	spawned_frames.append(current_frame)
	spawn_object()

#endregion


#region Spawn Logic

func spawn_object() -> void:
	if scene_to_spawn == null:
		push_warning("No scene assigned to ActiveFrameSpawner.")
		return

	if not scene_to_spawn.can_instantiate():
		return

	var instance: Node = scene_to_spawn.instantiate()

	if not instance is Node2D:
		push_warning("Spawned scene must inherit Node2D.")
		instance.free()
		return

	var spawned_object: Node2D = instance as Node2D

	var target_parent: Node = get_tree().current_scene

	if is_instance_valid(spawn_parent):
		target_parent = spawn_parent

	if not is_instance_valid(target_parent):
		spawned_object.free()
		return

	var actual_shooter: Node2D = shooter

	if not is_instance_valid(actual_shooter):
		actual_shooter = get_parent() as Node2D

	var spawn_transform: Transform2D = global_transform

	if is_instance_valid(spawn_marker):
		spawn_transform = spawn_marker.global_transform

	var spawn_position: Vector2 = (
		spawn_transform.origin
		+ spawn_transform.basis_xform(spawn_offset)
	)

	# Set shooter before _ready() runs.
	if spawned_object is BaseBullet:
		var bullet: BaseBullet = spawned_object as BaseBullet
		bullet.set_shooter(actual_shooter)

	target_parent.add_child(spawned_object)
	spawned_object.global_position = spawn_position

	if debug_enabled:
		print(
			"[ActiveFrameSpawner] Spawned: ",
			spawned_object.name,
			" | Shooter: ",
			actual_shooter
		)

	object_spawned.emit(spawned_object)

#endregion


#region Animation Events

func _on_frame_changed() -> void:
	_check_spawn_frame()


func _on_animation_changed() -> void:
	spawned_frames.clear()
	_check_spawn_frame()


func _on_animation_finished() -> void:
	if not is_instance_valid(animated_sprite):
		return

	if animated_sprite.animation == spawn_animation:
		spawned_frames.clear()


func _on_animation_looped() -> void:
	if not is_instance_valid(animated_sprite):
		return

	if animated_sprite.animation == spawn_animation:
		spawned_frames.clear()
		_check_spawn_frame()

#endregion
