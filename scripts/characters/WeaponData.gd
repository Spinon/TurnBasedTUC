class_name WeaponData
extends Resource

@export var weapon_id: String = ""
@export var display_name: String = ""
@export var weapon_type: String = ""   # shield, blade, dual_blade, bow, lance, custom
@export var base_atk: int = 20
@export var music_theme: String = ""   # identificador do tema musical da arma
@export var unlock_sector: int = 1
@export var description: String = ""

# skills[0] = ataque básico (sem ritmo)
# skills[1..3] = habilidades rítmicas (2/3/4 beats respectivamente)
var skills: Array[Dictionary] = []


func load_from_dict(data: Dictionary) -> void:
	weapon_id = data.get("id", "")
	display_name = data.get("name", "")
	weapon_type = data.get("type", "")
	base_atk = data.get("base_atk", 20)
	music_theme = data.get("music_theme", "")
	unlock_sector = data.get("unlock_sector", 1)
	description = data.get("description", "")
	skills = data.get("skills", [])


func get_basic_attack() -> Dictionary:
	if skills.is_empty():
		return {"id": "ataque", "name": "Atacar", "type": "physical",
				"power": 1.0, "rhythm_beats": 0, "mp_cost": 0}
	return skills[0]


func get_skill(index: int) -> Dictionary:
	# index 1-3 → habilidades rítmicas
	var actual := index  # skills[1], skills[2], skills[3]
	if actual < skills.size():
		return skills[actual]
	return {}


static func load_from_file(weapon_id: String) -> WeaponData:
	var path := "res://data/weapons/%s.json" % weapon_id
	if not FileAccess.file_exists(path):
		push_error("WeaponData: arquivo não encontrado: %s" % path)
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	var raw: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not raw is Dictionary:
		return null
	var weapon := WeaponData.new()
	weapon.load_from_dict(raw)
	return weapon
