extends Node

# Orquestra o tutorial completo do escritório:
#   INTRO → WORK_TASK_1 → WORK_TASK_2 → PROJECT_SELECT → MARCOS_BATTLE → COMPLETE
#
# Cada etapa ensina uma mecânica sem nomear o que é:
#   - Tasks de trabalho → sistema de ritmo
#   - Seleção de projeto → deck de Animanium
#   - Apresentação para o Marcos → batalha de turno

signal tutorial_stage_changed(stage: TutorialStage)
signal tutorial_complete()

enum TutorialStage {
	INTRO,
	WORK_TASK_1,
	WORK_TASK_2,
	PROJECT_SELECT,
	MARCOS_BATTLE,
	COMPLETE,
}

const NEXT_SCENE := "res://scenes/battle/FirstBattle.tscn"

# Textos narrativos exibidos como diálogo de interface antes de cada tarefa.
# Não usa Dialogic para manter dependência mínima nessa fase.
const TASK_INTRO_TEXTS := {
	TutorialStage.WORK_TASK_1: [
		{"speaker": "Leo", "text": "Mais um relatório de impacto de fenda...\nPreciso focar — o prazo é hoje."},
		{"speaker": "", "text": "[ Pressione o botão no tempo certo para manter o ritmo de trabalho. ]"},
	],
	TutorialStage.WORK_TASK_2: [
		{"speaker": "Leo", "text": "Agora as planilhas de contenção.\nSe eu acertar o ritmo direito, termino antes do almoço."},
		{"speaker": "", "text": "[ Ritmo mais longo desta vez. Não tropece no final. ]"},
	],
	TutorialStage.PROJECT_SELECT: [
		{"speaker": "Leo", "text": "Marcos quer ver três propostas de contenção.\nQual estrutura eu apresento?"},
		{"speaker": "", "text": "[ Escolha um formato de apresentação entre as três opções. ]"},
	],
	TutorialStage.MARCOS_BATTLE: [
		{"speaker": "Marcos", "text": "Leo! Finalmente. Vamos ver o que você trouxe."},
		{"speaker": "", "text": "[ Apresente seus argumentos. Convença Marcos antes que a reunião acabe. ]"},
	],
}

var current_stage: TutorialStage = TutorialStage.INTRO
var _selected_project_shape: Dictionary = {}

# Referências injetadas pelo OfficeDay.tscn
@onready var _dialogue_box: DialogueBox = $"../DialogueBox"
@onready var _rhythm_system: RhythmSystem = $"../RhythmSystem"
@onready var _animanium_ui: AnimaniumSelectUI = $"../AnimaniumSelectUI"
@onready var _presentation_battle: Node = $"../PresentationBattle"


func _ready() -> void:
	GameManager.set_state(GameManager.GameState.CUTSCENE)
	_rhythm_system.rhythm_completed.connect(_on_rhythm_completed)
	_animanium_ui.shape_selected.connect(_on_project_selected)
	_presentation_battle.battle_finished.connect(_on_marcos_defeated)
	_advance_to(TutorialStage.INTRO)


# ── Stage machine ────────────────────────────────────────────────────────────

func _advance_to(stage: TutorialStage) -> void:
	current_stage = stage
	tutorial_stage_changed.emit(stage)
	match stage:
		TutorialStage.INTRO:
			_run_intro()
		TutorialStage.WORK_TASK_1:
			_run_work_task(TutorialStage.WORK_TASK_1)
		TutorialStage.WORK_TASK_2:
			_run_work_task(TutorialStage.WORK_TASK_2)
		TutorialStage.PROJECT_SELECT:
			_run_project_select()
		TutorialStage.MARCOS_BATTLE:
			_run_marcos_battle()
		TutorialStage.COMPLETE:
			_run_complete()


# ── Stages ───────────────────────────────────────────────────────────────────

func _run_intro() -> void:
	var lines := [
		{"speaker": "", "text": "Segunda-feira.\nManhã de sol fraco no décimo-segundo andar."},
		{"speaker": "Leo", "text": "...Que sonho esquisito.\nQuase real demais."},
		{"speaker": "Leo", "text": "Bom, não importa.\nTenho relatórios pra fechar antes das dez."},
	]
	await _show_dialogue(lines)
	_advance_to(TutorialStage.WORK_TASK_1)


func _run_work_task(stage: TutorialStage) -> void:
	var intro_lines: Array = TASK_INTRO_TEXTS[stage]
	await _show_dialogue(intro_lines)
	GameManager.set_state(GameManager.GameState.EXPLORING)
	var task_data := _get_task_data(stage)
	_rhythm_system.start(task_data)


func _run_project_select() -> void:
	await _show_dialogue(TASK_INTRO_TEXTS[TutorialStage.PROJECT_SELECT])
	GameManager.set_state(GameManager.GameState.EXPLORING)
	var shapes := AnimaniumSystem.draw_battle_selection()
	_animanium_ui.show_shapes(shapes)
	_animanium_ui.show()


func _run_marcos_battle() -> void:
	await _show_dialogue(TASK_INTRO_TEXTS[TutorialStage.MARCOS_BATTLE])
	GameManager.set_state(GameManager.GameState.BATTLE)
	_presentation_battle.start(_selected_project_shape)


func _run_complete() -> void:
	GameManager.set_flag("tutorial_complete", true)
	var lines := [
		{"speaker": "Marcos", "text": "...Aprovado. Bom trabalho, Leo.\nVocê foi convincente hoje."},
		{"speaker": "Leo", "text": "..."},
		{"speaker": "Leo", "text": "Aiko?\nVocê estava aqui o tempo todo?"},
		{"speaker": "Aiko", "text": "Aprendi muito sobre o seu mundo.\nDa próxima vez... será diferente."},
		{"speaker": "", "text": "[ Setor 1 desbloqueado. A partir daqui, tudo é real. ]"},
	]
	await _show_dialogue(lines)
	tutorial_complete.emit()
	GameManager.set_state(GameManager.GameState.EXPLORING)
	get_tree().change_scene_to_file(NEXT_SCENE)


# ── Signal handlers ──────────────────────────────────────────────────────────

func _on_rhythm_completed(accuracy: float, _perfect: bool) -> void:
	GameManager.set_state(GameManager.GameState.CUTSCENE)
	var feedback := _rhythm_feedback_line(accuracy)
	await _show_dialogue([{"speaker": "Leo", "text": feedback}])
	match current_stage:
		TutorialStage.WORK_TASK_1:
			_advance_to(TutorialStage.WORK_TASK_2)
		TutorialStage.WORK_TASK_2:
			_advance_to(TutorialStage.PROJECT_SELECT)


func _on_project_selected(shape: Dictionary) -> void:
	_selected_project_shape = shape
	_animanium_ui.hide()
	GameManager.set_state(GameManager.GameState.CUTSCENE)
	var lines := [
		{"speaker": "Leo", "text": "Esse formato.\nÉ o que vai convencer o Marcos."},
	]
	await _show_dialogue(lines)
	_advance_to(TutorialStage.MARCOS_BATTLE)


func _on_marcos_defeated() -> void:
	_advance_to(TutorialStage.COMPLETE)


# ── Helpers ──────────────────────────────────────────────────────────────────

func _get_task_data(stage: TutorialStage) -> Dictionary:
	match stage:
		TutorialStage.WORK_TASK_1:
			return {"rhythm_beats": 2, "label": "Relatório de Impacto"}
		TutorialStage.WORK_TASK_2:
			return {"rhythm_beats": 3, "label": "Planilha de Contenção"}
	return {"rhythm_beats": 2, "label": "Tarefa"}


func _rhythm_feedback_line(accuracy: float) -> String:
	if accuracy >= 1.0:
		return "Perfeito.\nToda palavra no lugar certo."
	elif accuracy >= 0.66:
		return "Quase lá.\nBom o suficiente por hoje."
	elif accuracy >= 0.33:
		return "Poderia ter sido melhor.\nMas está feito."
	else:
		return "Droga...\nMelhor revisar antes de mandar."


# Exibe sequência de falas e aguarda confirmação do jogador.
func _show_dialogue(lines: Array) -> void:
	for line in lines:
		_dialogue_box.show_line(line.get("speaker", ""), line.get("text", ""))
		await _dialogue_box.line_confirmed
	_dialogue_box.hide_box()
