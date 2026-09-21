extends GameDefinition

func _init() -> void:
	id = "x01"
	name = "X01"
	image = "res://assets/game_selector/game_selector_301.png"
	screen_scene = preload("res://games/x01/x01_screen.tscn")
	max_players = 8
	options = [
		{
			"id": "start_value", "type": "enum", "name": "Game",
			"items": ["301", "501", "701", "1001"], "default": "501",
			"info": "Starting score. Each player counts down from this value to zero.",
		},
		{"type": "group", "name": "In / Out conditions"},
		{
			"id": "in_condition", "type": "enum", "name": "In",
			"items": ["None", "Double", "Triple", "Master"], "default": "None",
			"info": "Condition to start the game: a player's score only starts to count down once they hit a double (Double), a triple (Triple) or either of them (Master). None: any dart counts.",
		},
		{
			"id": "out_condition", "type": "enum", "name": "Out",
			"items": ["None", "Double", "Triple", "Master"], "default": "Double",
			"info": "Condition to finish the game: the last dart must reach exactly zero with a double (Double), a triple (Triple) or either of them (Master). None: any dart finishes.",
		},
	]
