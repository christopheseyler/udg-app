class_name TitleIntro3D
extends Node3D

## Intro 3D de l'ecran titre : la cible monte du bas de l'ecran en tournant
## sur elle-meme et s'arrete legerement de biais (position de repos de
## Board dans la scene). Pendant qu'elle tourne, le titre arrive devant elle
## en lettres 3D : le premier mot par le bord gauche de l'ecran, le second
## par le bord droit, chaque lettre faisant un tour sur elle-meme autour de
## l'axe horizontal, avec un leger decalage d'une lettre a l'autre. Une fois
## le titre en place, trois flechettes viennent se planter dans la cible,
## un spot balaye le titre de gauche a droite, puis les lettres s'envolent
## vers l'avant en tournant au hasard et en disparaissant en fondu. Emet
## `finished` au moment ou les lettres s'envolent.

signal finished

const DART_SCENE := preload("res://assets/udg-3d-assets/dart/Dart.glb")
## Caracteres HemiHead (Char_A, Char_a, Char_0...) : origine sur la ligne de
## base, chasse en metres dans la metadonnee glTF extras.advance.
const LETTERS_SCENE := preload("res://assets/udg-3d-assets/hemihead/HemiHeadChamfer.glb")
## Calque de rendu des lettres, le seul eclaire par TitleLight : vu de face,
## le metal ne reflete sinon que le ciel sombre de l'environnement.
const TITLE_LAYER := 2

@export_group("Cible")
@export var start_delay: float = 0.2
@export var rise_duration: float = 1.8
## Tours complets autour de l'axe vertical pendant la montee.
@export var spin_turns: float = 2.0
## Position de depart par rapport a la position de repos (sous l'ecran).
@export var rise_offset := Vector3(0.0, -1.1, 0.0)

@export_group("Titre")
## Mot qui arrive par le bord gauche de l'ecran.
@export var left_word: String = "Ultimate"
## Mot qui arrive par le bord droit de l'ecran.
@export var right_word: String = "Darts"
## Debut de l'arrivee du titre apres l'appel a play().
@export var title_delay: float = 0.5
@export var title_slide_duration: float = 1.6
## Decalage entre les tours de deux lettres voisines (la lettre de tete,
## la plus proche du centre, tourne la premiere).
@export var letter_spin_stagger: float = 0.06
## Espace entre les deux mots, en metres a l'echelle des caracteres.
@export var word_gap: float = 0.03

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

@export_group("Spot")
@export var sweep_delay: float = 0.3
@export var sweep_duration: float = 1.2
@export var spot_energy: float = 16.0
## Position du spot par rapport au point vise sur la ligne mediane du titre.
@export var spot_offset := Vector3(0.0, 0.06, 0.3)

@export_group("Envol du titre")
@export var fly_delay: float = 0.2
@export var fly_duration: float = 0.9
## Distance parcourue vers la camera.
@export var fly_distance: float = 0.7
## Rotation maximale autour de chaque axe, en tours, tiree au hasard par lettre.
@export var fly_spin_turns: float = 1.0
## Retard maximal, tire au hasard, du depart de chaque lettre.
@export var fly_stagger: float = 0.15

@onready var board: Node3D = $Board
@onready var camera: Camera3D = $Camera3D
@onready var title: Node3D = $Title
@onready var spot: SpotLight3D = $TitleSpot

var is_finished := false
var _rest_position: Vector3
var _rest_rotation: Vector3
## Pivots des lettres, un tableau par mot, de gauche a droite. Chaque pivot
## est au centre de son caractere (axe des rotations), le maillage en enfant.
var _words: Array[Array] = []
## Encombrement du titre dans le repere de Title.
var _title_bounds: AABB

func _ready() -> void:
	_rest_position = board.position
	_rest_rotation = board.rotation
	board.visible = false
	_build_title()
	title.visible = false

func play() -> void:
	board.position = _rest_position + rise_offset
	board.rotation = _rest_rotation - Vector3(0.0, spin_turns * TAU, 0.0)
	board.visible = true

	var tween := create_tween().set_parallel()
	tween.tween_property(board, "position", _rest_position, rise_duration) \
		.set_delay(start_delay).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(board, "rotation", _rest_rotation, rise_duration) \
		.set_delay(start_delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_slide_title_in(tween)
	await tween.finished

	for i in dart_hits.size():
		await get_tree().create_timer(throw_delay if i == 0 else throw_interval).timeout
		if i < dart_hits.size() - 1:
			_throw_dart(i)
		else:
			await _throw_dart(i)

	await get_tree().create_timer(sweep_delay).timeout
	await _sweep_spot()
	await get_tree().create_timer(fly_delay).timeout
	_fly_title_away()
	is_finished = true
	finished.emit()

## Pose les lettres des deux mots en ajoutant leurs chasses, le titre
## centre sur l'origine de Title. Les plaques de deux lettres voisines
## peuvent se chevaucher : une lettre sur deux est avancee d'un
## demi-millimetre pour que leurs faces ne se battent pas a l'affichage.
func _build_title() -> void:
	var font := LETTERS_SCENE.instantiate()
	var x := 0.0
	var index := 0
	for word in [left_word, right_word]:
		var pivots: Array[Node3D] = []
		for ch in word:
			var glyph := font.get_node_or_null("HemiHead/Char_" + ch) as MeshInstance3D
			if glyph == null:
				push_warning("Titre : pas de caractere 3D pour '%s'" % ch)
				continue
			var aabb := glyph.mesh.get_aabb()
			var mesh := MeshInstance3D.new()
			mesh.mesh = glyph.mesh
			mesh.layers = TITLE_LAYER
			mesh.position = -aabb.get_center()
			var pivot := Node3D.new()
			pivot.position = Vector3(x, 0.0, (index % 2) * 0.0005) + aabb.get_center()
			pivot.add_child(mesh)
			title.add_child(pivot)
			pivots.append(pivot)
			_title_bounds = aabb if index == 0 else _title_bounds.merge(Transform3D(Basis(), Vector3(x, 0.0, 0.0)) * aabb)
			x += glyph.get_meta("extras")["advance"]
			index += 1
		_words.append(pivots)
		x += word_gap
	font.free()

	var centre := Vector3(_title_bounds.get_center().x, 0.0, 0.0)
	_title_bounds.position -= centre
	for pivots in _words:
		for pivot: Node3D in pivots:
			pivot.position -= centre

## Ajoute a `tween` l'arrivee des deux mots, chacun depuis son bord de
## l'ecran : un mot glisse d'un bloc pendant que ses lettres font chacune un
## tour, en commencant par la lettre de tete. Les mots partent juste hors
## champ, calcule a la profondeur du titre.
func _slide_title_in(tween: Tween) -> void:
	title.visible = true
	var view := get_viewport().get_visible_rect().size
	var depth := camera.global_position.z - title.global_position.z
	for w in _words.size():
		var side := -1.0 if w == 0 else 1.0
		var letters: Array = _words[w].duplicate()
		if side < 0.0:
			letters.reverse()
		var edge := title.to_local(camera.project_position(Vector2(view.x * (side + 1.0) / 2.0, view.y / 2.0), depth)).x
		var lead: Node3D = letters[0]
		var shift := edge - lead.position.x + side * (_half_width(lead) + 0.01)
		var spin_duration := title_slide_duration - letter_spin_stagger * (letters.size() - 1)
		for k in letters.size():
			var pivot: Node3D = letters[k]
			var rest_x := pivot.position.x
			pivot.position.x += shift
			pivot.rotation.x = side * TAU
			tween.tween_property(pivot, "position:x", rest_x, title_slide_duration) \
				.set_delay(title_delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tween.tween_property(pivot, "rotation:x", 0.0, spin_duration) \
				.set_delay(title_delay + k * letter_spin_stagger).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

## Demi-largeur du caractere d'un pivot, dans le repere de Title.
func _half_width(pivot: Node3D) -> float:
	return (pivot.get_child(0) as MeshInstance3D).mesh.get_aabb().size.x / 2.0

## Balaye le titre de gauche a droite avec le spot, place devant la ligne
## mediane du titre et vise sur elle. Il part et finit a une largeur de
## faisceau des bords du titre, et s'allume et s'eteint hors du titre.
func _sweep_spot() -> void:
	var reach := spot_offset.length() * tan(deg_to_rad(spot.spot_angle)) / title.scale.x
	var from := _title_bounds.position.x - reach
	var to := _title_bounds.end.x + reach
	var mid_y := _title_bounds.get_center().y
	var sweep := func(t: float) -> void:
		var target := title.to_global(Vector3(lerpf(from, to, t), mid_y, 0.0))
		spot.global_position = target + spot_offset
		spot.look_at(target)
		spot.light_energy = spot_energy * clampf(sin(t * PI) * 3.0, 0.0, 1.0)
	sweep.call(0.0)
	spot.visible = true
	var tween := create_tween()
	tween.tween_method(sweep, 0.0, 1.0, sweep_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	spot.visible = false

## Fait partir les lettres vers la camera, chacune avec un retard, une
## derive et une rotation tires au hasard, en disparaissant en fondu.
func _fly_title_away() -> void:
	var tween := create_tween().set_parallel()
	for pivots in _words:
		for pivot: Node3D in pivots:
			var delay := randf() * fly_stagger
			var drift := Vector3(randf_range(-0.1, 0.1), randf_range(-0.05, 0.1), fly_distance) / title.scale.x
			var spin := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * TAU * fly_spin_turns
			tween.tween_property(pivot, "position", pivot.position + drift, fly_duration) \
				.set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tween.tween_property(pivot, "rotation", pivot.rotation + spin, fly_duration) \
				.set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tween.tween_property(pivot.get_child(0), "transparency", 1.0, fly_duration) \
				.set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(title.hide)

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
