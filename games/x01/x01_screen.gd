class_name X01Screen
extends GameScreen

## Ecran de jeu du X01, base sur le template GameScreen. Le panneau de score
## (X01ScorePanel) liste les joueurs avec leur score et ce qu'ils doivent
## faire ; le joueur en cours est en surbrillance et passe au suivant avec
## le bouton Next player. Options lues : start_value, in_condition,
## out_condition (voir x01_game.gd).

## Score maximal terminable en une fleche selon la condition de sortie : en
## dessous, le joueur voit ce qu'il doit faire pour finir.
const MAX_FINISH := {"None": 60, "Double": 40, "Triple": 60, "Master": 60}

@onready var score_panel: X01ScorePanel = $ScoreArea/ScorePanel

var _players: Array[String] = []
var _scores: Array[int] = []
var _entered: Array[bool] = []
var _current_player := 0
var _in_condition := "None"
var _out_condition := "Double"

func _ready() -> void:
	super._ready()
	next_player_requested.connect(_on_next_player_requested)

func setup(players: Array[String], options: Dictionary) -> void:
	_players = players.duplicate()
	_in_condition = options.get("in_condition", "None")
	_out_condition = options.get("out_condition", "Double")
	var start_value := int(options.get("start_value", "501"))

	_scores.clear()
	_entered.clear()
	for _player in _players:
		_scores.append(start_value)
		_entered.append(_in_condition == "None")
	_current_player = 0
	set_round(1)

	score_panel.set_players(_players)
	for i in _players.size():
		_refresh_row(i)
	score_panel.set_current_player(_current_player)

func _on_next_player_requested() -> void:
	if _players.is_empty():
		return
	_current_player = (_current_player + 1) % _players.size()
	if _current_player == 0:
		set_round(round_number + 1)
	score_panel.set_current_player(_current_player)

func _refresh_row(index: int) -> void:
	score_panel.set_row(index, _scores[index], _hint_for(index))

## Texte d'aide du joueur : condition d'entree tant qu'il n'est pas entre dans
## la partie, puis condition de sortie quand son score devient terminable.
func _hint_for(index: int) -> String:
	if not _entered[index]:
		return "Need a %s to enter" % _in_condition.to_lower()
	if _scores[index] > MAX_FINISH[_out_condition]:
		return ""
	if _out_condition == "None":
		return "Need %d to finish" % _scores[index]
	return "Need a %s to finish" % _out_condition.to_lower()
