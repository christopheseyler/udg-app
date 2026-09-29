extends GameDefinition

## Regles detaillees : voir "321 zap rules.txt" dans ce dossier.

func _init() -> void:
	id = "321_zap"
	name = "3-2-1 Zap"
	image = "res://assets/game_selector/game_selector_321_zap.png"
	screen_scene = preload("res://games/321_zap/zap_321_screen.tscn")
	min_players = 2
	max_players = 8
	reverse_players_order = true
	options = [
		{"type": "group", "name": "In / Out conditions"},
		{
			"id": "in_condition", "type": "enum", "name": "In",
			"items": ["Open In", "Double In", "Triple In", "Master In"], "default": "Open In",
			"info": "Condition to enter the game: a player's darts only start to count once they hit a double (Double In), a triple (Triple In) or either of them (Master In). Open In: any scoring dart enters. The entering dart counts. A missed dart never enters.",
		},
		{
			"id": "auto_entering", "type": "bool", "name": "Auto Entering",
			"default": false,
			"info": "A player who has not entered at the end of their turn enters automatically with a random dart satisfying the In condition.",
		},
		{
			"id": "out_condition", "type": "enum", "name": "Out",
			"items": ["Open Out", "Double Out", "Triple Out", "Master Out"], "default": "Open Out",
			"info": "Condition to finish: the dart reaching exactly 321 (or 0 on a reversed path) must be a double (Double Out), a triple (Triple Out) or either of them (Master Out). Otherwise the player is \"Zop\" (see Zop Behavior). Open Out: any dart finishes.",
		},
		{
			"id": "master_zap", "type": "bool", "name": "Master Zap",
			"default": false,
			"info": "Players must have zapped at least one player to finish. Reaching the target without any zap makes the player \"Zop\". Zaps stay acquired until the end of the game.",
		},
		{"type": "group", "name": "Bounce / Zap"},
		{
			"id": "both_ways", "type": "bool", "name": "Both Ways",
			"default": false,
			"info": "The entering dart decides the path: even segment number (the multiplier doesn't matter), from 0 up to 321; odd segment number (bull included), from 321 down to 0. The path is decided again each time the player enters.",
		},
		{
			"id": "continue_after_bounce", "type": "bool", "name": "Continue After Bounce",
			"default": false,
			"info": "Off: bouncing off the target ends the player's turn. On: the player keeps throwing their remaining darts.",
		},
		{
			"id": "auto_zap", "type": "bool", "name": "Auto-Zap",
			"default": false,
			"info": "A player who bounces back exactly onto the score they had before the dart (e.g. double 20 from 301) zaps themselves: they are Out and must enter again. It counts as a zap for Master Zap.",
		},
		{
			"id": "zop_behavior", "type": "enum", "name": "Zop Behavior",
			"items": ["Bust", "Nothing", "Auto-Zap"], "default": "Bust",
			"info": "What happens when a player reaches the target without meeting the Out condition or Master Zap. Bust: that dart is cancelled and the turn ends. Nothing: the player stays on the target and the turn ends; they must score to bounce off it. Auto-Zap: the player gets a zap but is Out and must enter again.",
		},
		{"type": "group", "name": "End of game"},
		{
			"id": "max_rounds", "type": "enum", "name": "Max Rounds",
			"items": ["8", "10", "12", "15", "20"], "default": "10",
			"info": "Maximum number of rounds. When it is reached, the game ends and players still in the game are ranked by their distance to their target (smallest first).",
		},
		{
			"id": "end_at_first_finish", "type": "bool", "name": "End at First Finish",
			"default": true,
			"info": "On: the game ends as soon as a player finishes, who wins. Off: players who finish leave the game with their rank and the others keep playing, until only one player is left or the maximum number of rounds is reached.",
		},
	]
