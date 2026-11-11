
@tool
extends CharacterBody2D
class_name BaseOWPlayer


#region Movement Settings

@export_group("Movement")

@export var move_speed: float = 200.0
@export var run_speed: float = 350.0

@export var acceleration: float = 1200.0
@export var deceleration: float = 1500.0

#endregion


#region Movement Inputs

@export_group("Movement Inputs")

@export var left_input: StringName = &"ui_left"
@export var right_input: StringName = &"ui_right"
@export var up_input: StringName = &"ui_up"
@export var down_input: StringName = &"ui_down"
@export var run_input: StringName = &"run"

#endregion


#region References

@export_group("References")

@export var visuals: Node2D

@export var anim: AnimatedSprite2D:
	set(value):
		anim = value
		notify_property_list_changed()

#endregion


#region Animation Settings

@export_group("Animation Settings")

@export_custom(PROPERTY_HINT_ENUM, "")
var idle_animation: String = "idle"

@export_custom(PROPERTY_HINT_ENUM, "")
var walk_animation: String = "walk"

@export_custom(PROPERTY_HINT_ENUM, "")
var run_animation: String = "run"

#endregion


#region Internal Variables

var movement_direction: Vector2 = Vector2.ZERO
var facing_direction: int = 1
var is_running: bool = false

#endregion


#region Inspector Animation Dropdowns

func _validate_property(property: Dictionary) -> void:
	if property.name in [
		"idle_animation",
		"walk_animation",
		"run_animation"
	]:
		if anim and anim.sprite_frames:
			var animations: PackedStringArray = (
				anim.sprite_frames.get_animation_names()
			)

			property.hint = PROPERTY_HINT_ENUM
			property.hint_string = ",".join(animations)

#endregion


#region Initialization

func _ready() -> void:
	if Engine.is_editor_hint():
		return

	if visuals == null:
		visuals = get_node_or_null("visuals") as Node2D

	if anim == null and visuals:
		anim = visuals.get_node_or_null(
			"AnimatedSprite2D"
		) as AnimatedSprite2D

	if visuals:
		facing_direction = (
			-1 if visuals.scale.x < 0.0 else 1
		)

	play_animation(StringName(idle_animation))

#endregion


#region Physics

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	handle_movement(delta)
	update_facing()
	update_animation()

	move_and_slide()

#endregion


#region Movement

func handle_movement(delta: float) -> void:
	movement_direction = Vector2(
		Input.get_axis(left_input, right_input),
		Input.get_axis(up_input, down_input)
	).normalized()

	is_running = (
		movement_direction != Vector2.ZERO
		and Input.is_action_pressed(run_input)
	)

	var target_speed: float = move_speed

	if is_running:
		target_speed = run_speed

	if movement_direction != Vector2.ZERO:
		velocity = velocity.move_toward(
			movement_direction * target_speed,
			acceleration * delta
		)
	else:
		velocity = velocity.move_toward(
			Vector2.ZERO,
			deceleration * delta
		)


func stop_movement() -> void:
	movement_direction = Vector2.ZERO
	velocity = Vector2.ZERO
	is_running = false

	update_animation()

#endregion


#region Facing

func update_facing() -> void:
	if visuals == null:
		return

	if movement_direction.x > 0.0:
		facing_direction = 1

	elif movement_direction.x < 0.0:
		facing_direction = -1

	else:
		return

	# Flip the entire visuals node.
	visuals.scale.x = (
		absf(visuals.scale.x) * facing_direction
	)

#endregion


#region Animation Controller

func update_animation() -> void:
	if movement_direction == Vector2.ZERO:
		play_animation(StringName(idle_animation))
		return

	if is_running:
		play_animation(StringName(run_animation))
	else:
		play_animation(StringName(walk_animation))


func play_animation(
	animation_name: StringName
) -> void:
	if anim == null or anim.sprite_frames == null:
		return

	if not anim.sprite_frames.has_animation(
		animation_name
	):
		return

	if (
		anim.animation != animation_name
		or not anim.is_playing()
	):
		anim.play(animation_name)

#endregion
