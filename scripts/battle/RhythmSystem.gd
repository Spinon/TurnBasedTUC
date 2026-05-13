class_name RhythmSystem
extends Node

# Minigame de ritmo do TUC
# Regras:
#   - Sequência de 2-4 beats por skill
#   - Accuracy% = bônus de dano%  (ex: 3/4 = +75% dano)
#   - 100% acerto → bônus máximo + special_effect da skill
#   - Config skip_rhythm → executa automático com +50% fixo

const BEAT_WINDOW := 0.30      # janela de acerto (segundos)
const BEAT_INTERVAL := 0.90    # tempo entre beats
const APPROACH_TIME := 0.70    # tempo do beat se aproximar antes da janela

enum BeatResult { PENDING, HIT, MISS }

signal rhythm_completed(accuracy: float, perfect: bool)
signal beat_spawned(beat_index: int, total_beats: int)
signal beat_resolved(beat_index: int, result: BeatResult)

var _beats_total: int = 0
var _beats_hit: int = 0
var _current_beat: int = 0
var _beat_active: bool = false
var _beat_timer: float = 0.0
var _waiting_input: bool = false
var _sequence_running: bool = false

# Definição de beats: cada entry tem { "input": "rhythm_hit" } — extensível para inputs variados
var _sequence: Array[Dictionary] = []


func start(skill: Dictionary) -> void:
	if GameManager.get_flag("skip_rhythm"):
		rhythm_completed.emit(0.5, false)   # skip = +50% fixo
		return

	_beats_total = skill.get("rhythm_beats", 3)
	_beats_hit = 0
	_current_beat = 0
	_beat_active = false
	_beat_timer = 0.0
	_sequence_running = true
	_build_sequence(_beats_total)
	set_process(true)


func _build_sequence(count: int) -> void:
	_sequence.clear()
	# Por enquanto todos os beats usam rhythm_hit
	# Futuro: habilidades avançadas podem ter inputs diferentes (L1, R1, direcional...)
	for i in count:
		_sequence.append({"input": "rhythm_hit"})


func _process(delta: float) -> void:
	if not _sequence_running:
		return

	_beat_timer += delta

	# Spawn do próximo beat
	if not _beat_active and _current_beat < _beats_total:
		if _beat_timer >= BEAT_INTERVAL * _current_beat:
			_beat_active = true
			_waiting_input = true
			_beat_spawn_time = _beat_timer
			beat_spawned.emit(_current_beat, _beats_total)

	# Janela de input aberta
	if _beat_active and _waiting_input:
		var elapsed := _beat_timer - _beat_spawn_time - APPROACH_TIME
		if elapsed > BEAT_WINDOW:
			_resolve_beat(BeatResult.MISS)


func _input(event: InputEvent) -> void:
	if not _sequence_running or not _waiting_input:
		return

	var expected_input: String = _sequence[_current_beat].get("input", "rhythm_hit")
	if event.is_action_pressed(expected_input):
		var elapsed := _beat_timer - _beat_spawn_time - APPROACH_TIME
		# Considera hit se dentro da janela (pode ser antes ou durante)
		if elapsed >= -0.05 and elapsed <= BEAT_WINDOW:
			_resolve_beat(BeatResult.HIT)
		# Input muito cedo → miss (não "guarda" o input)


func _resolve_beat(result: BeatResult) -> void:
	_waiting_input = false
	_beat_active = false
	if result == BeatResult.HIT:
		_beats_hit += 1
	beat_resolved.emit(_current_beat, result)
	_current_beat += 1

	if _current_beat >= _beats_total:
		_finish()


func _finish() -> void:
	_sequence_running = false
	set_process(false)
	var accuracy := float(_beats_hit) / float(_beats_total)
	var perfect := _beats_hit == _beats_total
	rhythm_completed.emit(accuracy, perfect)


# Retorna o multiplicador de dano baseado no accuracy
static func get_damage_multiplier(accuracy: float) -> float:
	return 1.0 + accuracy   # 0% acerto = ×1.0 | 100% acerto = ×2.0


var _beat_spawn_time: float = 0.0
