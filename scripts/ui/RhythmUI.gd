class_name RhythmUI
extends Control

# Visualizador do sistema de ritmo.
# Mostra indicadores de beat que acendem na hora certa e ficam verde/vermelho conforme o acerto.
# Auto-conecta ao RhythmSystem irmão na cena pai.

const COLOR_PENDING := Color(0.30, 0.30, 0.60, 1.0)
const COLOR_ACTIVE  := Color(0.85, 0.85, 1.00, 1.0)
const COLOR_HIT     := Color(0.20, 0.90, 0.40, 1.0)
const COLOR_MISS    := Color(0.90, 0.20, 0.20, 1.0)

const BEAT_SIZE := Vector2(48, 48)
const BEAT_SPACING := 12

@onready var _beat_container: HBoxContainer = $VBox/BeatContainer
@onready var _task_label: Label = $VBox/TaskLabel

var _beat_rects: Array[ColorRect] = []
var _connected := false


func _ready() -> void:
	hide()
	# Auto-connect ao RhythmSystem que vive como irmão no pai desta cena
	await get_tree().process_frame   # espera o pai resolver @onreadys
	var rhythm: RhythmSystem = get_parent().get_node_or_null("RhythmSystem")
	if rhythm:
		rhythm.beat_spawned.connect(_on_beat_spawned)
		rhythm.beat_resolved.connect(_on_beat_resolved)
		rhythm.rhythm_completed.connect(_on_rhythm_completed)
		_connected = true


# Chamado externamente para rotular a tarefa atual (opcional).
func set_task_label(text: String) -> void:
	_task_label.text = text


func _setup_beats(total: int) -> void:
	_beat_rects.clear()
	for child in _beat_container.get_children():
		child.queue_free()
	for _i in total:
		var rect := ColorRect.new()
		rect.custom_minimum_size = BEAT_SIZE
		rect.color = COLOR_PENDING
		_beat_container.add_child(rect)
		_beat_rects.append(rect)
	show()


# ── Signal handlers ──────────────────────────────────────────────────────────

func _on_beat_spawned(beat_index: int, total_beats: int) -> void:
	if beat_index == 0:
		_setup_beats(total_beats)
	if beat_index < _beat_rects.size():
		_beat_rects[beat_index].color = COLOR_ACTIVE


func _on_beat_resolved(beat_index: int, result: RhythmSystem.BeatResult) -> void:
	if beat_index >= _beat_rects.size():
		return
	match result:
		RhythmSystem.BeatResult.HIT:
			_beat_rects[beat_index].color = COLOR_HIT
		RhythmSystem.BeatResult.MISS:
			_beat_rects[beat_index].color = COLOR_MISS


func _on_rhythm_completed(_accuracy: float, _perfect: bool) -> void:
	# Mantém os indicadores visíveis brevemente para o jogador ver o resultado
	await get_tree().create_timer(0.8).timeout
	hide()
