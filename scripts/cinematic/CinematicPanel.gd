class_name CinematicPanel
extends Control

# Sistema de painéis ilustrados para cinemáticas e transições narrativas.
# Cada painel = fundo + texto narrado + efeitos atmosféricos.
# Arte é um placeholder substituível — o sistema funciona com cores/gradientes até ter sprites reais.

signal panel_finished()
signal sequence_finished()

const TYPEWRITER_SPEED := 0.04    # segundos por caractere
const PANEL_FADE_TIME := 0.6
const AUTO_ADVANCE_DELAY := 1.2   # segundos após texto completo antes de avançar (se auto)

@onready var _background: ColorRect = $Background
@onready var _illustration: TextureRect = $Illustration      # placeholder até ter arte
@onready var _overlay: ColorRect = $Overlay                  # fade preto
@onready var _text_box: PanelContainer = $TextBox
@onready var _text_label: RichTextLabel = $TextBox/VBox/Text
@onready var _speaker_label: Label = $TextBox/VBox/Speaker
@onready var _continue_hint: Label = $ContinueHint          # "▶ continuar"
@onready var _particles: CPUParticles2D = $AtmosphereParticles

var _panels: Array[Dictionary] = []
var _current_index: int = 0
var _typewriter_active: bool = false
var _text_complete: bool = false
var _auto_advance: bool = false
var _tween: Tween


func _ready() -> void:
	_overlay.color = Color.BLACK
	_continue_hint.hide()
	set_process_input(true)


# Inicia uma sequência de painéis.
# Cada panel dict: { "bg_color", "text", "speaker", "texture" (opcional),
#                   "particles" (opcional), "auto" (bool), "duration" (se auto) }
func play_sequence(panels: Array[Dictionary], auto_advance := false) -> void:
	_panels = panels
	_current_index = 0
	_auto_advance = auto_advance
	_show_panel(_panels[0])


func _show_panel(panel: Dictionary) -> void:
	_text_complete = false
	_continue_hint.hide()

	# Fundo
	var bg: Color = panel.get("bg_color", Color(0.05, 0.05, 0.1))
	_background.color = bg

	# Ilustração (placeholder = sem textura mostra só a cor)
	var tex: Texture2D = panel.get("texture", null)
	_illustration.texture = tex
	_illustration.visible = tex != null

	# Partículas atmosféricas
	var particle_preset: String = panel.get("particles", "")
	_set_particles(particle_preset)

	# Texto e speaker
	var speaker: String = panel.get("speaker", "")
	_speaker_label.text = speaker
	_speaker_label.visible = speaker.length() > 0
	_text_label.text = ""

	# Fade in
	_overlay.color = Color.BLACK
	_tween = create_tween()
	_tween.tween_property(_overlay, "modulate:a", 0.0, PANEL_FADE_TIME)
	await _tween.finished

	# Typewriter
	_typewriter_active = true
	var full_text: String = panel.get("text", "")
	await _run_typewriter(full_text)
	_typewriter_active = false
	_text_complete = true

	if _auto_advance or panel.get("auto", false):
		var duration: float = panel.get("duration", AUTO_ADVANCE_DELAY)
		await get_tree().create_timer(duration).timeout
		_advance()
	else:
		_continue_hint.show()


func _run_typewriter(text: String) -> void:
	for i in text.length():
		_text_label.text = text.substr(0, i + 1)
		await get_tree().create_timer(TYPEWRITER_SPEED).timeout
		if not _typewriter_active:   # skip se jogador adiantou
			_text_label.text = text
			return


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("confirm") or event.is_action_pressed("ui_accept"):
		if _typewriter_active:
			# Primeiro toque: mostra texto completo imediatamente
			_typewriter_active = false
		elif _text_complete and not _auto_advance:
			_advance()


func _advance() -> void:
	panel_finished.emit()
	_current_index += 1
	if _current_index >= _panels.size():
		_finish_sequence()
		return
	# Fade out antes do próximo painel
	_tween = create_tween()
	_tween.tween_property(_overlay, "modulate:a", 1.0, PANEL_FADE_TIME)
	await _tween.finished
	_show_panel(_panels[_current_index])


func _finish_sequence() -> void:
	_tween = create_tween()
	_tween.tween_property(_overlay, "modulate:a", 1.0, PANEL_FADE_TIME)
	await _tween.finished
	sequence_finished.emit()


func _set_particles(preset: String) -> void:
	match preset:
		"fog":
			_particles.emitting = true
			_particles.modulate = Color(0.7, 0.8, 1.0, 0.3)
		"sparks":
			_particles.emitting = true
			_particles.modulate = Color(0.9, 0.95, 1.0, 0.6)
		"":
			_particles.emitting = false
		_:
			_particles.emitting = false
