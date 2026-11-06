extends GameDefinition

func _init() -> void:
	id = "shanghai"
	name = "Shanghai"
	image = "res://assets/game_selector/game_selector_shanghai.png"
	logo_decoration = preload("res://games/shanghai/shanghai_logo_paint.tscn")
	logo_text_offset = Vector2(0.0, -0.045)
