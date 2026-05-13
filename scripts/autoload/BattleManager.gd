extends Node

# Controla o fluxo completo do combate por turno do TUC
# Ordem de turno determinada por SPD. Aiko age como sub-menu de Leo, não como combatente separado.

enum BattlePhase {
	NONE, START, PLAYER_TURN, ENEMY_TURN, EXECUTE_ACTION, CHECK_END, VICTORY, DEFEAT
}

var current_phase: BattlePhase = BattlePhase.NONE
var turn_queue: Array[CharacterData] = []   # ordem de ação no turno
var current_actor_index: int = 0
var enemies: Array[CharacterData] = []
var battle_log: Array[String] = []

signal phase_changed(phase: BattlePhase)
signal action_executed(actor: CharacterData, target: CharacterData, skill: Dictionary)
signal battle_ended(victory: bool)
signal log_updated(message: String)


func start_battle(enemy_list: Array[CharacterData]) -> void:
	enemies = enemy_list
	battle_log.clear()
	_build_turn_queue()
	_set_phase(BattlePhase.START)
	await get_tree().create_timer(0.5).timeout
	_next_turn()


func _build_turn_queue() -> void:
	turn_queue.clear()
	var all: Array[CharacterData] = []
	all.append_array(PartyManager.party)
	all.append_array(enemies)
	# Ordena por SPD decrescente; empate quebrado por personagens do jogador primeiro
	all.sort_custom(func(a, b):
		if a.spd != b.spd:
			return a.spd > b.spd
		return not a.is_enemy
	)
	turn_queue = all


func _next_turn() -> void:
	# Pula personagens mortos
	while current_actor_index < turn_queue.size() and turn_queue[current_actor_index].current_hp <= 0:
		current_actor_index += 1

	if current_actor_index >= turn_queue.size():
		current_actor_index = 0
		_tick_status_effects()
		_build_turn_queue()  # Recalcula caso SPD tenha mudado
		_next_turn()
		return

	var actor := turn_queue[current_actor_index]
	if actor.is_enemy:
		_set_phase(BattlePhase.ENEMY_TURN)
		await get_tree().create_timer(0.8).timeout
		_execute_enemy_action(actor)
	else:
		_set_phase(BattlePhase.PLAYER_TURN)
		# UI aguarda o jogador escolher ação — execute_player_action() é chamado externamente


func execute_player_action(actor: CharacterData, skill: Dictionary, target: CharacterData) -> void:
	_set_phase(BattlePhase.EXECUTE_ACTION)
	_apply_skill(actor, skill, target)
	action_executed.emit(actor, target, skill)
	await get_tree().create_timer(1.0).timeout
	_check_battle_end()


func _execute_enemy_action(enemy: CharacterData) -> void:
	_set_phase(BattlePhase.EXECUTE_ACTION)
	var alive_party := PartyManager.get_alive_members()
	if alive_party.is_empty():
		return
	var target: CharacterData = alive_party[randi() % alive_party.size()]
	var skill: Dictionary = enemy.skills[0] if enemy.skills.size() > 0 else {"name": "Ataque", "power": 1.0, "type": "physical", "mp_cost": 0}
	_apply_skill(enemy, skill, target)
	action_executed.emit(enemy, target, skill)
	await get_tree().create_timer(1.0).timeout
	_check_battle_end()


func _apply_skill(actor: CharacterData, skill: Dictionary, target: CharacterData) -> void:
	var skill_type: String = skill.get("type", "physical")
	var power: float = skill.get("power", 1.0)
	var mp_cost: int = skill.get("mp_cost", 0)
	var echo_cost: int = skill.get("echo_cost", 0)  # Custo especial das habilidades de Aiko

	# Consome recursos
	actor.current_mp -= mp_cost
	actor.current_echo -= echo_cost

	var damage := 0
	match skill_type:
		"physical":
			damage = maxi(1, int(actor.atk * power) - target.def)
			target.current_hp -= damage
		"magical", "echo":
			# Habilidades de Aiko usam MAG de Leo e ignoram DEF física
			damage = maxi(1, int(actor.mag * power) - target.res)
			target.current_hp -= damage
		"heal":
			var heal_amount := int(actor.mag * power)
			target.current_hp = mini(target.current_hp + heal_amount, target.max_hp)
			damage = -heal_amount  # Negativo = cura no log
		"buff":
			_apply_buff(target, skill)

	target.current_hp = maxi(0, target.current_hp)
	var msg := "[%s] usou [%s] em [%s] → %s" % [
		actor.display_name, skill.get("name", "?"),
		target.display_name,
		("+" + str(abs(damage)) + " HP" if damage < 0 else str(damage) + " de dano")
	]
	_log(msg)


func _apply_buff(target: CharacterData, skill: Dictionary) -> void:
	var stat: String = skill.get("buff_stat", "atk")
	var multiplier: float = skill.get("buff_multiplier", 1.2)
	var duration: int = skill.get("buff_duration", 3)
	target.active_buffs.append({"stat": stat, "multiplier": multiplier, "turns_left": duration})
	_log("[%s] recebeu buff em %s (x%.1f por %d turnos)" % [target.display_name, stat, multiplier, duration])


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
