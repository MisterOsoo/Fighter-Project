
extends Node2D
class_name DummySpawner


#region Spawn Settings

@export_group("Spawn Settings")

@export var dummy_scene: PackedScene
@export var initial_dummy: Node2D
@export var respawn_delay: float = 3.0
@export var spawn_on_ready: bool = true

#endregion


#region Player Settings

@export_group("Player Settings")

@export var player: BasePlayer
@export var spawn_distance: float = 150.0
@export var spawn_in_facing_direction: bool = true
@export var keep_player_height: bool = true

#endregion


#region Camera Settings

@export_group("Camera Settings")

@export var phantom_camera: PhantomCamera2D

#endregion


#region Internal Variables

var current_dummy: Node2D
var respawn_timer: Timer
var is_spawning: bool = false

var previous_dummy: Node2D

#endregion


#region Initialization

func _ready() -> void:
	respawn_timer = Timer.new()
	respawn_timer.name = "RespawnTimer"
	respawn_timer.one_shot = true

	add_child(respawn_timer)

	respawn_timer.timeout.connect(
		_on_respawn_timer_timeout
	)

	if is_instance_valid(initial_dummy):
		register_dummy(initial_dummy)

	elif spawn_on_ready:
		spawn_dummy.call_deferred()

#endregion


#region Dummy Registration

func register_dummy(dummy: Node2D) -> void:
	if not is_instance_valid(dummy):
		return

	current_dummy = dummy

	if not current_dummy.tree_exited.is_connected(
		_on_dummy_destroyed
	):
		current_dummy.tree_exited.connect(
			_on_dummy_destroyed
		)

#endregion


#region Dummy Spawning

func spawn_dummy() -> void:
	if is_spawning:
		return

	if is_instance_valid(current_dummy):
		return

	if dummy_scene == null:
		push_warning(
			"DummySpawner: No dummy scene assigned."
		)
		return

	if not is_instance_valid(player):
		push_warning(
			"DummySpawner: No player assigned."
		)
		return

	if not is_instance_valid(phantom_camera):
		push_warning(
			"DummySpawner: No PhantomCamera assigned."
		)
		return

	var scene_root: Node = get_tree().current_scene

	if scene_root == null:
		return

	is_spawning = true

	var dummy_instance: Node = dummy_scene.instantiate()

	if not dummy_instance is Node2D:
		push_error(
			"DummySpawner: Dummy root must be Node2D."
		)
		dummy_instance.free()
		is_spawning = false
		return

	var new_dummy: Node2D = dummy_instance as Node2D

	var spawn_position: Vector2 = player.global_position
	var direction: int = 1

	if spawn_in_facing_direction:
		direction = player.facing_direction

	spawn_position.x += spawn_distance * direction

	if not keep_player_height:
		spawn_position.y = global_position.y

	scene_root.add_child(new_dummy)
	new_dummy.global_position = spawn_position

	# Update the camera's group targets.
	update_camera_target(new_dummy)

	register_dummy(new_dummy)

	is_spawning = false

#endregion


#region Camera Target Management

func update_camera_target(new_dummy: Node2D) -> void:
	if not is_instance_valid(phantom_camera):
		return

	var targets: Array[Node2D] = []

	# Preserve all valid targets except the old dummy.
	for target in phantom_camera.follow_targets:
		if not is_instance_valid(target):
			continue

		if target == previous_dummy:
			continue

		if target == initial_dummy:
			continue

		targets.append(target)

	# Add the newly spawned dummy.
	targets.append(new_dummy)

	phantom_camera.follow_targets = targets

	previous_dummy = new_dummy

#endregion


#region Dummy Destruction

func _on_dummy_destroyed() -> void:
	previous_dummy = current_dummy
	current_dummy = null

	if not is_inside_tree():
		return

	if respawn_timer:
		respawn_timer.start(
			maxf(respawn_delay, 0.001)
		)

#endregion


#region Respawning

func _on_respawn_timer_timeout() -> void:
	spawn_dummy()

#endregion
