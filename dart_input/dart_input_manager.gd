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

signal hit_detected(hit: DartHit)

const SIMULATOR_SCENE := preload("res://dart_input/dart_simulator.tscn")

var simulated_input: SimulatedDartInput
var board_input: DartBoardInput

var _simulator: DartSimulator
var _active := false

func _ready() -> void:
	simulated_input = SimulatedDartInput.new()
	add_child(simulated_input)
	simulated_input.hit_detected.connect(_on_simulated_hit_detected)

	board_input = DartBoardInput.new()
	add_child(board_input)
	board_input.hit_detected.connect(_on_board_hit_detected)

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
	_simulator.set_available(active)
	if active:
		board_input.connect_to_board()
	else:
		board_input.disconnect_from_board()

## Arme l'attente d'un jet sur la carte reelle (no-op si non connectee). A
## appeler au debut de chaque tour puis apres chaque jet tant qu'il reste des
## flechettes (voir GameScreen.reset_turn()/add_throw()).
func start_turn() -> void:
	board_input.start_waiting()

## Interrompt l'attente en cours sur la carte reelle (no-op si non connectee
## ou pas en attente). A appeler quand le tour se termine avant que la carte
## n'ait elle-meme recu de jet (bouton Next player, bust, ...).
func stop_turn() -> void:
	board_input.stop_waiting()

func _on_simulated_hit_detected(hit: DartHit) -> void:
	board_input.stop_waiting()
	hit_detected.emit(hit)

func _on_board_hit_detected(hit: DartHit) -> void:
	hit_detected.emit(hit)
