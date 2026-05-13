class_name DialogueBox
extends Control

# Caixa de diálogo in-game: speaker + texto typewriter + aguarda confirmação.
# Usada pelo TutorialManager e PresentationBattle para falas narrativas.

signal line_confirmed()

const TYPEWRITER_SPEED := 0.03   # segundos por caractere

@onready var _speaker_label: Label = $Panel/Margin/VBox/Speaker
@onready var _text_label: RichTextLabel = $Panel/Margin/VBox/Text
@onready var _continue_hint: Label = $ContinueHint

var _typewriter_active: bool = false
var _full_text: String = ""


func _ready() -> void:
	hide()
	set_process_input(false)


func show_line(speaker: String, text: String) -> void:
	_speaker_label.text = speaker
	_speaker_label.visible = speaker.length() > 0
	_text_label.text = ""
	_continue_hint.hide()
	show()
	set_process_input(true)
	_full_text = text
	_typewriter_active = true
	await _run_typewriter(text)
	_typewriter_active = false
	_continue_hint.show()


func hide_box() -> void:
	hide()
	set_process_input(false)


func _run_typewriter(text: String) -> void:
	for i in text.length():
		if not _typewriter_active:
			_text_label.text = text
			return
		_text_label.text = text.substr(0, i + 1)
		await get_tree().create_timer(TYPEWRITER_SPEED).timeout


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("confirm") or event.is_action_pressed("ui_accept"):
		if _typewriter_active:
			_typewriter_active = false
			_text_label.text = _full_text
		elif not _typewriter_active:
			set_process_input(false)
			line_confirmed.emit()
