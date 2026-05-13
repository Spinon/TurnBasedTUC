extends Node

# Batalha de apresentação para o Marcos — tutorial disfarçado de batalha real.
#
# Mecânicas reusadas de BattleManager, mas com semântica diferente:
#   - "HP do inimigo" → Barra de Convicção (0.0 a 1.0, começa em 0.0, vencer = encher)
#   - "Ataques do Marcos" → Objeções que drenam a Convicção
#   - Derrota → Não tem game-over, apenas reinicia a apresentação com feedback narrativo
#   - Vitória → Convicção >= WIN_THRESHOLD

signal battle_finished()
signal conviction_changed(new_value: float)
signal marco_objection(text: String)
signal player_argument_resolved(accuracy: float, perfect: bool)

const WIN_THRESHOLD := 1.0
const CONVICTION_PER_RHYTHM_HIT := 0.25     # por beat correto
const CONVICTION_BONUS_PERFECT := 0.15      # bônus extra se perfeito
const CONVICTION_DRAIN_OBJECTION := 0.20    # quanto cada objeção drena

const MAX_ROUNDS := 6   # rodadas antes de Marcos encerrar a reunião

var conviction: float = 0.0
var current_round: int = 0
var _selected_shape: Dictionary = {}
var _battle_active: bool = false

@onready var _rhythm_system: RhythmSystem = $"../RhythmSystem"
@onready var _dialogue_box: Control = $"../DialogueBox"
@onready var _conviction_bar: ProgressBar = $"../ConvictionBar"


func _ready() -> void:
	_rhythm_system.rhythm_completed.connect(_on_rhythm_completed)


# Inicia a batalha. shape = formato de animanium escolhido no PROJECT_SELECT.
func start(shape: Dictionary) -> void:
	_selected_shape = shape
	conviction = 0.0
	current_round = 0
	_battle_active = true
	_conviction_bar.max_value = 1.0
	_conviction_bar.value = 0.0
	_conviction_bar.show()
	conviction_changed.emit(conviction)
	_run_round()


# ── Loop de rodadas ──────────────────────────────────────────────────────────

func _run_round() -> void:
	if not _battle_active:
		return

	current_round += 1

	# Rodada de Marcos primeiro (objeção), depois jogador defende com ritmo
	await _marcos_attacks()
	if not _battle_active:
		return

	# Defesa do Leo = rhythm task
	var argument_skill := _build_argument_skill()
	_rhythm_system.start(argument_skill)
	# Continua em _on_rhythm_completed


func _marcos_attacks() -> void:
	var objection := _pick_objection()
	marco_objection.emit(objection.text)
	await _show_dialogue([{"speaker": "Marcos", "text": objection.text}])
	_drain_conviction(CONVICTION_DRAIN_OBJECTION * objection.weight)


# ── Signal handlers ──────────────────────────────────────────────────────────

func _on_rhythm_completed(accuracy: float, perfect: bool) -> void:
	if not _battle_active:
		return

	var gained := accuracy * CONVICTION_PER_RHYTHM_HIT * _selected_shape.get("power_multiplier", 1.0)
	if perfect:
		gained += CONVICTION_BONUS_PERFECT
	_fill_conviction(gained)
	player_argument_resolved.emit(accuracy, perfect)

	var feedback := _argument_feedback(accuracy, perfect)
	await _show_dialogue([{"speaker": "Leo", "text": feedback}])

	if conviction >= WIN_THRESHOLD:
		_win()
	elif current_round >= MAX_ROUNDS:
		_stalemate()
	else:
		_run_round()


# ── Conviction ───────────────────────────────────────────────────────────────

func _fill_conviction(amount: float) -> void:
	conviction = minf(conviction + amount, WIN_THRESHOLD)
	_conviction_bar.value = conviction
	conviction_changed.emit(conviction)


func _drain_conviction(amount: float) -> void:
	conviction = maxf(conviction - amount, 0.0)
	_conviction_bar.value = conviction
	conviction_changed.emit(conviction)


# ── Resolução ────────────────────────────────────────────────────────────────

func _win() -> void:
	_battle_active = false
	_conviction_bar.hide()
	await _show_dialogue([
		{"speaker": "Marcos", "text": "...Tá. Me convenceu.\nÉ isso que vamos apresentar pro cliente."},
	])
	battle_finished.emit()


func _stalemate() -> void:
	# Sem game-over — Marcos encerra inconclusivo, Leo pode tentar de novo
	_battle_active = false
	conviction = 0.0
	current_round = 0
	conviction_changed.emit(conviction)
	await _show_dialogue([
		{"speaker": "Marcos", "text": "Olha, o tempo acabou.\nPrecisa ser mais direto, Leo."},
		{"speaker": "Leo", "text": "...Deixa eu reorganizar.\nVou tentar de novo."},
		{"speaker": "", "text": "[ Apresentação reiniciada. ]"},
	])
	_battle_active = true
	_run_round()


# ── Dados de objeções ────────────────────────────────────────────────────────

func _pick_objection() -> Dictionary:
	var pool := _get_objection_pool()
	return pool[randi() % pool.size()]


func _get_objection_pool() -> Array[Dictionary]:
	# weight = multiplicador de drain (1.0 = normal, 1.5 = pesado)
	return [
		{"text": "Isso não resolve o problema de custo.", "weight": 1.0},
		{"text": "O cliente nunca vai aceitar esse prazo.", "weight": 1.0},
		{"text": "Já tentamos algo parecido no trimestre passado.", "weight": 1.2},
		{"text": "Você tem dados que suportam essa abordagem?", "weight": 1.0},
		{"text": "O board não vai aprovar sem mais detalhes.", "weight": 1.5},
		{"text": "Seu concorrente interno propôs algo mais barato.", "weight": 1.2},
	]


# ── Helpers ──────────────────────────────────────────────────────────────────

func _build_argument_skill() -> Dictionary:
	# Dificuldade cresce levemente por rodada — começa em 2 beats, chega a 4
	var beats: int = clampi(1 + current_round, 2, 4)
	return {"rhythm_beats": beats, "label": "Argumento"}


func _argument_feedback(accuracy: float, perfect: bool) -> String:
	if perfect:
		return "Esse argumento foi sólido.\nEles não têm como refutar."
	elif accuracy >= 0.66:
		return "Bom ponto.\nMarcos está considerando."
	elif accuracy >= 0.33:
		return "Poderia ter sido mais preciso.\nMas serviu."
	else:
		return "...Não foi meu melhor momento."


func _show_dialogue(lines: Array) -> void:
	for line in lines:
		_dialogue_box.show_line(line.get("speaker", ""), line.get("text", ""))
		await _dialogue_box.line_confirmed
	_dialogue_box.hide_box()
