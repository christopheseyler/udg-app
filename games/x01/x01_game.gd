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
		{"type": "group", "name": "End of game"},
		{
			"id": "max_rounds", "type": "enum", "name": "Max Rounds",
			"items": ["10", "15", "20", "25", "30", "50"], "default": "50",
			"info": "Maximum number of rounds. When it is reached, the game ends and players still in the game are ranked by their remaining score (lowest first).",
		},
		{
			"id": "end_at_first_finish", "type": "bool", "name": "End at First Finish",
			"default": true,
			"info": "On: the game ends as soon as a player reaches zero, who wins. Off: players who reach zero leave the game with their rank (1st, 2nd...) and the others keep playing, until only one player is left or the maximum number of rounds is reached.",
		},
		{"type": "group", "name": "Special / Fun"},
		{
			"id": "same_score_hit", "type": "enum", "name": "Same Score Hit",
			"items": ["Nothing", "Wipe-Out", "Give-me your darts"], "default": "Nothing",
			"info": "What happens when a player's score becomes equal to another player's score. Nothing: no effect. Wipe-Out: the other player's score falls back to 0 (they stay in the game, no need to re-enter). Give-me your darts: the other player hands over darts (1 for a single, 2 for a double, 3 for a triple that caused the tie), which can be thrown right away in the same turn ; those darts are deducted from the other player's next turn, at worst skipping it entirely if 3 or more are owed. This stacks if several players tie into the same score before that player's turn comes up, and at most 3 owed darts are cleared each round.",
		},
	]
