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
			"items": ["Open In", "Double In", "Triple In", "Master In"], "default": "Open In",
			"info": "Condition to start the game: a player's score only starts to count down once they hit a double (Double In), a triple (Triple In) or either of them (Master In). Open In: any dart counts.",
		},
		{
			"id": "out_condition", "type": "enum", "name": "Out",
			"items": ["Open Out", "Double Out", "Triple Out", "Master Out"], "default": "Double Out",
			"info": "Condition to finish the game: the last dart must reach exactly zero with a double (Double Out), a triple (Triple Out) or either of them (Master Out). Open Out: any dart finishes.",
		},
		{"type": "group", "name": "Special / Fun"},
		{
			"id": "same_score_hit", "type": "enum", "name": "Same Score Hit",
			"items": ["Nothing", "Wipe-Out", "Give-me your darts"], "default": "Nothing",
			"info": "What happens when a player's score becomes equal to another player's score. Nothing: no effect. Wipe-Out: the other player's score falls back to 0 (they stay in the game, no need to re-enter). Give-me your darts: the other player hands over darts (1 for a single, 2 for a double, 3 for a triple that caused the tie), which can be thrown right away in the same turn ; those darts are deducted from the other player's next turn, at worst skipping it entirely if 3 or more are owed. This stacks if several players tie into the same score before that player's turn comes up, and at most 3 owed darts are cleared each round.",
		},
	]
