@tool
extends BaseNPC
class_name RangerMissionNPC


#region Mission Board Settings

@export_group("Mission Board")

@export var mission_board_scene: PackedScene

#endregion


#region Internal Variables

var active_mission_board: MissionBoard = null

#endregion


#region Initialization

func _ready() -> void:
	super._ready()

	if Engine.is_editor_hint():
		return

	if not npc_interacted.is_connected(
		_on_npc_interacted
	):
		npc_interacted.connect(
			_on_npc_interacted
		)

#endregion


#region Interaction

func _on_npc_interacted(_interactor: Node2D) -> void:
	if is_instance_valid(active_mission_board):
		return

	if mission_board_scene == null:
		push_warning(
			"RangerMissionNPC: No Mission Board scene assigned!"
		)
		return

	var board: MissionBoard = (
		mission_board_scene.instantiate() as MissionBoard
	)

	if board == null:
		push_error(
			"RangerMissionNPC: Mission Board scene must use MissionBoard.gd."
		)
		return

	active_mission_board = board

	# Add the board to the active overworld scene.
	get_tree().current_scene.add_child(board)

	if not board.board_closed.is_connected(
		_on_board_closed
	):
		board.board_closed.connect(
			_on_board_closed
		)

	board.open_board()

#endregion


#region Mission Board Cleanup

func _on_board_closed() -> void:
	if is_instance_valid(active_mission_board):
		active_mission_board.queue_free()

	active_mission_board = null

#endregion
