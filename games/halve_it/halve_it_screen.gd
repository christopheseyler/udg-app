class_name HalveItScreen
extends GameScreen

## Ecran de jeu du Halve It, base sur le template GameScreen. Chaque round est
## associe a une cible commune a tous les joueurs (voir NINE_ROUNDS_TARGETS et
## EXTENDED_TARGETS) ; le panneau de score (HalveItScorePanel) affiche la
## cible du round en cours et la liste des joueurs avec leur score.
##
## A la fin de son tour (3 fleches, ou Next player), le joueur touchant la
## cible avec au moins une fleche gagne la somme (valeur x multiplicateur) de
## toutes les fleches qui la touchent ; s'il ne touche la cible avec aucune de
## ses fleches, son score est divise par deux (arrondi a l'entier inferieur).
## Comme dans X01, rien n'est jamais modifie fleche par fleche : le tour en
## cours est recalcule a chaque jet a partir de l'instantane pris a son debut
## (_turn_start_score), et chaque tour termine garde son propre instantane
## dans _turn_history, ce qui permet a Cancel hit de remonter tour par tour
## sans limite jusqu'au debut de la partie.
##
## A la fin du dernier round, le(s) joueur(s) au score le plus eleve gagnent ;
## en cas d'egalite, tous les noms sont annonces ensemble.

const NINE_ROUNDS_TARGETS: Array[Dictionary] = [
	{"type": "number", "value": 15}, {"type": "number", "value": 16}, {"type": "number", "value": 17},
	{"type": "double"}, {"type": "number", "value": 18}, {"type": "number", "value": 19}, {"type": "number", "value": 20},
	{"type": "triple"}, {"type": "bull"},
]

const EXTENDED_TARGETS: Array[Dictionary] = [
	{"type": "number", "value": 12}, {"type": "number", "value": 13}, {"type": "number", "value": 14},
	{"type": "double"}, {"type": "number", "value": 15}, {"type": "number", "value": 16}, {"type": "number", "value": 17},
	{"type": "triple"}, {"type": "number", "value": 18}, {"type": "number", "value": 19}, {"type": "number", "value": 20},
	{"type": "bull"},
]

@onready var score_panel: HalveItScorePanel = $ScoreArea/ScorePanel

var _players: Array[String] = []
var _scores: Array[int] = []
var _targets: Array[Dictionary] = []
var _current_player := 0

## Fleches du tour en cours (parallele a GameScreen._throws, mais avec les
## DartHit complets necessaires au calcul du score).
var _turn_hits: Array[DartHit] = []
## Score du joueur courant au debut de son tour en cours : instantane que le
## tour recalcule toujours a partir de, jamais de l'etat courant.
var _turn_start_score := 0
## Tours termines, dans l'ordre (parallele a GameScreen._history) : permet a
## Cancel hit de revenir au tour precedent avec son instantane de depart
## exact (score et round).
var _turn_history: Array[Dictionary] = []
## Vrai des que _finalize_turn() a ete applique au tour en cours (voir
## _start_remove_darts) : le score affiche cesse alors de suivre les fleches
## une a une et reste sur le resultat final jusqu'au tour suivant.
var _turn_finalized := false

func _ready() -> void:
	super._ready()
	next_player_requested.connect(_on_next_player_requested)
	previous_player_requested.connect(_on_previous_player_requested)
	throw_cancelled.connect(_on_throw_cancelled)

func setup(players: Array[String], options: Dictionary) -> void:
	_players = players.duplicate()
	_targets = EXTENDED_TARGETS if options.get("game_mode", "9 Rounds") == "Extended" else NINE_ROUNDS_TARGETS
	var starting_score := int(options.get("starting_score", "0"))

	_scores.clear()
	for _player in _players:
		_scores.append(starting_score)
	_current_player = 0
	darts_per_turn = 3
	set_round(1)
	reset_turn()
	clear_history()

	_turn_history.clear()
	_turn_hits.clear()
	_turn_start_score = _scores[_current_player]
	_turn_finalized = false

	score_panel.set_players(_players)
	score_panel.set_target(_target_label(_current_target()))
	for i in _players.size():
		_refresh_row(i)
	score_panel.set_current_player(_current_player)

## Jet detecte : ajoute le jet au tour en cours et rafraichit l'aperçu du
## score (la valeur n'est appliquee qu'a la fin du tour, voir
## _finalize_turn).
func _on_dart_hit(hit: DartHit) -> void:
	if _game_over or confirm_overlay.visible or remove_darts_screen.visible:
		return
	if get_remaining_darts() <= 0:
		return

	_turn_hits.append(hit)
	add_throw(hit, _hit_matches_target(hit, _current_target()))
	_refresh_row(_current_player)

## Declenchement de l'ecran "Remove your darts" (3e fleche du tour, ou
## bouton Next player appuye plus tot) : applique le resultat du tour et
## rafraichit l'affichage AVANT que l'ecran ne s'affiche, pour que le score
## divise par deux (ou augmente) soit deja visible pendant que le joueur
## retire ses fleches, plutot qu'apres.
func _start_remove_darts() -> void:
	if not _turn_finalized:
		_finalize_turn()
		_turn_finalized = true
		_refresh_row(_current_player)
	super._start_remove_darts()

func _on_next_player_requested() -> void:
	if _players.is_empty():
		return
	_turn_history.append(_capture_turn_history_entry())
	_advance_and_start_turn()

## Applique le resultat du tour du joueur courant : la somme des fleches qui
## touchent la cible si au moins une la touche, sinon le score est divise par
## deux (arrondi a l'entier inferieur, jamais negatif puisque les scores le
## sont deja). Appele des que le tour se termine (voir _start_remove_darts),
## avant l'ecran "Remove your darts".
func _finalize_turn() -> void:
	var gained := _turn_gained()
	_scores[_current_player] = _turn_start_score + gained if gained > 0 else _turn_start_score / 2

## Avance au joueur suivant (et gere le nombre de rounds), puis prepare son
## tour. Termine la partie une fois la cible du dernier round jouee par tous
## les joueurs.
func _advance_and_start_turn() -> void:
	_current_player = (_current_player + 1) % _players.size()
	if _current_player == 0:
		set_round(round_number + 1)

	if round_number > _targets.size():
		_announce_result()
		return

	_turn_hits = []
	_turn_start_score = _scores[_current_player]
	_turn_finalized = false
	score_panel.set_target(_target_label(_current_target()))
	score_panel.set_current_player(_current_player)
	for i in _players.size():
		_refresh_row(i)

## Revient au tour du joueur precedent (Cancel hit avec le tour courant
## vide) : restaure son instantane de depart (score et round), ses jets sont
## ensuite retires un a un par les appels suivants a throw_cancelled.
func _on_previous_player_requested() -> void:
	if _players.is_empty() or _turn_history.is_empty():
		return
	var entry: Dictionary = _turn_history.pop_back()

	_current_player = entry.player
	_scores[_current_player] = entry.start_score
	set_round(entry.round)
	_turn_start_score = entry.start_score
	_turn_hits = entry.hits.duplicate()
	_turn_finalized = false

	score_panel.set_target(_target_label(_current_target()))
	score_panel.set_current_player(_current_player)
	for i in _players.size():
		_refresh_row(i)

func _on_throw_cancelled() -> void:
	if _turn_hits.is_empty():
		return
	_turn_hits.pop_back()
	_refresh_row(_current_player)

func _capture_turn_history_entry() -> Dictionary:
	return {
		"player": _current_player,
		"hits": _turn_hits.duplicate(),
		"start_score": _turn_start_score,
		"round": round_number,
	}

func _current_target() -> Dictionary:
	return _targets[round_number - 1]

func _hit_matches_target(hit: DartHit, target: Dictionary) -> bool:
	if hit.is_miss():
		return false
	match target.type:
		"number": return hit.segment == target.value
		"double": return hit.is_double()
		"triple": return hit.is_triple()
		"bull": return hit.segment == DartHit.BULL
		_: return false

func _target_label(target: Dictionary) -> String:
	match target.type:
		"number": return str(target.value)
		"double": return "Any Double"
		"triple": return "Any Triple"
		"bull": return "Bullseye"
		_: return ""

## Somme deja acquise ce tour par le joueur courant (fleches du tour qui
## touchent la cible en cours). Ne prejuge jamais du "score halved" : tant
## que le tour n'est pas termine, une fleche ratee peut encore etre suivie
## d'une fleche qui touche la cible.
func _turn_gained() -> int:
	var target := _current_target()
	var gained := 0
	for hit in _turn_hits:
		if _hit_matches_target(hit, target):
			gained += hit.get_score()
	return gained

## Texte d'aide affiche pour le joueur courant : somme deja acquise ce tour,
## ou rappel que rater la cible avec toutes ses fleches divise le score par
## deux.
func _hint_for(index: int) -> String:
	if index != _current_player or _game_over:
		return ""
	var gained := _turn_gained()
	return "+%d this turn" % gained if gained > 0 else "Miss = score halved"

## Score affiche pour un joueur : pour le joueur courant, le score courant
## est mis a jour a chaque fleche avec ce qu'elle a deja rapporte ce tour
## (jamais la division par deux, qui n'est decidee qu'a la fin du tour, voir
## _finalize_turn) ; pour les autres, leur score enregistre.
func _display_score(index: int) -> int:
	if index == _current_player and not _game_over and not _turn_finalized:
		return _turn_start_score + _turn_gained()
	return _scores[index]

func _refresh_row(index: int) -> void:
	score_panel.set_row(index, _display_score(index), _hint_for(index))

## Termine la partie : le(s) joueur(s) au score le plus eleve gagnent (tous
## annonces ensemble en cas d'egalite).
func _announce_result() -> void:
	var best: int = _scores.max()
	var winners := PackedStringArray()
	for i in _players.size():
		if _scores[i] == best:
			winners.append(_players[i])
	announce_winner(" & ".join(winners))
	# _game_over est maintenant vrai (voir GameScreen.announce_winner) : chaque
	# ligne affiche son score enregistre, plus de previsualisation en cours.
	for i in _players.size():
		_refresh_row(i)
