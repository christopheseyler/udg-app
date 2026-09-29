class_name SpinBanner
extends TextureRect

## Grande image d'annonce (ex. "Bust!" du X01, "Auto Enter!" du 321 Zap) qui
## apparait en tourbillonnant et en grossissant tres vite, et finit par un
## rebond : quelques tours sur elle-meme en ralentissant, pendant qu'elle
## grossit depuis presque rien jusqu'a depasser sa taille puis s'y poser
## (courbe elastique). Masquee par defaut ; play() la montre, stop() la
## masque.

const START_SCALE := 0.05
const SPIN_TURNS := 2.0
const SPIN_DURATION := 0.45
const ZOOM_DURATION := 0.9

var _tween: Tween

func _init() -> void:
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

## Centre l'image dans son parent a la taille banner_size, decalee de
## offset (le pivot des animations est son centre).
func place_centered(banner_size: Vector2, offset: Vector2 = Vector2.ZERO) -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	offset_left = -banner_size.x / 2.0 + offset.x
	offset_right = banner_size.x / 2.0 + offset.x
	offset_top = -banner_size.y / 2.0 + offset.y
	offset_bottom = banner_size.y / 2.0 + offset.y
	pivot_offset = banner_size / 2.0

func play() -> void:
	stop()
	visible = true
	scale = Vector2.ONE * START_SCALE
	rotation = -TAU * SPIN_TURNS
	modulate.a = 0.0
	_tween = create_tween().set_parallel()
	_tween.tween_property(self, "rotation", 0.0, SPIN_DURATION) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2.ONE, ZOOM_DURATION) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate:a", 1.0, SPIN_DURATION / 3.0)

func stop() -> void:
	if _tween:
		_tween.kill()
		_tween = null
	visible = false
