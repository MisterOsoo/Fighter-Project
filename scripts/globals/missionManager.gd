
extends Node


#region Mission Types

enum Biome {
	RANGER_TEST,
	FOREST,
	SEA,
	VOLCANO,
	DESERT,
	SWAMP,
	FINAL_MISSION
}

#endregion


#region Mission Progress

var selected_biome: Biome = Biome.RANGER_TEST

var ranger_test_completed: bool = false
var completed_biomes: Array[Biome] = []
var unlocked_biomes: Array[Biome] = []

var final_mission_completed: bool = false

#endregion


#region Mission Selection

func select_biome(biome: Biome) -> void:
	selected_biome = biome


func get_selected_biome_name() -> String:
	return get_biome_name(selected_biome)


func get_biome_name(biome: Biome) -> String:
	match biome:
		Biome.RANGER_TEST:
			return "Ranger Test"
		Biome.FOREST:
			return "Forest"
		Biome.SEA:
			return "Sea"
		Biome.VOLCANO:
			return "Volcano"
		Biome.DESERT:
			return "Desert"
		Biome.SWAMP:
			return "Swamp"
		Biome.FINAL_MISSION:
			return "Final Mission"

	return "Unknown"


func is_biome_unlocked(biome: Biome) -> bool:
	if biome == Biome.RANGER_TEST:
		return not ranger_test_completed

	if biome == Biome.FINAL_MISSION:
		return are_all_biomes_completed()

	return biome in unlocked_biomes


func are_all_biomes_completed() -> bool:
	for biome in [
		Biome.FOREST,
		Biome.SEA,
		Biome.VOLCANO,
		Biome.DESERT,
		Biome.SWAMP
	]:
		if biome not in completed_biomes:
			return false

	return true

#endregion
