extends Control

## Ecran titre : fait apparaitre le titre en fondu, puis bascule
## automatiquement vers l'ecran de selection de jeu. Un tap/clic
## n'importe ou permet de sauter directement a la suite.

@export var next_scene_path: String = "res://game_select.tscn"
@export var start_delay: float = 3.0
@export var fade_in_duration: float = 1.5
@export var hold_duration: float = 5.0
@export var fade_out_duration: float = 1.0
@export var zoom_out_scale: float = 20

@onready var title_image: TextureRect = $TitleImage

var _going_to_next_scene := false

func _ready() -> void:
	title_image.modulate.a = 0.0
	title_image.pivot_offset = title_image.size / 2.0
	var tween := create_tween()
	tween.tween_interval(start_delay)
	tween.tween_property(title_image, "modulate:a", 1.0, fade_in_duration)
	tween.tween_interval(hold_duration)
	tween.set_parallel(true)
	tween.tween_property(title_image, "modulate:a", 0.0, fade_out_duration)
	tween.tween_property(title_image, "scale", Vector2.ONE * zoom_out_scale, fade_out_duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.set_parallel(false)
	tween.tween_callback(_go_to_next_scene)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_go_to_next_scene()
	elif event is InputEventMouseButton and event.pressed:
		_go_to_next_scene()

func _go_to_next_scene() -> void:
	if _going_to_next_scene:
		return
	_going_to_next_scene = true
	get_tree().change_scene_to_file(next_scene_path)
