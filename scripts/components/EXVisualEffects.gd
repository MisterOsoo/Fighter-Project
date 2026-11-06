
extends Node
class_name EXVisualEffects


#region References

@export_group("References")

@export var character: CharacterBody2D
@export var animated_sprite: AnimatedSprite2D
@export var visuals: Node2D

#endregion


#region Delayed Shadow Settings

@export_group("Delayed Animation Shadows")

@export_range(0.0, 0.5, 0.01)
var shadow_1_delay: float = 0.10

@export_range(0.0, 0.5, 0.01)
var shadow_2_delay: float = 0.25

@export var debug_shadow: bool = false

#endregion


#region State

var effects_active: bool = false
var active_special: SpecialAttackData

var flash_timer: float = 0.0
var flash_visible: bool = false

var original_modulate: Color = Color.WHITE

#endregion


#region Shadow State

var shadow_1: Sprite2D
var shadow_2: Sprite2D

var shadow_history: Array[Dictionary] = []
var elapsed_time: float = 0.0

#endregion


#region Initialization

func _ready() -> void:
	if character == null:
		character = get_parent() as CharacterBody2D

	if character is BasePlayer:
		var player: BasePlayer = character as BasePlayer

		if animated_sprite == null:
			animated_sprite = player.anim

		if visuals == null:
			visuals = player.visuals

	if is_instance_valid(animated_sprite):
		original_modulate = animated_sprite.modulate

	create_shadows()


func _exit_tree() -> void:
	if is_instance_valid(shadow_1):
		shadow_1.queue_free()

	if is_instance_valid(shadow_2):
		shadow_2.queue_free()

#endregion


#region Shadow Setup

func create_shadows() -> void:
	if not is_instance_valid(animated_sprite):
		push_warning(
			"EXVisualEffects: AnimatedSprite2D missing."
		)
		return

	if not is_instance_valid(visuals):
		push_warning(
			"EXVisualEffects: Visuals node missing."
		)
		return

	shadow_1 = create_shadow_sprite("EXShadow1")
	shadow_2 = create_shadow_sprite("EXShadow2")


func create_shadow_sprite(
	shadow_name: String
) -> Sprite2D:
	var shadow: Sprite2D = Sprite2D.new()

	shadow.name = shadow_name
	shadow.centered = animated_sprite.centered
	shadow.offset = animated_sprite.offset
	shadow.texture_filter = animated_sprite.texture_filter

	visuals.add_child(shadow)

	# Place each shadow behind the original sprite.
	visuals.move_child(
		shadow,
		animated_sprite.get_index()
	)

	shadow.z_index = animated_sprite.z_index
	shadow.z_as_relative = animated_sprite.z_as_relative

	shadow.hide()

	return shadow

#endregion


#region Effect Control

func start_effects(special: SpecialAttackData) -> void:
	if special == null:
		return

	stop_effects()

	active_special = special
	effects_active = true

	flash_timer = 0.0
	flash_visible = false
	elapsed_time = 0.0

	shadow_history.clear()

	if is_instance_valid(animated_sprite):
		original_modulate = animated_sprite.modulate

	if active_special.ex_yellow_flash:
		apply_flash(true)

	hide_shadows()


func stop_effects() -> void:
	effects_active = false
	active_special = null

	flash_timer = 0.0
	flash_visible = false
	elapsed_time = 0.0

	shadow_history.clear()

	if is_instance_valid(animated_sprite):
		animated_sprite.modulate = original_modulate

	hide_shadows()


func hide_shadows() -> void:
	if is_instance_valid(shadow_1):
		shadow_1.hide()

	if is_instance_valid(shadow_2):
		shadow_2.hide()

#endregion


#region Processing

func _process(delta: float) -> void:
	if not effects_active:
		return

	if active_special == null:
		stop_effects()
		return

	if not is_instance_valid(animated_sprite):
		stop_effects()
		return

	elapsed_time += delta

	if active_special.ex_yellow_flash:
		update_flash(delta)

	if active_special.ex_afterimage_enabled or debug_shadow:
		record_animation_frame()

		update_shadow(
			shadow_1,
			shadow_1_delay,
			1
		)

		update_shadow(
			shadow_2,
			shadow_2_delay,
			2
		)

		cleanup_history()
	else:
		hide_shadows()

#endregion


#region Yellow Flash

func update_flash(delta: float) -> void:
	flash_timer -= delta

	if flash_timer > 0.0:
		return

	flash_timer = maxf(
		active_special.ex_flash_interval,
		0.01
	)

	flash_visible = not flash_visible

	apply_flash(flash_visible)


func apply_flash(enabled: bool) -> void:
	if not is_instance_valid(animated_sprite):
		return

	if enabled:
		animated_sprite.modulate = (
			original_modulate * active_special.ex_flash_color
		)
	else:
		animated_sprite.modulate = original_modulate

#endregion


#region Animation Recording

func record_animation_frame() -> void:
	if animated_sprite.sprite_frames == null:
		return

	var frames: SpriteFrames = animated_sprite.sprite_frames

	if not frames.has_animation(animated_sprite.animation):
		return

	var current_frame: int = animated_sprite.frame

	if current_frame < 0:
		return

	if current_frame >= frames.get_frame_count(
		animated_sprite.animation
	):
		return

	var frame_texture: Texture2D = frames.get_frame_texture(
		animated_sprite.animation,
		current_frame
	)

	if frame_texture == null:
		return

	# Record the displayed animation frame and
	# its exact position in world space.
	shadow_history.append({
		"time": elapsed_time,
		"texture": frame_texture,
		"transform": animated_sprite.global_transform,
		"flip_h": animated_sprite.flip_h,
		"flip_v": animated_sprite.flip_v
	})

#endregion


#region Delayed Shadows

func update_shadow(
	shadow: Sprite2D,
	delay: float,
	shadow_number: int
) -> void:
	if not is_instance_valid(shadow):
		return

	if shadow_history.is_empty():
		shadow.hide()
		return

	var target_time: float = elapsed_time - delay

	if debug_shadow:
		target_time = elapsed_time

	var selected_frame: Dictionary = {}

	for entry in shadow_history:
		if entry["time"] <= target_time:
			selected_frame = entry
		else:
			break

	if selected_frame.is_empty():
		shadow.hide()
		return

	# Display the exact recorded animation texture.
	shadow.texture = selected_frame["texture"]

	# Convert the historical world transform
	# into the current Visuals local space.
	var historical_transform: Transform2D = (
		selected_frame["transform"]
	)

	shadow.transform = (
		visuals.global_transform.affine_inverse()
		* historical_transform
	)

	shadow.flip_h = selected_frame["flip_h"]
	shadow.flip_v = selected_frame["flip_v"]

	# Apply the same configurable offset to both.
	# The second shadow gets twice the offset.
	shadow.position.x -= (
		active_special.ex_afterimage_offset
		* float(shadow_number)
	)

	var shadow_color: Color = (
		active_special.ex_afterimage_color
	)

	shadow_color.a *= active_special.ex_afterimage_opacity

	# Make the older shadow slightly more transparent.
	if shadow_number == 2:
		shadow_color.a *= 0.65

	if debug_shadow:
		shadow_color = Color(1.0, 0.0, 1.0, 1.0)

	shadow.modulate = shadow_color
	shadow.show()

#endregion


#region History Cleanup

func cleanup_history() -> void:
	if shadow_history.size() <= 1:
		return

	var longest_delay: float = maxf(
		shadow_1_delay,
		shadow_2_delay
	)

	if debug_shadow:
		longest_delay = 0.0

	var oldest_needed_time: float = (
		elapsed_time - longest_delay
	)

	while shadow_history.size() > 1:
		if shadow_history[1]["time"] > oldest_needed_time:
			break

		shadow_history.remove_at(0)

#endregion
