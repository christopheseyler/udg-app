extends GameDefinition

func _init() -> void:
	id = "halve_it"
	name = "Halve It"
	image = "res://assets/game_selector/game_selector_halve_it.png"
	screen_scene = preload("res://games/halve_it/halve_it_screen.tscn")
	max_players = 8
	uses_players_order = false
	options = [
		{
			"id": "game_mode", "type": "enum", "name": "Game Mode",
			"items": ["9 Rounds", "Extended"], "default": "9 Rounds",
			"info": "9 Rounds (15 to Bullseye): 15, 16, 17, Any Double, 18, 19, 20, Any Triple, Bullseye. Extended (12 to Bullseye): 12, 13, 14, Any Double, 15, 16, 17, Any Triple, 18, 19, 20, Bullseye.",
		},
		{
			"id": "starting_score", "type": "enum", "name": "Starting Score",
			"items": ["0", "40", "80"], "default": "0",
			"info": "Score every player begins the game with.",
		},
	]
