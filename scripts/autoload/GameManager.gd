extends Node

# Estado global do jogo — persiste entre cenas
enum GameState { EXPLORING, BATTLE, CUTSCENE, MENU, GAME_OVER }

var current_state: GameState = GameState.EXPLORING
var current_sector: int = 1
var play_time: float = 0.0
var flags: Dictionary = {}  # flags de narrativa: {"julia_found": true, "elara_joined": false, ...}

signal state_changed(new_state: GameState)
signal sector_changed(new_sector: int)


func _process(delta: float) -> void:
	if current_state == GameState.EXPLORING:
		play_time += delta


func set_state(new_state: GameState) -> void:
	current_state = new_state
	state_changed.emit(new_state)


func set_sector(sector: int) -> void:
	current_sector = sector
	sector_changed.emit(sector)


func set_flag(flag_name: String, value: bool) -> void:
	flags[flag_name] = value


func get_flag(flag_name: String) -> bool:
	return flags.get(flag_name, false)


func save_game() -> void:
	var save_data := {
		"sector": current_sector,
		"play_time": play_time,
		"flags": flags,
		"party": PartyManager.get_save_data(),
	}
	var file := FileAccess.open("user://save.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()


func load_game() -> bool:
	if not FileAccess.file_exists("user://save.json"):
		return false
	var file := FileAccess.open("user://save.json", FileAccess.READ)
	var data: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not data is Dictionary:
		return false
	current_sector = data.get("sector", 1)
	play_time = data.get("play_time", 0.0)
	flags = data.get("flags", {})
	PartyManager.load_save_data(data.get("party", {}))
	return true
