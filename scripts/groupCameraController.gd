
extends Node
class_name GroupCameraController


#region Camera Settings

@export_group("Camera Settings")

@export var phantom_camera: PhantomCamera2D

#endregion


#region Group Settings

@export_group("Follow Groups")

@export var player_group: StringName = &"player"
@export var enemy_group: StringName = &"enemy"

#endregion


#region Internal Variables

var current_player: Node2D
var current_enemy: Node2D

var update_queued: bool = false

#endregion


#region Initialization

func _ready() -> void:
	if phantom_camera == null:
		phantom_camera = get_parent() as PhantomCamera2D

	if phantom_camera == null:
		push_warning(
			"GroupCameraController: PhantomCamera2D not assigned."
		)
		return

	# Find the initial player and enemy.
	update_camera_targets()

	# Detect creatures entering or leaving the scene.
	if not get_tree().node_added.is_connected(
		_on_node_added
	):
		get_tree().node_added.connect(
			_on_node_added
		)

	if not get_tree().node_removed.is_connected(
		_on_node_removed
	):
		get_tree().node_removed.connect(
			_on_node_removed
		)

#endregion


#region Camera Targets

func update_camera_targets() -> void:
	update_queued = false

	if not is_instance_valid(phantom_camera):
		return

	var player_node: Node = get_tree().get_first_node_in_group(
		player_group
	)

	var enemy_node: Node = get_tree().get_first_node_in_group(
		enemy_group
	)

	current_player = player_node as Node2D
	current_enemy = enemy_node as Node2D

	var targets: Array[Node2D] = []

	if is_instance_valid(current_player):
		targets.append(current_player)

	if is_instance_valid(current_enemy):
		if current_enemy != current_player:
			targets.append(current_enemy)

	phantom_camera.follow_targets = targets

#endregion


#region Target Refresh

func queue_target_refresh() -> void:
	if update_queued:
		return

	update_queued = true

	call_deferred("update_camera_targets")


func _on_node_added(_node: Node) -> void:
	queue_target_refresh()


func _on_node_removed(node: Node) -> void:
	# Only refresh when one of our followed characters
	# or their ancestors leaves the scene.
	if is_instance_valid(current_player):
		if node == current_player or node.is_ancestor_of(
			current_player
		):
			queue_target_refresh()
			return

	if is_instance_valid(current_enemy):
		if node == current_enemy or node.is_ancestor_of(
			current_enemy
		):
			queue_target_refresh()
			return

	# Also refresh for other removed group members.
	if node.is_in_group(player_group):
		queue_target_refresh()
		return

	if node.is_in_group(enemy_group):
		queue_target_refresh()

#endregion


#region Cleanup

func _exit_tree() -> void:
	if get_tree().node_added.is_connected(
		_on_node_added
	):
		get_tree().node_added.disconnect(
			_on_node_added
		)

	if get_tree().node_removed.is_connected(
		_on_node_removed
	):
		get_tree().node_removed.disconnect(
			_on_node_removed
		)

#endregion
