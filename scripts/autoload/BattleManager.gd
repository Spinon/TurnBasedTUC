extends Node

# Controla o fluxo completo do combate por turno do TUC.
#
# Turno do Leo = 2 sub-ações:
#   1. Ação de Arma: Atacar (sem ritmo) | Skill 1/2/3 (rítmicas, dependem da arma)
#   2. Ação de Aiko: deck de Animanium (modo varia por setor: PROC / GUARANTEED / SYNC_BAR)
#
# Outros personagens (Julia, Elara, inimigos) = 1 ação por turno normal.

enum BattlePhase {
	NONE, START,
	PLAYER_TURN,            # UI aguarda escolha de arma
	RHYTHM_INPUT,           # jogador fazendo minigame de ritmo
	ANIMANIUM_SELECT,       # jogador escolhendo forma do Animanium (ação da Aiko)
	ENEMY_TURN,
	EXECUTE_ACTION,
	CHECK_END, VICTORY, DEFEAT
}

# Sub-fases do turno do Leo
enum LeoSubPhase { WEAPON_ACTION, AIKO_ACTION, DONE }

var current_phase: BattlePhase = BattlePhase.NONE
var turn_queue: Array[CharacterData] = []
var current_actor_index: int = 0
var enemies: Array[CharacterData] = []
var battle_log: Array[String] = []

var _rhythm: RhythmSystem
var _pending_actor: CharacterData = null
var _pending_skill: Dictionary = {}
var _pending_target: CharacterData = null
var _rhythm_multiplier: float = 1.0
var _last_rhythm_accuracy: float = 0.0

# Controle do turno duplo do Leo
var _leo_sub_phase: LeoSubPhase = LeoSubPhase.WEAPON_ACTION
var _aiko_available_this_turn: bool = false
var _aiko_extra_actions: int = 0    # Cargas de sincronia usadas no turno atual

signal phase_changed(phase: BattlePhase)
signal action_executed(actor: CharacterData, target: CharacterData, skill: Dictionary)
signal battle_ended(victory: bool)
signal log_updated(message: String)
signal animanium_shapes_ready(shapes: Array)
signal aiko_action_available(mode: CharacterData.AikoMode)
signal aiko_action_unavailable()
signal sync_bar_ticked(value: float, points: int)


func _ready() -> void:
	_rhythm = RhythmSystem.new()
	add_child(_rhythm)
	_rhythm.rhythm_completed.connect(_on_rhythm_completed)


func start_battle(enemy_list: Array[CharacterData]) -> void:
	enemies = enemy_list.duplicate()
	battle_log.clear()
	current_actor_index = 0
	_build_turn_queue()
	_set_phase(BattlePhase.START)
	await get_tree().create_timer(0.5).timeout
	_next_turn()


func _build_turn_queue() -> void:
	turn_queue.clear()
	var all: Array[CharacterData] = []
	all.append_array(PartyManager.party)
	all.append_array(enemies)
	all.sort_custom(func(a, b):
		if a.spd != b.spd:
			return a.spd > b.spd
		return not a.is_enemy
	)
	turn_queue = all


func _next_turn() -> void:
	while current_actor_index < turn_queue.size() \
			and turn_queue[current_actor_index].current_hp <= 0:
		current_actor_index += 1

	if current_actor_index >= turn_queue.size():
		current_actor_index = 0
		_tick_status_effects()
		_build_turn_queue()
		_next_turn()
		return

	var actor := turn_queue[current_actor_index]

	if actor.is_enemy:
		_set_phase(BattlePhase.ENEMY_TURN)
		await get_tree().create_timer(0.8).timeout
		_execute_enemy_action(actor)
	else:
		_start_player_turn(actor)


func _start_player_turn(actor: CharacterData) -> void:
	_leo_sub_phase = LeoSubPhase.WEAPON_ACTION
	_aiko_available_this_turn = false
	_aiko_extra_actions = 0

	# Determina se a ação da Aiko está disponível neste turno
	if actor.character_id == "leo":
		match actor.aiko_mode:
			CharacterData.AikoMode.PROC:
				_aiko_available_this_turn = actor.roll_aiko_proc()
			CharacterData.AikoMode.GUARANTEED:
				_aiko_available_this_turn = true
			CharacterData.AikoMode.SYNC_BAR:
				_aiko_available_this_turn = true   # sempre disponível; cargas extras são opcionais

	_set_phase(BattlePhase.PLAYER_TURN)

	if _aiko_available_this_turn:
		aiko_action_available.emit(actor.aiko_mode)
	else:
		aiko_action_unavailable.emit()


# ── Ação de arma (chamada pela UI) ──────────────────────────────────────

func execute_weapon_action(actor: CharacterData, skill: Dictionary, target: CharacterData) -> void:
	_pending_actor = actor
	_pending_skill = skill
	_pending_target = target
	_rhythm_multiplier = 1.0
	_last_rhythm_accuracy = 0.0

	var beats: int = skill.get("rhythm_beats", 0)
	if beats > 0:
		_start_rhythm(skill)
	else:
		await _execute_pending_action()
		_after_weapon_action(actor)


func _after_weapon_action(actor: CharacterData) -> void:
	# Atualiza barra de sincronia com a accuracy do ritmo (se houve)
	if actor.character_id == "leo" and actor.aiko_mode == CharacterData.AikoMode.SYNC_BAR:
		actor.tick_sync_bar(_last_rhythm_accuracy)
		sync_bar_ticked.emit(actor.sync_bar, actor.sync_points)

	# Passa para a sub-ação da Aiko
	if _aiko_available_this_turn and actor.character_id == "leo":
		_leo_sub_phase = LeoSubPhase.AIKO_ACTION
		_offer_aiko_action(actor)
	else:
		_finish_actor_turn()


# ── Ação da Aiko (Animanium) ────────────────────────────────────────────

func _offer_aiko_action(actor: CharacterData) -> void:
	_set_phase(BattlePhase.ANIMANIUM_SELECT)
	var shapes := AnimaniumSystem.draw_battle_selection()
	animanium_shapes_ready.emit(shapes)
	# UI chama confirm_animanium_shape() ou skip_aiko_action()


func confirm_animanium_shape(shape: Dictionary, target: CharacterData) -> void:
	var effect: Dictionary = shape.get("effect", {})
	var aiko_skill := {
		"name": "Eco — %s" % shape.get("name", "?"),
		"shape_name": shape.get("name", ""),
		"shape_flavor": effect.get("special_flavor", ""),
		"mp_cost": 0,
		"echo_cost": 0,
	}
	aiko_skill.merge(effect, true)

	_pending_actor = turn_queue[current_actor_index]
	_pending_skill = aiko_skill
	_pending_target = target
	_rhythm_multiplier = 1.0

	await _execute_pending_action()

	# Verifica se tem carga extra de sincronia para usar
	var actor := turn_queue[current_actor_index]
	if actor.aiko_mode == CharacterData.AikoMode.SYNC_BAR \
			and actor.sync_points > 0 and _aiko_extra_actions < CharacterData.MAX_SYNC_POINTS:
		# UI pode oferecer usar uma carga extra — chama use_sync_charge() ou _finish_actor_turn()
		pass
	else:
		_finish_actor_turn()


# Jogador escolhe gastar uma carga de sincronia para repetir a ação da Aiko
func use_sync_charge(target: CharacterData) -> void:
	var actor := turn_queue[current_actor_index]
	if not actor.consume_sync_point():
		_finish_actor_turn()
		return
	_aiko_extra_actions += 1
	_offer_aiko_action(actor)


func skip_aiko_action() -> void:
	_finish_actor_turn()


func _finish_actor_turn() -> void:
	_leo_sub_phase = LeoSubPhase.DONE
	_check_battle_end()


# ── Ritmo ───────────────────────────────────────────────────────────────

func _start_rhythm(skill: Dictionary) -> void:
	_set_phase(BattlePhase.RHYTHM_INPUT)
	_rhythm.start(skill)


func _on_rhythm_completed(accuracy: float, perfect: bool) -> void:
	_last_rhythm_accuracy = accuracy
	_rhythm_multiplier = RhythmSystem.get_damage_multiplier(accuracy)
	if perfect:
		_pending_skill["perfect_hit"] = true
	_set_phase(BattlePhase.EXECUTE_ACTION)
	await _execute_pending_action()
	_after_weapon_action(_pending_actor)


# ── Execução de skill ───────────────────────────────────────────────────

func _execute_pending_action() -> void:
	_set_phase(BattlePhase.EXECUTE_ACTION)
	_apply_skill(_pending_actor, _pending_skill, _pending_target, _rhythm_multiplier)
	action_executed.emit(_pending_actor, _pending_target, _pending_skill)
	await get_tree().create_timer(1.0).timeout


func _execute_enemy_action(enemy: CharacterData) -> void:
	var alive_party := PartyManager.get_alive_members()
	if alive_party.is_empty():
		return
	var target: CharacterData = alive_party[randi() % alive_party.size()]
	var skill: Dictionary = enemy.skills[0] if not enemy.skills.is_empty() else \
		{"name": "Ataque", "power": 1.0, "type": "physical", "mp_cost": 0}
	_apply_skill(enemy, skill, target, 1.0)
	action_executed.emit(enemy, target, skill)
	await get_tree().create_timer(1.0).timeout
	_check_battle_end()


func _apply_skill(actor: CharacterData, skill: Dictionary, target: CharacterData, multiplier: float = 1.0) -> void:
	var skill_type: String = skill.get("type", "physical")
	var base_power: float = skill.get("power_multiplier", skill.get("power", 1.0))
	var power := base_power * multiplier
	var mp_cost: int = skill.get("mp_cost", 0)
	var echo_cost: int = skill.get("echo_cost", 0)

	actor.current_mp = maxi(0, actor.current_mp - mp_cost)
	actor.current_echo = maxi(0, actor.current_echo - echo_cost)

	var damage := 0
	match skill_type:
		"physical":
			var pierce: float = skill.get("def_pierce", 0.0)
			var eff_def := int(actor.get_effective_def() * (1.0 - pierce)) \
				if not skill.get("ignore_def", false) else 0
			damage = maxi(1, int(actor.get_effective_atk() * power) - eff_def)
			damage *= skill.get("hits", 1)
			target.current_hp -= damage
		"magical", "echo", "dimensional":
			var eff_res := actor.get_effective_res() \
				if not skill.get("ignore_res", false) else 0
			damage = maxi(1, int(actor.get_effective_mag() * power) - eff_res)
			target.current_hp -= damage
		"heal":
			var h := int(actor.get_effective_mag() * power)
			target.current_hp = mini(target.current_hp + h, target.max_hp)
			damage = -h
		"buff", "debuff":
			_apply_buff(target, skill)
		"shield":
			_apply_shield(target, skill)
		"status":
			damage = maxi(1, int(actor.get_effective_atk() * power) - target.get_effective_def())
			target.current_hp -= damage
			_apply_status(target, skill)
		"hybrid":
			damage = maxi(1, int(actor.get_effective_atk() * power) - target.get_effective_def())
			target.current_hp -= damage
			if skill.has("shield_hp"):
				var st := actor if skill.get("shield_target") == "self" else target
				_apply_shield(st, skill)

	target.current_hp = maxi(0, target.current_hp)

	if skill.get("perfect_hit", false):
		_apply_perfect_effect(actor, skill, target)

	_log_action(actor, skill, target, damage, multiplier)


func _apply_buff(target: CharacterData, skill: Dictionary) -> void:
	target.active_buffs.append({
		"stat": skill.get("buff_stat", "atk"),
		"multiplier": skill.get("buff_multiplier", 1.2),
		"turns_left": skill.get("buff_duration", 3),
	})


func _apply_shield(target: CharacterData, skill: Dictionary) -> void:
	target.active_buffs.append({"stat": "shield", "hp": skill.get("shield_hp", 30), "turns_left": 999})
	_log("[%s] ganhou escudo de %d HP" % [target.display_name, skill.get("shield_hp", 30)])


func _apply_status(target: CharacterData, skill: Dictionary) -> void:
	var status: String = skill.get("status", "")
	if status:
		target.active_buffs.append({"stat": "status_" + status, "turns_left": skill.get("status_duration", 2)})


func _apply_perfect_effect(actor: CharacterData, skill: Dictionary, target: CharacterData) -> void:
	match skill.get("perfect_effect", "stun"):
		"stun":
			target.active_buffs.append({"stat": "status_stun", "turns_left": 1})
			_log("✦ PERFEITO! [%s] ficou atordoado!" % target.display_name)
		"recover_mp":
			actor.current_mp = mini(actor.current_mp + 15, actor.max_mp)
			_log("✦ PERFEITO! [%s] recuperou 15 MP!" % actor.display_name)
		"double":
			_log("✦ PERFEITO! Dano dobrado!")


func _log_action(actor: CharacterData, skill: Dictionary, target: CharacterData, damage: int, mult: float) -> void:
	var shape := (" / %s" % skill["shape_name"]) if skill.has("shape_name") else ""
	var rhythm_note := (" [×%.1f]" % mult) if mult != 1.0 else ""
	var flavor := (" — \"%s\"" % skill["shape_flavor"]) if skill.get("shape_flavor") else ""
	var dmg_str := ("+%d HP" % abs(damage)) if damage < 0 else ("%d dano" % damage)
	_log("[%s] %s%s em [%s] → %s%s%s" % [
		actor.display_name, skill.get("name", "?"), shape,
		target.display_name, dmg_str, rhythm_note, flavor
	])


func _tick_status_effects() -> void:
	for combatant in turn_queue:
		for i in range(combatant.active_buffs.size() - 1, -1, -1):
			combatant.active_buffs[i]["turns_left"] -= 1
			if combatant.active_buffs[i]["turns_left"] <= 0:
				combatant.active_buffs.remove_at(i)


func _check_battle_end() -> void:
	if enemies.all(func(e): return e.current_hp <= 0):
		_set_phase(BattlePhase.VICTORY)
		battle_ended.emit(true)
		return
	if PartyManager.is_party_wiped():
		_set_phase(BattlePhase.DEFEAT)
		battle_ended.emit(false)
		return
	current_actor_index += 1
	_next_turn()


func _set_phase(phase: BattlePhase) -> void:
	current_phase = phase
	phase_changed.emit(phase)


func _log(message: String) -> void:
	battle_log.append(message)
	log_updated.emit(message)
