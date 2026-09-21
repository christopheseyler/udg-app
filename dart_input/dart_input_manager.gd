extends Node

## Autoload : point d'entree unique des jets de fleche. Les ecrans de jeu
## s'abonnent a hit_detected sans savoir d'ou viennent les jets ; la source
## (DartInput) se change avec set_input(). Tant que la vraie carte UART n'est
## pas implementee, la source par defaut est un SimulatedDartInput, avec son
## panneau de simulation (DartSimulator) accessible pendant une partie.

signal hit_detected(hit: DartHit)

const SIMULATOR_SCENE := preload("res://dart_input/dart_simulator.tscn")

var input: DartInput

var _simulator: DartSimulator
var _active := false

func _ready() -> void:
	set_input(SimulatedDartInput.new())

## Remplace la source de jets (carte UART, simulateur, ...). L'ancienne
## source est liberee ; le panneau de simulation n'existe que pour un
## SimulatedDartInput.
func set_input(new_input: DartInput) -> void:
	if input:
		input.hit_detected.disconnect(_on_input_hit_detected)
		input.queue_free()
	if _simulator:
		_simulator.queue_free()
		_simulator = null

	input = new_input
	add_child(input)
	input.hit_detected.connect(_on_input_hit_detected)

	if input is SimulatedDartInput:
		_simulator = SIMULATOR_SCENE.instantiate()
		add_child(_simulator)
		_simulator.setup(input)
		_simulator.set_available(_active)

## Un ecran de jeu l'active a son ouverture et le desactive a sa fermeture :
## le panneau de simulation n'est propose que pendant une partie.
func set_active(active: bool) -> void:
	_active = active
	if _simulator:
		_simulator.set_available(active)

func _on_input_hit_detected(hit: DartHit) -> void:
	hit_detected.emit(hit)
