class_name ZapBolt
extends Control

## Eclair affiche sur la ligne d'un joueur : eteint tant qu'il n'a zappe
## personne, allume des qu'il a obtenu un zap. En mode Master Zap, quand il
## pourrait terminer sans avoir de zap (il lui en faut un pour sortir),
## l'eclair bat comme un coeur (double battement puis pause) pour l'avertir.
## L'image est dans un enfant anime : un conteneur parent (grille du panneau
## de score) remet l'echelle de ce controle a 1 a chaque mise en page.

enum State { OFF, ON, WARNING }

## zap_bolt_states.png : 3 cases carrees identiques (eteint, allume, pic de
## battement).
const ATLAS := preload("res://assets/games/321_zap/zap_bolt_states.png")
const CELL_COUNT := 3
const BEAT_SCALES: Array[float] = [1.3, 1.18]
const BEAT_UP_DURATION := 0.07
const BEAT_DOWN_DURATION := 0.13
const BEAT_GAP := 0.1
const BEAT_PAUSE := 0.6

var _image: TextureRect
var _cells: Array[AtlasTexture] = []
var _state := State.OFF
var _tween: Tween

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cell_size := Vector2(ATLAS.get_width() / float(CELL_COUNT), ATLAS.get_height())
	for i in CELL_COUNT:
		var cell := AtlasTexture.new()
		cell.atlas = ATLAS
		cell.region = Rect2(Vector2(i * cell_size.x, 0), cell_size)
		_cells.append(cell)
	_image = TextureRect.new()
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_image.set_anchors_preset(Control.PRESET_FULL_RECT)
	_image.texture = _cells[0]
	add_child(_image)
	resized.connect(func(): _image.pivot_offset = size / 2.0)

## N'anime que si l'etat change (appele a chaque rafraichissement de ligne).
func set_state(state: State) -> void:
	if state == _state:
		return
	_state = state
	if _tween:
		_tween.kill()
		_tween = null
	_image.scale = Vector2.ONE
	match state:
		State.OFF:
			_image.texture = _cells[0]
		State.ON:
			_image.texture = _cells[1]
		State.WARNING:
			_start_heartbeat()

## Double battement (pic lumineux + grossissement) puis pause, en boucle.
func _start_heartbeat() -> void:
	_image.texture = _cells[0]
	_tween = create_tween().set_loops()
	for beat_scale in BEAT_SCALES:
		_tween.tween_callback(func(): _image.texture = _cells[2])
		_tween.tween_property(_image, "scale", Vector2.ONE * beat_scale, BEAT_UP_DURATION) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_tween.tween_callback(func(): _image.texture = _cells[1])
		_tween.tween_property(_image, "scale", Vector2.ONE, BEAT_DOWN_DURATION) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_tween.tween_callback(func(): _image.texture = _cells[0])
		_tween.tween_interval(BEAT_GAP)
	_tween.tween_interval(BEAT_PAUSE)
