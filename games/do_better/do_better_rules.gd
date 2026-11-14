class_name DoBetterRules
extends RefCounted

## Regles de Beat the King, if you can, sans affichage : l'etat
## de la partie est un Dictionary (voir new_state()) que apply_turn() fait
## evoluer a la fin de chaque tour et advance() fait passer au tour suivant.
## L'ecran (DoBetterScreen) garde un instantane de l'etat au debut de chaque
## tour, pour que Cancel hit puisse revenir en arriere.
##
## Chaque round a un master initial (rotation dans l'ordre des joueurs). Sa
## premiere fleche fixe la cible du round ; ses trois fleches donnent le score
## a battre, en marques. Les autres joueurs jouent ensuite chacun trois
## fleches sur cette cible, dans l'ordre : mieux que le master, +1 point pour
## le joueur ; moins bien, +1 point pour le master ; egalite, rien.
##
## Marques : sur un numero, simple = 1, double = 2, triple = 3. Sur le bull
## (cible fixee par un bull), 25 = 1, bull = 2. Si la premiere fleche du
## master est ratee, la cible est "Miss" : chaque fleche ratee vaut 1 marque.
## Les fleches hors de la cible ne valent rien.
##
## Option Get the Crown (id "get_the_lead", son ancien nom) : le joueur qui
## bat le master actuel prend son titre (la couronne) et son score devient le
## score a battre ; la cible ne change pas. En cas d'egalite, le master garde
## son titre, sans point. Si le master initial a perdu son titre, il rejoue
## en dernier : s'il bat le master actuel, il reprend le titre, gagne 1 point
## et recupere tous les points gagnes pendant ce round par les autres
## joueurs ; sinon, le master actuel gagne 1 point (rien en cas d'egalite).
## Sans cette option, le master initial garde le titre tout le round.
##
## La couronne affichee par l'ecran est toujours sur le master actuel.
##
## Option Keep the Crown : le master initial ne tourne plus ; le master a la
## fin d'un round est le master initial du suivant (sans Get the Crown, le
## premier master le reste donc toute la partie).
##
## A la fin du dernier round (un multiple du nombre de joueurs, pour que
## chacun soit master initial autant de fois sans Keep the Crown), le plus de
## points gagne ; les egalites partagent la place.
##
## A l'ecran, le master s'appelle le "king" (le jeu est Beat the King, if you
## can) ; le code garde le terme master.

## Etat d'une nouvelle partie de `player_count` joueurs, en `rounds` rounds.
static func new_state(player_count: int, rounds: int, get_the_lead: bool, keep_the_crown: bool = false) -> Dictionary:
	var points: Array[int] = []
	points.resize(player_count)
	points.fill(0)
	var state := {
		"players": player_count,
		"rounds": rounds,
		"get_the_lead": get_the_lead,
		"keep_the_crown": keep_the_crown,
		"points": points,
		"round": 1,
		"over": false,
		"master": 0,
	}
	_start_round(state)
	return state

## Prepare le round state.round : master initial selon la rotation (ou celui
## qui a garde la couronne, avec Keep the Crown), cible a fixer par sa
## premiere fleche.
static func _start_round(state: Dictionary) -> void:
	var gains: Array[int] = []
	gains.resize(state.players)
	gains.fill(0)
	var initial: int = (state.round - 1) % state.players
	if state.keep_the_crown:
		initial = state.master
	state.merge({
		# Rang du tour dans le round : 0 = master initial, puis les autres.
		"turn": 0,
		# Vrai pendant le retour du master initial (Get the Crown).
		"comeback": false,
		"initial": initial,
		"master": initial,
		# Score a battre, en marques.
		"best": 0,
		# {"type": "number", "value": 20}, {"type": "bull"}, {"type": "miss"},
		# ou {} tant que le master initial n'a pas lance sa premiere fleche.
		"target": {},
		# Points gagnes pendant ce round, par joueur (repris par le master
		# initial s'il recupere son titre).
		"gains": gains,
		# Marques de chaque joueur deja passe ce round : {joueur: marques}.
		"played": {},
		# Resume du dernier tour, pour l'affichage.
		"last_result": "",
	}, true)

## Joueur dont c'est le tour.
static func current_player(state: Dictionary) -> int:
	if state.comeback:
		return state.initial
	return (state.initial + state.turn) % state.players

## Vrai pendant le tour du master initial qui fixe la cible.
static func is_setting_target(state: Dictionary) -> bool:
	return state.turn == 0 and not state.comeback

## Cible fixee par la premiere fleche du master initial.
static func target_from_hit(hit: DartHit) -> Dictionary:
	if hit.is_miss():
		return {"type": "miss"}
	if hit.segment == DartHit.BULL:
		return {"type": "bull"}
	return {"type": "number", "value": hit.segment}

## Cible du tour en cours : celle du round, ou, pendant le tour du master
## initial, celle que fixe sa premiere fleche (`hits`), {} avant.
static func turn_target(state: Dictionary, hits: Array[DartHit]) -> Dictionary:
	if is_setting_target(state):
		return target_from_hit(hits[0]) if not hits.is_empty() else {}
	return state.target

## Marques d'une fleche sur `target`.
static func marks(hit: DartHit, target: Dictionary) -> int:
	match target.get("type", ""):
		"miss":
			return 1 if hit.is_miss() else 0
		"bull":
			return hit.multiplier if hit.segment == DartHit.BULL else 0
		"number":
			return hit.multiplier if not hit.is_miss() and hit.segment == target.value else 0
	return 0

static func total_marks(hits: Array[DartHit], target: Dictionary) -> int:
	var total := 0
	for hit in hits:
		total += marks(hit, target)
	return total

## Libelle d'une cible : "20", "Bull", "Miss".
static func target_label(target: Dictionary) -> String:
	match target.get("type", ""):
		"miss":
			return "Miss"
		"bull":
			return "Bull"
		"number":
			return str(target.value)
	return "?"

## Applique le resultat du tour en cours (fleches `hits`) a `state`. `names`
## sert au resume du tour (state.last_result).
static func apply_turn(state: Dictionary, hits: Array[DartHit], names: Array[String]) -> void:
	var player := current_player(state)
	var target := turn_target(state, hits)
	var score := total_marks(hits, target)
	state.played[player] = score

	if is_setting_target(state):
		state.target = target
		state.best = score
		state.master = player
		state.last_result = "%s sets the target: %s, %s to beat" % [
			names[player], target_label(target), _marks_text(score)]
		return

	var master: int = state.master
	if state.comeback:
		if score > state.best:
			var recovered := 0
			for i in state.players:
				if i != player and state.gains[i] > 0:
					state.points[i] -= state.gains[i]
					recovered += state.gains[i]
					state.gains[i] = 0
			_give_point(state, player)
			state.points[player] += recovered
			state.gains[player] += recovered
			state.master = player
			state.best = score
			state.last_result = "%s takes the crown back: +1 and %d recovered" % [names[player], recovered]
		elif score < state.best:
			_give_point(state, master)
			state.last_result = "%s keeps the crown: +1 %s" % [names[master], names[master]]
		else:
			state.last_result = "Tie: %s keeps the crown, no point" % names[master]
		return

	if score > state.best:
		_give_point(state, player)
		if state.get_the_lead:
			state.master = player
			state.best = score
			state.last_result = "%s takes the crown: +1" % names[player]
		else:
			state.last_result = "%s does better: +1 %s" % [names[player], names[player]]
	elif score < state.best:
		_give_point(state, master)
		state.last_result = "%s fails: +1 %s" % [names[player], names[master]]
	else:
		state.last_result = ("Tie: %s keeps the crown, no point" if state.get_the_lead else "Tie with %s: no point") % names[master]

static func _give_point(state: Dictionary, player: int) -> void:
	state.points[player] += 1
	state.gains[player] += 1

static func _marks_text(count: int) -> String:
	return "%d mark%s" % [count, "" if count == 1 else "s"]

## Passe au tour suivant apres apply_turn() : joueur suivant du round, retour
## du master initial (Get the Crown, s'il a perdu son titre), ou round suivant.
## state.over devient vrai apres le dernier tour du dernier round.
static func advance(state: Dictionary) -> void:
	if not state.comeback and state.turn < state.players - 1:
		state.turn += 1
		return
	if not state.comeback and state.get_the_lead and state.master != state.initial:
		state.comeback = true
		return
	state.round += 1
	if state.round > state.rounds:
		state.over = true
		return
	var last_result: String = state.last_result
	_start_round(state)
	state.last_result = last_result

## Copie independante de l'etat (instantane de debut de tour).
static func copy(state: Dictionary) -> Dictionary:
	return state.duplicate(true)
