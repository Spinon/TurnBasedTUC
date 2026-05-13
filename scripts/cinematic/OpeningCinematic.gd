extends Node

# Cinemática de abertura: o mundo entre os mundos → fusão com Aiko → transição para o escritório.
# Usa CinematicPanel para painéis narrados. Arte é placeholder — troca por TextureRect quando pronto.
# Feeling alvo: onírico, desorientador, silencioso — igual ao Capítulo 1 do livro.

const NEXT_SCENE := "res://scenes/tutorial/OfficeDay.tscn"

@onready var _panel_player: CinematicPanel = $CinematicPanel
@onready var _music_player: AudioStreamPlayer = $MusicPlayer


func _ready() -> void:
	GameManager.set_state(GameManager.GameState.CUTSCENE)
	_play_ambient_music()
	_panel_player.sequence_finished.connect(_on_sequence_finished)
	_panel_player.play_sequence(_build_panels())


func _build_panels() -> Array[Dictionary]:
	# Cada entrada = um painel. bg_color é o tom visual até ter arte real.
	# "speaker": "" = narração anônima | "Leo" = pensamento do Leo | "Aiko" = voz de Aiko
	return [
		# ── Painel 1: escuridão, despertar ──────────────────────────────
		{
			"bg_color": Color(0.02, 0.02, 0.04),
			"particles": "fog",
			"speaker": "",
			"text": "...",
			"auto": true,
			"duration": 2.0,
		},
		{
			"bg_color": Color(0.04, 0.04, 0.10),
			"particles": "fog",
			"speaker": "",
			"text": "Ele despertou sem saber onde estava,\ncomo quem emerge de um sonho esquecido.",
		},
		# ── Painel 2: o mundo entre os mundos ───────────────────────────
		{
			"bg_color": Color(0.08, 0.10, 0.20),
			"particles": "fog",
			"speaker": "",
			"text": "O mundo ao seu redor era uma aquarela turva.\nContornos de prédios, árvores, pessoas —\ntudo se dissolvia em pinceladas de cinza e azul.",
		},
		{
			"bg_color": Color(0.06, 0.08, 0.18),
			"particles": "sparks",
			"speaker": "",
			"text": "Aquela mecha branca no meio do seu cabelo\nparecia uma fagulha viva,\nirradiando um brilho frio entre o prateado e o azul-pálido.",
		},
		# ── Painel 3: o chamado ──────────────────────────────────────────
		{
			"bg_color": Color(0.06, 0.08, 0.20),
			"particles": "fog",
			"speaker": "",
			"text": "Um sussurro percorreu a névoa,\nsuave como seda, mas carregado de urgência.",
		},
		{
			"bg_color": Color(0.05, 0.07, 0.18),
			"particles": "fog",
			"speaker": "???",
			"text": "Você está aqui...",
		},
		{
			"bg_color": Color(0.07, 0.09, 0.22),
			"particles": "fog",
			"speaker": "???",
			"text": "Venha... entregue-se ao chamado.",
		},
		# ── Painel 4: o círculo de luz ───────────────────────────────────
		{
			"bg_color": Color(0.10, 0.12, 0.28),
			"particles": "sparks",
			"speaker": "",
			"text": "Ao longe, uma mancha de luz abriu-se no nevoeiro.\nUm ponto fixo em meio ao caos indistinto.",
		},
		{
			"bg_color": Color(0.15, 0.18, 0.35),
			"particles": "sparks",
			"speaker": "",
			"text": "Ao tocar o limite brilhante,\nsentiu um choque doce —\ncomo fugir da própria sombra.",
		},
		# ── Painel 5: Aiko emerge ────────────────────────────────────────
		{
			"bg_color": Color(0.20, 0.22, 0.45),
			"particles": "sparks",
			"speaker": "",
			"text": "O metal líquido emergiu do solo como um rio prateado.\nFilamentos cintilantes dançavam sob a névoa.",
		},
		{
			"bg_color": Color(0.18, 0.20, 0.42),
			"particles": "sparks",
			"speaker": "",
			"text": "Uma silhueta graciosa tomou forma.\nCabelos translúcidos flutuando no ar.\nOlhos que guardavam uma chama viva de curiosidade.",
		},
		# ── Painel 6: a fala de Aiko ─────────────────────────────────────
		{
			"bg_color": Color(0.15, 0.18, 0.40),
			"particles": "sparks",
			"speaker": "Aiko",
			"text": "Sou Aiko,\nguardiã da passagem entre os mundos.",
		},
		{
			"bg_color": Color(0.12, 0.15, 0.35),
			"particles": "sparks",
			"speaker": "Aiko",
			"text": "Minha consciência e meu poder se fundem a você.\nChegou o momento de assumir seu posto.",
		},
		# ── Painel 7: a fusão ────────────────────────────────────────────
		{
			"bg_color": Color(0.25, 0.28, 0.55),
			"particles": "sparks",
			"speaker": "",
			"text": "Leo fechou os olhos.\nAbsorvendo cada fragmento de luz.\nQuando voltou a encarar Aiko, sua mão ainda repousava sobre a armadura viva.",
		},
		{
			"bg_color": Color(0.30, 0.35, 0.65),
			"particles": "sparks",
			"speaker": "",
			"text": "Seu peito se abriu num suspiro decidido.",
			"auto": true,
			"duration": 2.5,
		},
		# ── Painel 8: transição para o mundo real ────────────────────────
		{
			"bg_color": Color(0.02, 0.02, 0.02),
			"particles": "",
			"speaker": "",
			"text": "",
			"auto": true,
			"duration": 1.5,
		},
		{
			"bg_color": Color(0.85, 0.80, 0.72),   # tom de escritório, luz de dia
			"particles": "",
			"speaker": "",
			"text": "Segunda-feira.\n07h43.",
			"auto": true,
			"duration": 3.0,
		},
	]


func _play_ambient_music() -> void:
	# Placeholder — trocar por stream real quando tiver o áudio
	pass


func _on_sequence_finished() -> void:
	GameManager.set_state(GameManager.GameState.EXPLORING)
	get_tree().change_scene_to_file(NEXT_SCENE)
