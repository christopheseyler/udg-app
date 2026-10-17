extends GameDefinition

func _init() -> void:
	id = "around_the_clock"
	name = "Around the Clock"
	image = "res://assets/game_selector/game_selector_around_the_clock.png"
	screen_scene = preload("res://games/around_the_clock/around_the_clock_screen.tscn")
	max_players = 8
	options = [
		{
			"id": "game_mode", "type": "enum", "name": "Game Mode",
			"items": ["Classic", "Classic Extended", "The Irish Way"], "default": "Classic",
			"info": "Classic: hit the numbers in order, from 1 to 20. Classic Extended: 1 to 20, then the Bull. The Irish Way: 1 to 20, then the Bull ; from 1 to 9, a double moves you 2 numbers ahead and a triple 3 ; on 10, a Double 10 takes you straight to the Bull ; you win by hitting 2 Bulls in the same turn (a Double Bull counts as 2).",
		},
		{"type": "group", "name": "End of game"},
		{
			"id": "max_rounds", "type": "enum", "name": "Max Rounds",
			"items": ["10", "12", "15", "20"], "default": "10",
			"info": "Maximum number of rounds. When it is reached, the game ends and players who haven't finished are ranked by the target they reached (furthest first).",
		},
		{
			"id": "end_at_first_finish", "type": "bool", "name": "End at First Finish",
			"default": true,
			"info": "On: the game ends as soon as a player finishes, who wins. Off: players who finish leave the game with their rank (1st, 2nd...) and the others keep playing, until everyone has finished or the maximum number of rounds is reached. In The Irish Way, a player finishing after the Double 10 shortcut always ends the game.",
		},
	]
