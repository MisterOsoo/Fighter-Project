@tool
extends EditorPlugin


#region Plugin Initialization

func _enter_tree() -> void:
	print("Active Frame Hitbox plugin enabled!")


func _exit_tree() -> void:
	print("Active Frame Hitbox plugin disabled!")

#endregion
