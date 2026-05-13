extends Node

# Controla o fluxo completo do combate por turno do TUC
# Ordem de turno determinada por SPD. Aiko age como sub-menu de Leo, não como combatente separado.
# Integra RhythmSystem e AnimaniumSystem.

enum BattlePhase {
	NONE, START, PLAYER_TURN, ENEMY_TURN,
	RHYTHM_INPUT,       # jogador está no minigame de ritmo
	ANIMANIUM_SELECT,   # jogador está escolhendo a forma do Animanium
	EXECUTE_ACTION, CHECK_END, VICTORY, DEFEAT
}

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

signal phase_changed(phase: BattlePhase)
signal action_executed(actor: CharacterData, target: CharacterData, skill: Dictionary)
signal battle_ended(victory: bool)
signal log_updated(message: String)
signal animanium_shapes_ready(shapes: Array)   # UI precisa mostrar as 3 opções


func _ready() -> void:
	_rhythm = RhythmSystem.new()
	add_child(_rhythm)
	_rhythm.rhythm_completed.connect(_on_rhythm_completed)


func start_battle(enemy_list: Array[CharacterData]) -> void:
	enemies = enemy_list
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
	while current_actor_index < turn_queue.size() and turn_queue[current_actor_index].current_hp <= 0:
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
		_set_phase(BattlePhase.PLAYER_TURN)
		# UI aguarda o jogador escolher ação


# Chamado pela UI com a ação escolhida pelo jogador
func execute_player_action(actor: CharacterData, skill: Dictionary, target: CharacterData) -> void:
	_pending_actor = actor
	_pending_skill = skill
	_pending_target = target
	_rhythm_multiplier = 1.0

	var needs_animanium := skill.get("is_animanium", false)
	var has_rhythm := skill.get("rhythm_beats", 0) > 0

	if needs_animanium:
		# Primeiro escolhe a forma, depois (se tiver ritmo) faz o ritmo
		_set_phase(BattlePhase.ANIMANIUM_SELECT)
		var shapes := AnimaniumSystem.draw_battle_selection()
		animanium_shapes_ready.emit(shapes)
		# UI chama confirm_animanium_shape() com a forma escolhida
	elif has_rhythm:
		_start_rhythm(skill)
	else:
		_execute_pending_action()


# Chamado pela UI quando o jogador escolheu uma forma do Animanium
func confirm_animanium_shape(shape: Dictionary) -> void:
	# Mescla o efeito da forma na skill pendente
	var effect: Dictionary = shape.get("effect", {})
	_pending_skill = _pending_skill.merged(effect, true)
	_pending_skill["shape_name"] = shape.get("name", "")
	_pending_skill["shape_flavor"] = effect.get("special_flavor", "")

	if _pending_skill.get("rhythm_beats", 0) > 0:
		_start_rhythm(_pending_skill)
	else:
		_execute_pending_action()


func _start_rhythm(skill: Dictionary) -> void:
	_set_phase(BattlePhase.RHYTHM_INPUT)
	_rhythm.start(skill)
	# _on_rhythm_completed será chamado pelo sinal quando terminar


func _on_rhythm_completed(accuracy: float, perfect: bool) -> void:
	_rhythm_multiplier = RhythmSystem.get_damage_multiplier(accuracy)
	if perfect:
		_pending_skill["perfect_hit"] = true
	_execute_pending_action()


func _execute_pending_action() -> void:
	_set_phase(BattlePhase.EXECUTE_ACTION)
	_apply_skill(_pending_actor, _pending_skill, _pending_target, _rhythm_multiplier)
	action_executed.emit(_pending_actor, _pending_target, _pending_skill)
	await get_tree().create_timer(1.0).timeout
	_check_battle_end()


func _execute_enemy_action(enemy: CharacterData) -> void:
	_set_phase(BattlePhase.EXECUTE_ACTION)
	var alive_party := PartyManager.get_alive_members()
	if alive_party.is_empty():
		return
	var target: CharacterData = alive_party[randi() % alive_party.size()]
	var skill: Dictionary = enemy.skills[0] if enemy.skills.size() > 0 else \
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
			var effective_def := int(target.get_effective_def() * (1.0 - pierce))
			damage = maxi(1, int(actor.get_effective_atk() * power) - effective_def)
			# Multi-hit (ex: Flecha Dupla)
			var hits: int = skill.get("hits", 1)
			damage *= hits
			target.current_hp -= damage
		"magical", "echo", "dimensional":
			var ignore_res: bool = skill.get("ignore_res", false)
			var effective_res := 0 if ignore_res else target.get_effective_res()
			damage = maxi(1, int(actor.get_effective_mag() * power) - effective_res)
			target.current_hp -= damage
		"heal":
			var heal := int(actor.get_effective_mag() * power)
			target.current_hp = mini(target.current_hp + heal, target.max_hp)
			damage = -heal
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
				var shield_target := actor if skill.get("shield_target") == "self" else target
				_apply_shield(shield_target, skill)

	target.current_hp = maxi(0, target.current_hp)

	# Efeito especial do 100% de ritmo
	if skill.get("perfect_hit", false):
		_apply_perfect_effect(actor, skill, target)

	var flavor: String = skill.get("shape_flavor", "")
	var suffix := (" — \"%s\"" % flavor) if flavor else ""
	var rhythm_note := (" [×%.1f ritmo]" % multiplier) if multiplier != 1.0 else ""
	var msg := "[%s] usou [%s%s] em [%s] → %s%s" % [
		actor.display_name,
		skill.get("name", "?"),
		(" / %s" % skill.get("shape_name", "")) if skill.has("shape_name") else "",
		target.display_name,
		("+" + str(abs(damage)) + " HP" if damage < 0 else str(damage) + " de dano"),
		rhythm_note + suffix
	]
	_log(msg)


func _apply_buff(target: CharacterData, skill: Dictionary) -> void:
	var stat: String = skill.get("buff_stat", "atk")
	var mult: float = skill.get("buff_multiplier", 1.2)
	var dur: int = skill.get("buff_duration", 3)
	target.active_buffs.append({"stat": stat, "multiplier": mult, "turns_left": dur})
	_log("[%s] recebeu buff em %s (×%.1f, %d turnos)" % [target.display_name, stat, mult, dur])


func _apply_shield(target: CharacterData, skill: Dictionary) -> void:
	var shield_hp: int = skill.get("shield_hp", 30)
	target.active_buffs.append({"stat": "shield", "hp": shield_hp, "turns_left": 999})
	_log("[%s] ganhou escudo de %d HP" % [target.display_name, shield_hp])


func _apply_status(target: CharacterData, skill: Dictionary) -> void:
	var status: String = skill.get("status", "")
	var dur: int = skill.get("status_duration", 2)
	if status:
		target.active_buffs.append({"stat": "status_" + status, "turns_left": dur})
		_log("[%s] sofreu %s por %d turnos" % [target.display_name, status, dur])


func _apply_perfect_effect(actor: CharacterData, skill: Dictionary, target: CharacterData) -> void:
	# Efeito especial de 100% ritmo — definido por skill ou forma do Animanium
	var perfect_type: String = skill.get("perfect_effect", "stun")
	match perfect_type:
		"stun":
			target.active_buffs.append({"stat": "status_stun", "turns_left": 1})
			_log("✦ PERFEITO! [%s] ficou atordoado!" % target.display_name)
		"recover_mp":
			actor.current_mp = mini(actor.current_mp + 15, actor.max_mp)
			_log("✦ PERFEITO! [%s] recuperou 15 MP!" % actor.display_name)
		"double":
			_log("✦ PERFEITO! Golpe duplo!")


func _tick_status_effects() -> void:
	for combatant in turn_queue:
		for i in range(combatant.active_buffs.size() - 1, -1, -1):
			combatant.active_buffs[i]["turns_left"] -= 1
			if combatant.active_buffs[i]["turns_left"] <= 0:
				combatant.active_buffs.remove_at(i)


func _check_battle_end() -> void:
	_set_phase(BattlePhase.CHECK_END)
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
