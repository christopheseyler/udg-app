class_name X01Screen
extends GameScreen

## Ecran de jeu du X01, base sur le template GameScreen. Le panneau de score
## (X01ScorePanel) liste les joueurs avec leur score et ce qu'ils doivent
## faire ; le joueur en cours est en surbrillance et passe au suivant avec
## le bouton Next player. Options lues : start_value, in_condition,
## out_condition (voir x01_game.gd).
##
## Decompte : tant que le joueur n'est pas entre (condition in_condition),
## ses jets ne comptent pas. Un bust (score negatif, score a 0 sans
## satisfaire out_condition, ou score a 1 alors que out_condition exige un
## double/triple) annule tout le tour : le score (et l'entree) revient a ce
## qu'il etait au debut du tour, qui se termine aussitot. Le score de chaque
## joueur est recalcule a partir des jets de son tour en cours (voir
## _replay_turn) : ceci permet a Cancel hit d'annuler les jets un a un, y
## compris ceux d'un tour deja termine (voir _on_previous_player_requested).
## Un score exactement a 0 en respectant out_condition gagne la partie.
## Au-dela de max_rounds, la partie s'arrete sans vainqueur.

## Score maximal terminable en une fleche selon la condition de sortie : en
## dessous, le joueur voit ce qu'il doit faire pour finir.
const MAX_FINISH := {"None": 60, "Double": 40, "Triple": 60, "Master": 60}

## Nombre de rounds (cycles complets de tous les joueurs) au-dela duquel la
## partie s'arrete sans vainqueur, pour eviter une partie infinie.
@export var max_rounds: int = 50

@onready var score_panel: X01ScorePanel = $ScoreArea/ScorePanel

var _players: Array[String] = []
var _scores: Array[int] = []
var _entered: Array[bool] = []
var _current_player := 0
var _in_condition := "None"
var _out_condition := "Double"

## Jets du tour en cours (parallele a GameScreen._throws, mais avec les
## DartHit complets necessaires au calcul du score).
var _turn_hits: Array[DartHit] = []
var _turn_start_score := 0
var _turn_start_entered := false
## Tours termines, dans l'ordre (parallele a GameScreen._history) : permet a
## Cancel hit de revenir au tour precedent avec son etat de depart exact.
var _turn_history: Array[Dictionary] = []

func _ready() -> void:
	super._ready()
	next_player_requested.connect(_on_next_player_requested)
	previous_player_requested.connect(_on_previous_player_requested)
	throw_cancelled.connect(_on_throw_cancelled)

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
	reset_turn()
	clear_history()

	_turn_history.clear()
	_turn_hits.clear()
	_turn_start_score = start_value
	_turn_start_entered = _in_condition == "None"

	score_panel.set_players(_players)
	for i in _players.size():
		_refresh_row(i)
	score_panel.set_current_player(_current_player)

## Jet detecte : applique les regles du X01 au joueur courant, puis affiche
## le jet comme d'habitude. Termine le tour aussitot sur un bust ; declare la
## victoire aussitot sur un score a 0 valide.
func _on_dart_hit(hit: DartHit) -> void:
	if _game_over or confirm_overlay.visible or remove_darts_screen.visible:
		return
	if get_remaining_darts() <= 0:
		return

	_turn_hits.append(hit)
	var result := _apply_turn_state()
	add_throw(hit.get_label())

	if result.finished:
		announce_winner(_players[_current_player])
	elif result.busted:
		_start_remove_darts()

func _on_next_player_requested() -> void:
	if _players.is_empty():
		return
	_turn_history.append({
		"player": _current_player,
		"hits": _turn_hits.duplicate(),
		"start_score": _turn_start_score,
		"start_entered": _turn_start_entered,
	})

	_current_player = (_current_player + 1) % _players.size()
	if _current_player == 0:
		set_round(round_number + 1)
		if round_number > max_rounds:
			end_game("X01: max rounds reached, game over with no winner")
			return

	_turn_hits = []
	_turn_start_score = _scores[_current_player]
	_turn_start_entered = _entered[_current_player]
	score_panel.set_current_player(_current_player)

## Revient au tour du joueur precedent (Cancel hit avec le tour courant
## vide) : restaure son etat de debut de tour et ses jets, qui seront
## retires un a un par les appels suivants a throw_cancelled.
func _on_previous_player_requested() -> void:
	if _players.is_empty() or _turn_history.is_empty():
		return
	var entry: Dictionary = _turn_history.pop_back()
	if _current_player == 0:
		set_round(round_number - 1)

	_current_player = entry.player
	_turn_start_score = entry.start_score
	_turn_start_entered = entry.start_entered
	_turn_hits = entry.hits.duplicate()
	_apply_turn_state()
	score_panel.set_current_player(_current_player)

func _on_throw_cancelled(_value: String) -> void:
	if _turn_hits.is_empty():
		return
	_turn_hits.pop_back()
	_apply_turn_state()

## Recalcule le score et l'etat "entre" du joueur courant a partir des jets
## de son tour en cours, et met a jour l'affichage. Rejouer depuis le debut
## du tour (plutot que d'ajuster le score jet par jet) rend Cancel hit
## trivial a implementer correctement, y compris a travers un bust.
func _apply_turn_state() -> Dictionary:
	var result := _replay_turn(_turn_start_score, _turn_start_entered, _turn_hits)
	_scores[_current_player] = result.score
	_entered[_current_player] = result.entered
	_refresh_row(_current_player)
	return result

## Rejoue une suite de jets depuis le score et l'etat "entre" de debut de
## tour. S'arrete des qu'un jet gagne la partie (score a 0 valide) ou fait
## un bust (score et entree reviennent alors a ce qu'ils etaient au debut du
## tour, comme si le tour n'avait pas eu lieu).
func _replay_turn(start_score: int, start_entered: bool, hits: Array[DartHit]) -> Dictionary:
	var score := start_score
	var entered := start_entered
	var busted := false
	var finished := false

	for hit in hits:
		if not entered:
			if not _satisfies_in(hit):
				continue
			entered = true

		var new_score := score - hit.get_score()
		if _is_bust(new_score, hit):
			score = start_score
			entered = start_entered
			busted = true
			break

		score = new_score
		if score == 0:
			finished = true
			break

	return {"score": score, "entered": entered, "busted": busted, "finished": finished}

func _satisfies_in(hit: DartHit) -> bool:
	match _in_condition:
		"Double": return hit.is_double()
		"Triple": return hit.is_triple()
		"Master": return hit.is_master()
		_: return true

func _satisfies_out(hit: DartHit) -> bool:
	match _out_condition:
		"Double": return hit.is_double()
		"Triple": return hit.is_triple()
		"Master": return hit.is_master()
		_: return true

## Un score negatif, un score a 0 sans respecter out_condition, ou un score a
## 1 alors que out_condition exige un double ou un triple (aucun ne vaut 1)
## sont des bust.
func _is_bust(new_score: int, hit: DartHit) -> bool:
	if new_score < 0:
		return true
	if new_score == 0:
		return not _satisfies_out(hit)
	if new_score == 1 and _out_condition != "None":
		return true
	return false

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
