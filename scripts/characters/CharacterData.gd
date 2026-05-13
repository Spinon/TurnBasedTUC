class_name CharacterData
extends Resource

# Estrutura de dados de um personagem/inimigo — carregada de JSON

@export var character_id: String = ""
@export var display_name: String = ""
@export var is_enemy: bool = false

# Stats base
@export var max_hp: int = 100
@export var max_mp: int = 50
@export var max_echo: int = 30    # Recurso exclusivo de Aiko (age por Leo)
@export var atk: int = 10
@export var mag: int = 8
@export var def: int = 5
@export var res: int = 5
@export var spd: int = 10

# Estado atual
var current_hp: int
var current_mp: int
var current_echo: int
var active_buffs: Array[Dictionary] = []

# Habilidades disponíveis: lista de dicionários carregados do JSON
var skills: Array[Dictionary] = []
# Habilidades de Aiko (só existem em Leo; empty para outros personagens)
var aiko_skills: Array[Dictionary] = []


func _init() -> void:
	current_hp = max_hp
	current_mp = max_mp
	current_echo = max_echo


func load_from_dict(data: Dictionary) -> void:
	character_id = data.get("id", "")
	display_name = data.get("name", "")
	is_enemy = data.get("is_enemy", false)
	max_hp = data.get("max_hp", 100)
	max_mp = data.get("max_mp", 50)
	max_echo = data.get("max_echo", 0)
	atk = data.get("atk", 10)
	mag = data.get("mag", 8)
	def = data.get("def", 5)
	res = data.get("res", 5)
	spd = data.get("spd", 10)
	skills = data.get("skills", [])
	aiko_skills = data.get("aiko_skills", [])
	current_hp = max_hp
	current_mp = max_mp
	current_echo = max_echo


func to_dict() -> Dictionary:
	return {
		"id": character_id,
		"name": display_name,
		"is_enemy": is_enemy,
		"max_hp": max_hp,
		"max_mp": max_mp,
		"max_echo": max_echo,
		"atk": atk,
		"mag": mag,
		"def": def,
		"res": res,
		"spd": spd,
		"current_hp": current_hp,
		"current_mp": current_mp,
		"current_echo": current_echo,
		"skills": skills,
		"aiko_skills": aiko_skills,
	}


# Retorna ATK real considerando buffs ativos
func get_effective_atk() -> int:
	return _apply_buffs("atk", atk)


func get_effective_mag() -> int:
	return _apply_buffs("mag", mag)


func get_effective_def() -> int:
	return _apply_buffs("def", def)


func get_effective_res() -> int:
	return _apply_buffs("res", res)


func _apply_buffs(stat: String, base_value: int) -> int:
	var total := float(base_value)
	for buff in active_buffs:
		if buff.get("stat") == stat:
			total *= buff.get("multiplier", 1.0)
	return int(total)


func is_alive() -> bool:
	return current_hp > 0
