extends Control

## Ecran titre : le titre apparait en fondu, reste affiche, puis
## disparait en fondu avec un zoom accelere pendant que le background
## s'assombrit, avant de basculer vers l'ecran de selection de jeu (qui
## demarre sur ce fond assombri). Un tap/clic saute directement a la suite.

@export var next_scene_path: String = "res://main_screens/game_selection/game_select.tscn"
@export var start_delay: float = 2.0
@export var fade_in_duration: float = 1.5
@export var hold_duration: float = 5.0
@export var fade_out_duration: float = 1.0
@export var zoom_out_scale: float = 20.0
@export var background_dark_color: Color = Color(0.55, 0.55, 0.55, 1.0)

@onready var background: TextureRect = $Background
@onready var title_image: TextureRect = $TitleImage

var _going_to_next_scene := false
var _preload_paths: Array[String] = []

func _ready() -> void:
	_preload_next_scene()
	title_image.modulate.a = 0.0
	title_image.pivot_offset = title_image.size / 2.0
	title_image.resized.connect(func(): title_image.pivot_offset = title_image.size / 2.0)

	var tween := create_tween()
	tween.tween_interval(start_delay)
	tween.tween_property(title_image, "modulate:a", 1.0, fade_in_duration)
	tween.tween_interval(hold_duration)
	tween.tween_property(title_image, "modulate:a", 0.0, fade_out_duration)
	tween.parallel().tween_property(title_image, "scale", Vector2.ONE * zoom_out_scale, fade_out_duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(background, "modulate", background_dark_color, fade_out_duration)
	tween.tween_callback(_go_to_next_scene)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_go_to_next_scene()
	elif event is InputEventMouseButton and event.pressed:
		_go_to_next_scene()

## Charge en arriere-plan la scene suivante et les images du carrousel
## pendant que le titre s'affiche : evite l'ecran gris cause par le
## chargement synchrone au moment du changement de scene. Les ressources
## sont gardees sur la racine du SceneTree pour survivre a cette scene.
func _preload_next_scene() -> void:
	_preload_paths = [next_scene_path]
	var game_select_script: GDScript = load("res://main_screens/game_selection/game_select.gd")
	for game in game_select_script.get_script_constant_map().get("GAMES", []):
		_preload_paths.append(game["image"])
	for path in _preload_paths:
		ResourceLoader.load_threaded_request(path)

func _go_to_next_scene() -> void:
	if _going_to_next_scene:
		return
	_going_to_next_scene = true

	var loaded := []
	for path in _preload_paths:
		while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await get_tree().process_frame
		loaded.append(ResourceLoader.load_threaded_get(path))

	get_tree().root.set_meta("preloaded_resources", loaded)
	get_tree().change_scene_to_packed(loaded[0])
