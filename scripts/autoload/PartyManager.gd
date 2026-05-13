extends Node

# Gerencia a composição da party conforme a progressão narrativa do TUC
# Fase 1: só Leo  | Fase 2: Leo+Aiko (Aiko é parte de Leo, não membro separado)
# Fase 3: +Julia  | Fase 4: +Elara  | Fase 5: Elara morre, volta a 3 membros

const MAX_PARTY_SIZE := 3  # Leo, Julia, Elara (Aiko é integrada a Leo)

var party: Array[CharacterData] = []

signal party_changed(new_party: Array)


func _ready() -> void:
	_load_initial_party()


func _load_initial_party() -> void:
	var leo_data := _load_character("leo")
	if leo_data:
		party.append(leo_data)


func add_member(character_id: String) -> void:
	if party.size() >= MAX_PARTY_SIZE:
		return
	if _is_in_party(character_id):
		return
	var data := _load_character(character_id)
	if data:
		party.append(data)
		party_changed.emit(party)


func remove_member(character_id: String) -> void:
	party = party.filter(func(m): return m.character_id != character_id)
	party_changed.emit(party)


func get_member(character_id: String) -> CharacterData:
	for member in party:
		if member.character_id == character_id:
			return member
	return null


func get_alive_members() -> Array[CharacterData]:
	return party.filter(func(m): return m.current_hp > 0)


func is_party_wiped() -> bool:
	return get_alive_members().is_empty()


func _is_in_party(character_id: String) -> bool:
	return party.any(func(m): return m.character_id == character_id)


func _load_character(character_id: String) -> CharacterData:
	var path := "res://data/characters/%s.json" % character_id
	if not FileAccess.file_exists(path):
		push_error("CharacterData not found: %s" % path)
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	var raw: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not raw is Dictionary:
		return null
	var data := CharacterData.new()
	data.load_from_dict(raw)
	return data


func get_save_data() -> Dictionary:
	var out := {}
	for member in party:
		out[member.character_id] = member.to_dict()
	return out


func load_save_data(data: Dictionary) -> void:
	party.clear()
	for id in data.keys():
		var cd := CharacterData.new()
		cd.load_from_dict(data[id])
		party.append(cd)
	party_changed.emit(party)
