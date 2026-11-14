class_name LeaderCrown
extends SubViewportContainer

## Couronne de l'ecran de Beat the King : la couronne 3D du logo (crown.glb),
## rendue dans un petit SubViewport transparent, posee de biais sur le coin
## superieur gauche de la ligne de son porteur (voir DoBetterRules). Quand
## elle change de main (un joueur fait mieux, nouveau round), elle saute
## jusqu'a la ligne du nouveau porteur, puis grossit un instant et un reflet
## la traverse (voir leader_crown_shine.gdshader).
##
## L'ecran fournit `row_rect` (index de joueur -> rectangle global de sa
## ligne) ; la couronne suit sa ligne a chaque image, donc reste en place si
## la mise en page change.

## Hauteur de la couronne, en proportion de la hauteur de la ligne.
const HEIGHT_RATIO := 0.85
## Retrait des noms (HeaderScorePanel.name_indent_ratio) qui laisse la place a
## la couronne, en proportion de la hauteur d'une ligne.
const NAME_INDENT_RATIO := 0.75
## Largeur / hauteur du rendu.
const ASPECT := 1.25
## Inclinaison a l'ecran, en degres (negatif : penchee vers la gauche).
const TILT_DEGREES := -22.0
## Centre de la couronne par rapport au coin superieur gauche de la ligne, en
## proportion de sa taille : a cheval sur le bord gauche, dans le retrait
## des noms, et un peu au-dessus du bord haut.
const CORNER_OFFSET := Vector2(0.33, -0.1)
const TRAVEL_TIME := 0.7
## Ecart lateral (vers la gauche) du saut d'une ligne a l'autre, en
## proportion de la largeur de la couronne.
const TRAVEL_ARC := 0.3
const ZOOM := 1.35
const SHINE_TIME := 0.6
## Balancement de la couronne 3D au repos : amplitude (degres) et periode (s).
const SWAY_DEGREES := 9.0
const SWAY_PERIOD := 4.0

@onready var _crown: Node3D = $SubViewport/Crown

## Rectangle global de la ligne d'un joueur.
var row_rect: Callable
var _index := -1
var _tween: Tween
var _travel_from := Vector2.ZERO
var _travel_progress := 1.0
var _crown_rest: Transform3D
var _time := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	rotation_degrees = TILT_DEGREES
	_crown_rest = _crown.transform
	visible = false

## Pose la couronne sur la ligne du joueur `index` (-1 : la cache). Si elle
## etait deja sur une autre ligne et que `animate` est vrai, elle y saute,
## puis zoom et reflet.
func show_on(index: int, animate: bool = true) -> void:
	if index == _index:
		return
	var previous := _index
	_index = index
	if index < 0 or not row_rect.is_valid():
		visible = false
		_stop_tween()
		return
	if previous < 0 or not visible or not animate:
		_stop_tween()
		visible = true
		_place(_target_center())
		return
	_stop_tween()
	_travel_from = _center()
	_travel_progress = 0.0
	_tween = create_tween()
	_tween.tween_method(_set_travel, 0.0, 1.0, TRAVEL_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_callback(celebrate)

## Petit zoom et reflet (fin d'un deplacement).
func celebrate() -> void:
	_stop_tween()
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2.ONE * ZOOM, 0.14) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_method(_set_shine, 0.0, 1.0, SHINE_TIME)
	var shader := material as ShaderMaterial
	shader.set_shader_parameter("flash", 1.0)
	_tween.parallel().tween_method(func(value: float) -> void:
		shader.set_shader_parameter("flash", value), 1.0, 0.0, 0.5)
	_tween.tween_callback(_set_shine.bind(-1.0))

func _process(delta: float) -> void:
	_time += delta
	var sway := deg_to_rad(SWAY_DEGREES) * sin(_time * TAU / SWAY_PERIOD)
	_crown.transform = Transform3D(Basis(Vector3.UP, sway) * _crown_rest.basis, _crown_rest.origin)
	if visible and _travel_progress >= 1.0:
		_place(_target_center())

func _set_travel(progress: float) -> void:
	_travel_progress = progress
	var target := _target_center()
	var arc := Vector2(-TRAVEL_ARC * _crown_size().x * sin(PI * progress), 0.0)
	_place(_travel_from.lerp(target, progress) + arc)

func _set_shine(value: float) -> void:
	(material as ShaderMaterial).set_shader_parameter("shine", value)

func _stop_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	_travel_progress = 1.0
	scale = Vector2.ONE
	_set_shine(-1.0)
	(material as ShaderMaterial).set_shader_parameter("flash", 0.0)

func _row() -> Rect2:
	return row_rect.call(_index) if _index >= 0 and row_rect.is_valid() else Rect2()

func _crown_size() -> Vector2:
	var height := maxf(_row().size.y * HEIGHT_RATIO, 40.0)
	return Vector2(height * ASPECT, height).round()

func _target_center() -> Vector2:
	var row := _row()
	return row.position + CORNER_OFFSET * _crown_size()

## Centre de la couronne, en coordonnees globales (position et pivot_offset
## sont dans le repere du parent, avant la rotation autour du pivot).
func _center() -> Vector2:
	return _parent_transform() * (position + pivot_offset)

## Place le centre de la couronne en `center` (coordonnees globales), en
## ajustant sa taille a celle de la ligne.
func _place(center: Vector2) -> void:
	var crown_size := _crown_size()
	if size != crown_size:
		size = crown_size
	pivot_offset = crown_size / 2.0
	position = _parent_transform().affine_inverse() * center - pivot_offset

func _parent_transform() -> Transform2D:
	var parent := get_parent() as CanvasItem
	return parent.get_global_transform() if parent != null else Transform2D.IDENTITY
