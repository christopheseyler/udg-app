extends Node

## Autoload : point d'entree unique des jets de fleche. Les ecrans de jeu
## s'abonnent a hit_detected sans savoir d'ou viennent les jets. Deux sources
## tournent en parallele : la carte d'interface reelle (DartBoardInput, voir
## udg-yocto/doc/DARTBOARD-INTERFACE.md) et le simulateur (SimulatedDartInput
## + son panneau DartSimulator, toujours disponible pendant une partie meme
## si la carte est branchee - pratique pour tester ou completer un tour a la
## main). Si la carte n'est pas branchee, connect_to_board() echoue
## silencieusement et seul le simulateur reste actif.
##
## La politique de tour (WaitForHit arme au debut du tour puis reargue apres
## chaque jet tant qu'il en reste flechettes) est decidee par GameScreen via
## start_turn()/stop_turn() ; un jet lance depuis le simulateur interrompt
## aussi l'attente de la carte reelle (StopWaitingHit), pour eviter qu'un jet
## physique tardif ne vienne s'ajouter en double.
##
## Connexion perdue pendant une partie (DartBoardInput.connection_lost) :
## nouvelles tentatives toutes les RECONNECT_INTERVAL secondes, au plus
## RECONNECT_ATTEMPTS fois, et l'attente d'un jet est rearmee si le tour en
## cours en attendait un (_wants_hit).

signal hit_detected(hit: DartHit)

const SIMULATOR_SCENE := preload("res://dart_input/dart_simulator.tscn")
const RECONNECT_INTERVAL := 1.0
const RECONNECT_ATTEMPTS := 10

var simulated_input: SimulatedDartInput
var board_input: DartBoardInput

var _simulator: DartSimulator
var _active := false
## Le tour en cours attend un jet de la carte reelle : entre start_turn() et
## stop_turn() ou le jet qui termine l'attente.
var _wants_hit := false
var _reconnecting := false

func _ready() -> void:
	simulated_input = SimulatedDartInput.new()
	add_child(simulated_input)
	simulated_input.hit_detected.connect(_on_simulated_hit_detected)

	board_input = DartBoardInput.new()
	add_child(board_input)
	board_input.hit_detected.connect(_on_board_hit_detected)
	board_input.connection_lost.connect(_reconnect)

	_simulator = SIMULATOR_SCENE.instantiate()
	add_child(_simulator)
	_simulator.setup(simulated_input)
	_simulator.set_available(_active)

## Un ecran de jeu l'active a son ouverture (connexion a la carte, panneau de
## simulation disponible) et le desactive a sa fermeture (deconnexion, ce qui
## libere le port pour un autre usage, ex : mise a jour du firmware depuis
## l'ecran Settings).
func set_active(active: bool) -> void:
	_active = active
	_wants_hit = false
	_simulator.set_available(active)
	if active:
		board_input.connect_to_board()
	else:
		board_input.disconnect_from_board()

## Arme l'attente d'un jet sur la carte reelle (no-op si non connectee). A
## appeler au debut de chaque tour puis apres chaque jet tant qu'il reste des
## flechettes (voir GameScreen.reset_turn()/add_throw()).
func start_turn() -> void:
	_wants_hit = true
	board_input.start_waiting()

## Interrompt l'attente en cours sur la carte reelle (no-op si non connectee
## ou pas en attente). A appeler quand le tour se termine avant que la carte
## n'ait elle-meme recu de jet (bouton Next player, bust, ...).
func stop_turn() -> void:
	_wants_hit = false
	board_input.stop_waiting()

func _on_simulated_hit_detected(hit: DartHit) -> void:
	_wants_hit = false
	board_input.stop_waiting()
	hit_detected.emit(hit)

func _on_board_hit_detected(hit: DartHit) -> void:
	# Le jet termine l'attente cote carte ; le jeu la rearme (start_turn)
	# s'il reste des flechettes.
	_wants_hit = false
	hit_detected.emit(hit)

## Connexion a la carte perdue : tant qu'une partie est en cours, retente la
## connexion jusqu'a RECONNECT_ATTEMPTS fois, puis rearme l'attente d'un jet
## si le tour en attendait un. Abandonne si la partie se termine entre-temps.
func _reconnect() -> void:
	if _reconnecting:
		return
	_reconnecting = true
	for attempt in RECONNECT_ATTEMPTS:
		await get_tree().create_timer(RECONNECT_INTERVAL).timeout
		if not _active or board_input.is_connected_to_board():
			break
		board_input.connect_to_board()
		if board_input.is_connected_to_board():
			if _wants_hit:
				board_input.start_waiting()
			break
	_reconnecting = false
