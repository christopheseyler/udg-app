class_name TitleIntro3D
extends Node3D

## Intro 3D de l'ecran titre : la cible monte du bas de l'ecran en tournant
## sur elle-meme, s'arrete legerement de biais (position de repos de
## Board dans la scene), puis trois flechettes viennent s'y planter l'une
## apres l'autre. Emet `finished` une fois la derniere flechette immobile.

signal finished

const DART_SCENE := preload("res://assets/udg-3d-assets/dart/Dart.glb")

@export_group("Cible")
@export var start_delay: float = 0.2
@export var rise_duration: float = 1.8
## Tours complets autour de l'axe vertical pendant la montee.
@export var spin_turns: float = 2.0
## Position de depart par rapport a la position de repos (sous l'ecran).
@export var rise_offset := Vector3(0.0, -1.1, 0.0)

@export_group("Flechettes")
@export var throw_delay: float = 0.3
@export var throw_interval: float = 0.45
@export var flight_duration: float = 0.3
## Points d'impact dans le plan de la cible, en metres (bull au centre,
## 20 en haut). Par defaut : triple 20, triple 19, puis bull.
@export var dart_hits: Array[Vector2] = [Vector2(0.002, 0.117), Vector2(-0.035, -0.111), Vector2(0.001, 0.002)]
## Distance de depart devant la cible : les flechettes arrivent en ligne
## droite, perpendiculairement a la cible (hors champ au depart).
@export var launch_distance: float = 1.0
## Agrandissement des flechettes (1 = taille reelle, peu lisible a l'ecran).
@export var dart_scale: float = 1.5
## Enfoncement de la pointe dans la cible.
@export var tip_depth: float = 0.01
## Amplitude du tremblement de la flechette a l'impact.
@export var wobble_degrees: float = 5.0

@onready var board: Node3D = $Board

var is_finished := false
var _rest_position: Vector3
var _rest_rotation: Vector3

func _ready() -> void:
	_rest_position = board.position
	_rest_rotation = board.rotation
	board.visible = false

func play() -> void:
	board.position = _rest_position + rise_offset
	board.rotation = _rest_rotation - Vector3(0.0, spin_turns * TAU, 0.0)
	board.visible = true

	var tween := create_tween().set_parallel()
	tween.tween_property(board, "position", _rest_position, rise_duration) \
		.set_delay(start_delay).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(board, "rotation", _rest_rotation, rise_duration) \
		.set_delay(start_delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tween.finished

	for i in dart_hits.size():
		await get_tree().create_timer(throw_delay if i == 0 else throw_interval).timeout
		if i < dart_hits.size() - 1:
			_throw_dart(i)
		else:
			await _throw_dart(i)
	is_finished = true
	finished.emit()

## Lance une flechette en ligne droite le long de la normale de la cible
## jusqu'a son point d'impact. Elle est rattachee a la cible : son origine
## est la pointe, son axe +Y va vers l'empennage.
func _throw_dart(index: int) -> void:
	var dart: Node3D = DART_SCENE.instantiate()
	board.add_child(dart)

	var hit := dart_hits[index]
	var end := Vector3(hit.x, hit.y, -tip_depth)
	var start := end + Vector3.BACK * launch_distance
	var roll := 0.7 + index * 2.1

	var fly := func(t: float) -> void:
		dart.transform = Transform3D(_dart_basis(roll + t * TAU * 1.5), start.lerp(end, t))
	fly.call(0.0)
	var tween := create_tween()
	tween.tween_method(fly, 0.0, 1.0, flight_duration)
	await tween.finished

	_punch_board()
	var rest_basis := dart.basis
	var wobble := func(t: float) -> void:
		var angle := deg_to_rad(wobble_degrees) * exp(-7.0 * t) * sin(t * TAU * 8.0)
		dart.basis = rest_basis * Basis(Vector3.RIGHT, angle)
	tween = create_tween()
	tween.tween_method(wobble, 0.0, 0.6, 0.6)
	await tween.finished

## Couche la flechette le long de la normale de la cible (axe +Y de la
## flechette vers +Z de la cible), avec une rotation propre autour de cet axe.
func _dart_basis(roll: float) -> Basis:
	return (Basis(Vector3.RIGHT, PI / 2.0) * Basis(Vector3.UP, roll)).scaled_local(Vector3.ONE * dart_scale)

## Petit recul de la cible a chaque impact.
func _punch_board() -> void:
	var tween := create_tween()
	tween.tween_property(board, "position", _rest_position - board.basis.z * 0.006, 0.04)
	tween.tween_property(board, "position", _rest_position, 0.3) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
