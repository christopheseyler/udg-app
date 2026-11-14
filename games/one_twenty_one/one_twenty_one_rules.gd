class_name OneTwentyOneRules
extends RefCounted

## Regles du 121, sans affichage. Chaque joueur a sa propre progression :
## un objectif courant (121 au depart, par defaut) a terminer a exactement 0
## en respectant la condition de finition, en au plus `darts_per_target`
## flechettes (un multiple de 3, lancees par volees de 3, les joueurs jouant
## chacun une volee a tour de role).
##
## - Reussite : l'objectif suivant vaut +1 ; la volee s'arrete. Avec le palier
##   de securite, un objectif termine dans les 3 premieres flechettes de la
##   tentative devient le palier.
## - Bust (score negatif, 0 sans la condition de finition, ou 1 quand la
##   finition exige un double/triple) : les flechettes de la volee sont
##   annulees (le score revient a celui du debut de volee) mais comptent dans
##   la limite ; la volee s'arrete.
## - Echec (limite atteinte sans reussite) : l'objectif suivant repart du
##   depart (ou du palier) avec "Back to Start", ou recule de 1 sans passer
##   sous le depart (ou le palier) avec "Step Back".
## Chaque nouvelle tentative dispose de toutes ses flechettes.

const OUT_CONDITIONS := ["Open Out", "Double Out", "Triple Out", "Master Out"]

## Etat d'un joueur au debut de la partie.
static func new_player(start: int) -> Dictionary:
	return {
		"target": start,
		"remaining": start,
		# Flechettes deja lancees dans la tentative en cours.
		"used": 0,
		# Palier de securite obtenu (0 : aucun).
		"safe": 0,
		# Plus haut objectif reussi (0 : aucun).
		"best": 0,
		# Nombre d'objectifs reussis.
		"successes": 0,
	}

## Plancher d'un joueur : son palier s'il en a un, sinon le depart.
static func floor_of(player: Dictionary, start: int) -> int:
	return maxi(player.safe, start)

## Vrai si `hit` peut terminer selon `out_condition`.
static func can_finish(hit: DartHit, out_condition: String) -> bool:
	if hit.is_miss():
		return false
	match out_condition:
		"Double Out":
			return hit.is_double()
		"Triple Out":
			return hit.is_triple()
		"Master Out":
			return hit.is_master()
	return true

## Joue la volee `hits` du joueur `player` (non modifie) et renvoie son
## nouvel etat, plus "outcome" : "" (volee en cours ou finie sans
## evenement), "success", "bust" ou "fail" (limite atteinte : `end_of_volley`
## applique alors l'echec), et "volley_over" (plus de flechette a lancer
## dans cette volee). `settings` : {start, darts_per_target, out_condition,
## safety, fail_rule}.
static func play_volley(player: Dictionary, hits: Array[DartHit], settings: Dictionary, end_of_volley: bool) -> Dictionary:
	var state := player.duplicate()
	var volley_start: int = state.remaining
	var used_at_start: int = state.used
	state.outcome = ""
	state.volley_over = false
	for hit in hits:
		state.used += 1
		var next: int = state.remaining - hit.get_score()
		if next == 0 and can_finish(hit, settings.out_condition):
			if settings.safety and state.used <= 3:
				state.safe = state.target
			state.best = maxi(state.best, state.target)
			state.successes += 1
			state.target += 1
			state.remaining = state.target
			state.used = 0
			state.outcome = "success"
			state.volley_over = true
			return state
		if next < 0 or next == 0 or (next == 1 and settings.out_condition != "Open Out"):
			state.remaining = volley_start
			state.outcome = "bust"
			state.volley_over = true
			break
		state.remaining = next
	if state.used - used_at_start >= 3:
		state.volley_over = true
	# Une volee terminee plus tot (bust, ou Next) compte ses 3 flechettes.
	if end_of_volley:
		state.used = used_at_start + 3
	if state.used >= settings.darts_per_target:
		state.volley_over = true
		if state.outcome == "":
			state.outcome = "fail"
		if end_of_volley:
			state.outcome = "fail"
			_apply_fail(state, settings)
	return state

static func _apply_fail(state: Dictionary, settings: Dictionary) -> void:
	var floor_value := floor_of(state, settings.start)
	if settings.fail_rule == "Step Back":
		state.target = maxi(state.target - 1, floor_value)
	else:
		state.target = floor_value
	state.remaining = state.target
	state.used = 0
