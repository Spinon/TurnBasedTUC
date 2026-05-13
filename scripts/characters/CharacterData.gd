class_name CharacterData
extends Resource

@export var character_id: String = ""
@export var display_name: String = ""
@export var is_enemy: bool = false

# Stats base
@export var max_hp: int = 100
@export var max_mp: int = 50
@export var max_echo: int = 0
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

# Skills fixas (Julia, Elara, inimigos)
var skills: Array[Dictionary] = []
# Skills de Aiko — só preenchido em Leo
var aiko_skills: Array[Dictionary] = []

# ── Arma equipada (só Leo) ──────────────────────────────────────────────
var equipped_weapon: WeaponData = null

func equip_weapon(weapon: WeaponData) -> void:
	equipped_weapon = weapon

func get_weapon_skills() -> Array[Dictionary]:
	if equipped_weapon:
		return equipped_weapon.skills
	return skills

func get_basic_attack() -> Dictionary:
	if equipped_weapon:
		return equipped_weapon.get_basic_attack()
	return skills[0] if not skills.is_empty() else \
		{"id": "ataque", "name": "Atacar", "type": "physical", "power": 1.0, "rhythm_beats": 0, "mp_cost": 0}

# ── Modo Aiko (só Leo) ──────────────────────────────────────────────────
enum AikoMode { NONE, PROC, GUARANTEED, SYNC_BAR }
var aiko_mode: AikoMode = AikoMode.NONE

# Modo PROC
const AIKO_PROC_CHANCE := 0.40   # 40% de chance por turno

# Modo SYNC_BAR
const SYNC_BAR_PASSIVE_FILL := 0.20    # enchimento passivo por turno (5 turnos para 1 carga)
const SYNC_BAR_RHYTHM_BONUS := 0.15    # bônus por accuracy% (100% ritmo = +15%)
const MAX_SYNC_POINTS := 3             # máximo de cargas acumuladas

var sync_bar: float = 0.0       # 0.0 → 1.0
var sync_points: int = 0        # cargas acumuladas prontas para usar

signal aiko_proced()
signal sync_point_gained(total: int)
signal sync_bar_updated(value: float)


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

	# Carrega arma inicial se especificada
	var weapon_id: String = data.get("starting_weapon", "")
	if weapon_id:
		var weapon := WeaponData.load_from_file(weapon_id)
		if weapon:
			equip_weapon(weapon)

	current_hp = data.get("current_hp", max_hp)
	current_mp = data.get("current_mp", max_mp)
	current_echo = data.get("current_echo", max_echo)
	sync_bar = data.get("sync_bar", 0.0)
	sync_points = data.get("sync_points", 0)


# ── Aiko: proc por turno ────────────────────────────────────────────────

func roll_aiko_proc() -> bool:
	if aiko_mode != AikoMode.PROC:
		return false
	var result := randf() < AIKO_PROC_CHANCE
	if result:
		aiko_proced.emit()
	return result


# ── Aiko: barra de sincronia ────────────────────────────────────────────

func tick_sync_bar(rhythm_accuracy: float = 0.0) -> void:
	if aiko_mode != AikoMode.SYNC_BAR:
		return
	sync_bar += SYNC_BAR_PASSIVE_FILL + (rhythm_accuracy * SYNC_BAR_RHYTHM_BONUS)
	sync_bar = minf(sync_bar, 1.0)
	sync_bar_updated.emit(sync_bar)
	if sync_bar >= 1.0:
		sync_bar = 0.0
		if sync_points < MAX_SYNC_POINTS:
			sync_points += 1
			sync_point_gained.emit(sync_points)


func consume_sync_point() -> bool:
	if sync_points <= 0:
		return false
	sync_points -= 1
	return true


# ── Stats efetivos com buffs ────────────────────────────────────────────

func get_effective_atk() -> int:
	var base := atk
	if equipped_weapon:
		base += equipped_weapon.base_atk - 10   # bônus relativo à baseline
	return _apply_buffs("atk", base)


func get_effective_mag() -> int:
	return _apply_buffs("mag", mag)


func get_effective_def() -> int:
	var base := def
	if equipped_weapon:
		base += equipped_weapon.get("base_def_bonus", 0)
	return _apply_buffs("def", base)


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


func to_dict() -> Dictionary:
	return {
		"id": character_id, "name": display_name, "is_enemy": is_enemy,
		"max_hp": max_hp, "max_mp": max_mp, "max_echo": max_echo,
		"atk": atk, "mag": mag, "def": def, "res": res, "spd": spd,
		"current_hp": current_hp, "current_mp": current_mp, "current_echo": current_echo,
		"skills": skills, "aiko_skills": aiko_skills,
		"equipped_weapon": equipped_weapon.weapon_id if equipped_weapon else "",
		"sync_bar": sync_bar, "sync_points": sync_points,
	}
