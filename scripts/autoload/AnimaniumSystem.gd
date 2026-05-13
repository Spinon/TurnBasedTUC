extends Node

# Sistema de formas do Animanium — pool crescente com a progressão narrativa
#
# Progressão por setor:
#   Setores 1-3  → pool_tier 1 → 3 formas  (jogador pensa que são skills fixas)
#   Setores 4-6  → pool_tier 2 → 6 formas  (primeira surpresa)
#   Setores 7-9  → pool_tier 3 → 9 formas
#   Setores 10-12 → pool_tier 4 → 12 formas
#
# Em batalha: 3 formas aleatórias da pool atual são oferecidas → jogador escolhe 1

const SHAPES_DATA_PATH := "res://data/animanium_shapes.json"
const TIER_THRESHOLDS := [1, 4, 7, 10]   # setor onde cada tier desbloqueia
const SHAPES_PER_TIER := 3

var _all_shapes: Array[Dictionary] = []
var _current_pool: Array[Dictionary] = []
var _current_tier: int = 0

signal pool_expanded(new_shapes: Array, new_tier: int)
signal shapes_selected(shapes: Array)    # 3 formas oferecidas em batalha


func _ready() -> void:
	_load_shapes()
	_update_pool_for_sector(GameManager.current_sector)
	GameManager.sector_changed.connect(_on_sector_changed)


func _load_shapes() -> void:
	var file := FileAccess.open(SHAPES_DATA_PATH, FileAccess.READ)
	if not file:
		push_error("AnimaniumSystem: shapes data not found at %s" % SHAPES_DATA_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Array:
		for s in parsed:
			_all_shapes.append(s)


func _on_sector_changed(sector: int) -> void:
	_update_pool_for_sector(sector)


func _update_pool_for_sector(sector: int) -> void:
	var new_tier := 0
	for i in TIER_THRESHOLDS.size():
		if sector >= TIER_THRESHOLDS[i]:
			new_tier = i

	if new_tier <= _current_tier:
		return

	# Desbloqueia tiers entre o atual e o novo (caso setor salte)
	for tier in range(_current_tier, new_tier):
		var start_idx := tier * SHAPES_PER_TIER
		var end_idx := start_idx + SHAPES_PER_TIER
		var newly_unlocked: Array[Dictionary] = []
		for i in range(start_idx, mini(end_idx, _all_shapes.size())):
			if not _current_pool.any(func(s): return s.id == _all_shapes[i].id):
				_current_pool.append(_all_shapes[i])
				newly_unlocked.append(_all_shapes[i])
		if newly_unlocked.size() > 0:
			pool_expanded.emit(newly_unlocked, tier + 1)

	_current_tier = new_tier


# Chamado pelo BattleManager quando Leo usa uma skill de Animanium
# Retorna 3 formas aleatórias da pool atual
func draw_battle_selection() -> Array[Dictionary]:
	if _current_pool.is_empty():
		return []

	var pool_copy := _current_pool.duplicate()
	pool_copy.shuffle()
	var selection: Array[Dictionary] = []
	for i in mini(3, pool_copy.size()):
		selection.append(pool_copy[i])

	shapes_selected.emit(selection)
	return selection


func get_pool_size() -> int:
	return _current_pool.size()


func get_current_tier() -> int:
	return _current_tier


# Chamado quando Aiko ensina uma forma específica via evento narrativo
# (override manual — para cutscenes ou eventos especiais)
func unlock_shape_by_id(shape_id: String) -> void:
	var shape := _all_shapes.filter(func(s): return s.id == shape_id)
	if shape.is_empty():
		return
	if not _current_pool.any(func(s): return s.id == shape_id):
		_current_pool.append(shape[0])


func get_save_data() -> Dictionary:
	return {
		"tier": _current_tier,
		"pool_ids": _current_pool.map(func(s): return s.id),
	}


func load_save_data(data: Dictionary) -> void:
	_current_tier = data.get("tier", 0)
	var ids: Array = data.get("pool_ids", [])
	_current_pool.clear()
	for id in ids:
		var match_shape := _all_shapes.filter(func(s): return s.id == id)
		if not match_shape.is_empty():
			_current_pool.append(match_shape[0])
