class_name X01Screen
extends GameScreen

## Ecran de jeu du X01, base sur le template GameScreen. Le panneau de score
## (X01ScorePanel) liste les joueurs avec leur score et ce qu'ils doivent
## faire ; le joueur en cours est en surbrillance et passe au suivant avec
## le bouton Next player. Options lues : start_value, in_condition,
## out_condition, same_score_hit (voir x01_game.gd).
##
## Decompte : tant que le joueur n'est pas entre (condition in_condition),
## ses jets ne comptent pas. Un bust (score negatif, score a 0 sans
## satisfaire out_condition, ou score a 1 alors que out_condition exige un
## double/triple) annule tout le tour, y compris ses effets same_score_hit
## sur d'autres joueurs (voir plus bas) : tout revient a ce que c'etait au
## debut du tour, qui se termine aussitot. Un score exactement a 0 en
## respectant out_condition gagne la partie. Au-dela de max_rounds, la
## partie s'arrete sans vainqueur. Dans les deux cas, l'ecran de classement
## suit (voir _standings).
##
## same_score_hit : quand un jet amene le joueur courant exactement au score
## d'un autre joueur, applique un effet a cet autre joueur (Wipe-Out ou
## Give-me your darts, voir _replay_turn). Cumulatif : plusieurs jets peuvent
## amener plusieurs joueurs sur le meme score qu'un meme joueur B avant que B
## ne rejoue.
##
## L'etat courant (scores, entree, dette de fleches, nombre de fleches du
## tour) n'est jamais modifie au coup par coup : il est entierement recalcule
## par _replay_turn() a partir d'un instantane pris au debut du tour en
## cours et de la liste des jets de ce tour (_turn_hits). Chaque tour termine
## garde son propre instantane de depart dans _turn_history (voir
## _capture_turn_history_entry), donc Cancel hit peut remonter tour par tour
## sans limite jusqu'au tout debut de la partie, en annulant a chaque fois
## les jets un a un puis en restaurant l'instantane exact du tour precedent
## (scores, entree et dette de TOUS les joueurs) : les effets same_score_hit
## sur d'autres joueurs (Wipe-Out, fleches donnees) sont annules tout aussi
## correctement que le score du joueur courant, quel que soit le nombre de
## tours ecoules depuis.

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
var _same_score_hit := "Nothing"

## Nombre de fleches par tour "normal" (avant application d'une dette de
## fleches donnees ou d'un bonus). Capture la valeur de darts_per_turn au
## demarrage, plutot que de la dupliquer en dur.
var _base_darts_per_turn := 3
## Fleches dues par chaque joueur (mode "Give-me your darts"), retirees de
## son prochain tour (jusqu'a _base_darts_per_turn a la fois, voir
## _advance_and_start_turn).
var _dart_debt: Array[int] = []

## Jets du tour en cours (parallele a GameScreen._throws, mais avec les
## DartHit complets necessaires au calcul du score).
var _turn_hits: Array[DartHit] = []
## Instantane complet pris au debut du tour en cours : point de depart que
## _replay_turn() rejoue avec _turn_hits pour obtenir l'etat courant.
var _turn_start_scores: Array[int] = []
var _turn_start_entered: Array[bool] = []
var _turn_start_dart_debt: Array[int] = []
var _turn_start_darts_per_turn := 3
## Tours termines, dans l'ordre (parallele a GameScreen._history) : permet a
## Cancel hit de revenir au tour precedent avec son instantane de depart
## exact. Les tours entierement sautes (dette de fleches) n'y figurent pas,
## de meme qu'ils ne figurent pas dans GameScreen._history.
var _turn_history: Array[Dictionary] = []

func _ready() -> void:
	super._ready()
	_base_darts_per_turn = darts_per_turn
	next_player_requested.connect(_on_next_player_requested)
	previous_player_requested.connect(_on_previous_player_requested)
	throw_cancelled.connect(_on_throw_cancelled)

func setup(players: Array[String], options: Dictionary) -> void:
	_players = players.duplicate()
	_in_condition = options.get("in_condition", "None")
	_out_condition = options.get("out_condition", "Double")
	_same_score_hit = options.get("same_score_hit", "Nothing")
	var start_value := int(options.get("start_value", "501"))

	_scores.clear()
	_entered.clear()
	_dart_debt.clear()
	for _player in _players:
		_scores.append(start_value)
		_entered.append(_in_condition == "None")
		_dart_debt.append(0)
	_current_player = 0
	darts_per_turn = _base_darts_per_turn
	set_round(1)
	reset_turn()
	clear_history()

	_turn_history.clear()
	_turn_hits.clear()
	_start_turn_snapshot()

	score_panel.set_players(_players)
	for i in _players.size():
		_refresh_row(i)
	score_panel.set_current_player(_current_player)

## Jet detecte : ajoute le jet au tour en cours, recalcule l'etat complet
## (voir _apply_turn_state) puis affiche le jet comme d'habitude. Termine le
## tour aussitot sur un bust ; declare la victoire aussitot sur un score a 0
## valide.
func _on_dart_hit(hit: DartHit) -> void:
	if _game_over or confirm_overlay.visible or remove_darts_screen.visible:
		return
	if get_remaining_darts() <= 0:
		return

	_turn_hits.append(hit)
	var result := _apply_turn_state()
	# Pas de notion de cible en X01 : chaque jet compte toujours pour le
	# score (badge toujours dore).
	add_throw(hit, true)

	if result.finished:
		var winner: Array[String] = [_players[_current_player]]
		announce_rank(winner, 1)
		finish_game(_standings(_current_player))
	elif result.busted:
		_start_remove_darts()

func _on_next_player_requested() -> void:
	if _players.is_empty():
		return
	_turn_history.append(_capture_turn_history_entry())
	_advance_and_start_turn()

## Avance au joueur suivant (et gere le nombre de rounds), applique sa dette
## de fleches eventuelle, puis prepare son tour. S'il n'a aucune fleche a
## jouer (dette >= darts_per_turn normal), passe silencieusement au joueur
## suivant sans repasser par l'historique : ce tour n'a jamais vraiment eu
## lieu. Termine forcement (la dette totale du systeme ne peut que diminuer
## ici, aucun jet n'etant lance pendant un saut).
## Note : darts_per_turn (GameScreen) est borne a 1 minimum par son setter,
## donc on ne le met jamais a jour a une valeur <= 0 ; un tour entierement
## saute court-circuite avant de le toucher.
func _advance_and_start_turn() -> void:
	_current_player = (_current_player + 1) % _players.size()
	if _current_player == 0:
		set_round(round_number + 1)
		if round_number > max_rounds:
			finish_game(_standings(-1))
			return

	var debt := _dart_debt[_current_player]
	if debt >= _base_darts_per_turn:
		_dart_debt[_current_player] -= _base_darts_per_turn
		_advance_and_start_turn()
		return

	_dart_debt[_current_player] = 0
	darts_per_turn = _base_darts_per_turn - debt

	_turn_hits = []
	_start_turn_snapshot()
	score_panel.set_current_player(_current_player)
	# La dette vient de changer (remboursee ou reduite par un saut) sans
	# passer par _apply_turn_state() : rafraichir explicitement, sinon les
	# gommettes restent affichees avec l'ancienne valeur jusqu'au prochain
	# jet lance.
	for i in _players.size():
		_refresh_row(i)

## Revient au tour du joueur precedent (Cancel hit avec le tour courant
## vide) : restaure son instantane de depart et ses jets, qui seront retires
## un a un par les appels suivants a throw_cancelled.
func _on_previous_player_requested() -> void:
	if _players.is_empty() or _turn_history.is_empty():
		return
	var entry: Dictionary = _turn_history.pop_back()
	if _current_player == 0:
		set_round(round_number - 1)

	_current_player = entry.player
	_turn_start_scores = entry.start_scores.duplicate()
	_turn_start_entered = entry.start_entered.duplicate()
	_turn_start_dart_debt = entry.start_dart_debt.duplicate()
	_turn_start_darts_per_turn = entry.start_darts_per_turn
	_turn_hits = entry.hits.duplicate()
	_apply_turn_state()
	score_panel.set_current_player(_current_player)

func _on_throw_cancelled() -> void:
	if _turn_hits.is_empty():
		return
	_turn_hits.pop_back()
	_apply_turn_state()

## Prend l'instantane de depart du tour qui commence pour _current_player :
## scores, entree et dette de TOUS les joueurs, plus le nombre de fleches du
## tour. _replay_turn() rejouera toujours depuis cet instantane, jamais a
## partir de l'etat courant : c'est ce qui rend Cancel hit correct, y
## compris pour les effets same_score_hit sur d'autres joueurs.
func _start_turn_snapshot() -> void:
	_turn_start_scores = _scores.duplicate()
	_turn_start_entered = _entered.duplicate()
	_turn_start_dart_debt = _dart_debt.duplicate()
	_turn_start_darts_per_turn = darts_per_turn

func _capture_turn_history_entry() -> Dictionary:
	return {
		"player": _current_player,
		"hits": _turn_hits.duplicate(),
		"start_scores": _turn_start_scores.duplicate(),
		"start_entered": _turn_start_entered.duplicate(),
		"start_dart_debt": _turn_start_dart_debt.duplicate(),
		"start_darts_per_turn": _turn_start_darts_per_turn,
	}

## Recalcule integralement l'etat courant (scores et entree de tous les
## joueurs, dette de fleches, nombre de fleches du tour) en rejouant
## _turn_hits depuis l'instantane de debut de tour, et met a jour
## l'affichage. Rejouer entierement a chaque jet (plutot que d'ajuster l'etat
## au coup par coup) rend Cancel hit correct par construction : annuler un
## jet annule aussi tout ce qu'il avait declenche, y compris sur un autre
## joueur (Wipe-Out, fleches donnees).
func _apply_turn_state() -> Dictionary:
	var result := _replay_turn(_turn_hits)
	if result.busted:
		# Bust : le tour entier est annule, effets same_score_hit compris,
		# comme s'il n'avait jamais eu lieu.
		_scores = _turn_start_scores.duplicate()
		_entered = _turn_start_entered.duplicate()
		_dart_debt = _turn_start_dart_debt.duplicate()
		darts_per_turn = _turn_start_darts_per_turn
	else:
		_scores = result.scores
		_entered = result.entered
		_dart_debt = result.dart_debt
		darts_per_turn = result.darts_per_turn

	for i in _players.size():
		_refresh_row(i)
	return result

## Rejoue une suite de jets du joueur courant depuis l'instantane de debut de
## tour. S'arrete des qu'un jet gagne la partie (score a 0 valide) ou fait un
## bust. Une egalite de score avec un autre joueur (autre que par un jet
## rate) applique l'effet same_score_hit configure a cet autre joueur : voir
## la doc en tete de fichier.
func _replay_turn(hits: Array[DartHit]) -> Dictionary:
	var scores := _turn_start_scores.duplicate()
	var entered := _turn_start_entered.duplicate()
	var dart_debt := _turn_start_dart_debt.duplicate()
	var turn_darts := _turn_start_darts_per_turn
	var busted := false
	var finished := false
	var player := _current_player

	for hit in hits:
		if not entered[player]:
			if not _satisfies_in(hit):
				continue
			entered[player] = true

		var new_score: int = scores[player] - hit.get_score()
		if _is_bust(new_score, hit):
			busted = true
			break

		scores[player] = new_score
		if new_score == 0:
			finished = true
			break

		if _same_score_hit != "Nothing" and not hit.is_miss():
			for i in _players.size():
				if i != player and scores[i] == new_score:
					turn_darts = _apply_same_score_hit(i, hit, scores, dart_debt, turn_darts)

	return {
		"scores": scores, "entered": entered, "dart_debt": dart_debt,
		"darts_per_turn": turn_darts, "busted": busted, "finished": finished,
	}

## Applique l'effet "meme score" au joueur other_index (jamais le joueur
## courant), sur les copies de travail de _replay_turn, et renvoie le nombre
## de fleches du tour a jour. Wipe-Out : son score retombe a 0, sans avoir a
## re-satisfaire in_condition (il reste "dans la partie"). Give-me your
## darts : il donne au joueur courant autant de fleches que le
## multiplicateur du jet qui a provoque l'egalite (simple = 1, double = 2,
## triple = 3), a lancer tout de suite dans le meme tour ; ces fleches seront
## retirees de son prochain tour (voir _advance_and_start_turn).
func _apply_same_score_hit(other_index: int, hit: DartHit, scores: Array[int], dart_debt: Array[int], turn_darts: int) -> int:
	match _same_score_hit:
		"Wipe-Out":
			scores[other_index] = 0
		"Give-me your darts":
			var count := hit.multiplier
			dart_debt[other_index] += count
			turn_darts += count
	return turn_darts

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

## Classement final : le gagnant (winner, -1 si la partie s'arrete sans
## vainqueur, voir max_rounds) en tete, puis les autres joueurs par points
## restants croissants (ex aequo a points egaux).
func _standings(winner: int) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for i in _players.size():
		entries.append({"name": _players[i], "score": _scores[i], "index": i})
	return rank_standings(entries, func(a: Dictionary, b: Dictionary) -> bool:
		if (a.index == winner) != (b.index == winner):
			return a.index == winner
		return a.score < b.score)

func _refresh_row(index: int) -> void:
	score_panel.set_row(index, _scores[index], _hint_for(index))
	score_panel.set_debt(index, _dart_debt[index])

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
