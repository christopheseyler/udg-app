class_name DoBetterLogoDart
extends Node3D

## Flechette du logo de Beat the King : lancee vers la couronne a son
## tour, elle se plante dans la cible la ou etait la couronne, puis s'efface
## en fondu avec les autres (voir DoBetterLogoTiming). Sa position de repos
## est celle de la couronne, sur la face de la cible ; ses maillages restent
## tels quels dans le logo (groupe GameLogo3D.UNMERGED_GROUP) pour pouvoir
## s'effacer (GeometryInstance3D.transparency) sans le reste du logo.

## Rang de la flechette (0 a 2) : moment du lancer et point d'impact.
@export var index: int = 0
## D'ou elle arrive, depuis son point d'impact (vers la camera, un peu en
## dessous a droite : l'empennage reste tourne vers le lanceur).
@export var throw_from := Vector3(0.1, -0.18, 0.9)
## Hauteur de la courbe du vol, en metres.
@export var arc_height: float = 0.06
## Enfoncement de la pointe dans la cible.
@export var depth: float = 0.006

var _rest: Transform3D
var _time := 0.0
## Copies des materiaux de la flechette (partages avec les autres flechettes
## du jeu), dont l'alpha suit le fondu. GeometryInstance3D.transparency est
## sans effet sur ces materiaux opaques avec le renderer Mobile.
var _materials: Array[BaseMaterial3D] = []
var _fade := -1.0

func _ready() -> void:
	for mesh: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		for i in mesh.get_surface_override_material_count():
			var material := mesh.get_active_material(i) as BaseMaterial3D
			if material:
				material = material.duplicate()
				mesh.set_surface_override_material(i, material)
				_materials.append(material)

func _enter_tree() -> void:
	_rest = transform
	_time = 0.0

func _exit_tree() -> void:
	transform = _rest

func _process(delta: float) -> void:
	_time += delta
	var t := DoBetterLogoTiming.cycle_time(_time)
	var progress := DoBetterLogoTiming.flight_progress(t, index)
	var fade := DoBetterLogoTiming.dart_fade(t)
	visible = progress >= 0.0 and fade < 1.0
	if not visible:
		return
	_set_fade(fade)

	var impact := _rest.origin + DoBetterLogoTiming.SPOTS[index] + Vector3(0.0, 0.0, -depth)
	var tip := impact + throw_from * (1.0 - progress)
	tip.y += arc_height * 4.0 * progress * (1.0 - progress)
	transform = Transform3D(_aim_basis(throw_from.normalized()), tip)

## Fondu des materiaux : opaques (rendu normal) tant que `fade` vaut 0,
## melanges en transparence pendant le fondu.
func _set_fade(fade: float) -> void:
	if fade == _fade:
		return
	_fade = fade
	for material in _materials:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if fade > 0.0 \
				else BaseMaterial3D.TRANSPARENCY_DISABLED
		material.albedo_color.a = 1.0 - fade

## Base de la flechette (pointe a l'origine, empennage vers +Y) : son axe Y
## tourne vers `tail`.
func _aim_basis(tail: Vector3) -> Basis:
	var x := tail.cross(Vector3.BACK).normalized()
	var z := x.cross(tail).normalized()
	return Basis(x, tail, z).scaled(_rest.basis.get_scale())
