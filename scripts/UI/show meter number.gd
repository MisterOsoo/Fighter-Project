extends RichTextLabel


#region References

@export_group("References")
@export var meter_bar: TextureProgressBar

#endregion


#region Initialization

func _ready() -> void:
	if meter_bar == null:
		push_warning("MeterNumber: No TextureProgressBar assigned.")
		return

	if not meter_bar.value_changed.is_connected(
		_on_value_changed
	):
		meter_bar.value_changed.connect(
			_on_value_changed
		)

	update_display()

#endregion


#region Meter Display

func update_display() -> void:
	if meter_bar == null:
		return

	text = str(roundi(meter_bar.value))


func _on_value_changed(_new_value: float) -> void:
	update_display()

#endregion
