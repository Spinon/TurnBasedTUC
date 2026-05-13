class_name AnimaniumSelectUI
extends Control

# Seletor de formas do Animanium — exibe 3 opções e aguarda a escolha do jogador.
# No tutorial é apresentado como "escolha de projeto"; no combate real, como deck.
# Placeholder: botões de texto. Trocar por ShapeButton com preview gráfico depois.

signal shape_selected(shape: Dictionary)

@onready var _title_label: Label = $Container/Title
@onready var _shape_buttons: Array = [
	$Container/ShapeButtons/Shape0,
	$Container/ShapeButtons/Shape1,
	$Container/ShapeButtons/Shape2,
]

var _shapes: Array[Dictionary] = []
var _focused_index: int = 0


func _ready() -> void:
	hide()
	set_process_input(false)
	for i in _shape_buttons.size():
		_shape_buttons[i].pressed.connect(_on_shape_pressed.bind(i))


# Recebe array de 3 shape dicts do AnimaniumSystem.draw_battle_selection().
func show_shapes(shapes: Array, title := "Qual formato?") -> void:
	_shapes = shapes
	_title_label.text = title
	for i in _shape_buttons.size():
		var btn: Button = _shape_buttons[i]
		if i < shapes.size():
			var shape: Dictionary = shapes[i]
			btn.text = shape.get("name", shape.get("id", "???"))
			btn.tooltip_text = shape.get("description", "")
			btn.visible = true
		else:
			btn.visible = false
	show()
	set_process_input(true)
	if _shape_buttons[0].visible:
		_shape_buttons[0].grab_focus()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	# Navegação por controle (d-pad horizontal)
	if event.is_action_pressed("ui_right"):
		_move_focus(1)
	elif event.is_action_pressed("ui_left"):
		_move_focus(-1)


func _move_focus(direction: int) -> void:
	_focused_index = (_focused_index + direction) % _shapes.size()
	if _focused_index < 0:
		_focused_index += _shapes.size()
	_shape_buttons[_focused_index].grab_focus()


func _on_shape_pressed(index: int) -> void:
	if index >= _shapes.size():
		return
	set_process_input(false)
	hide()
	shape_selected.emit(_shapes[index])
