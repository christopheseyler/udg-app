extends GameDefinition

## Regles detaillees : voir "cricket rules.txt" dans ce dossier.

func _init() -> void:
	id = "cricket"
	name = "Cricket"
	image = "res://assets/game_selector/game_selector_cricket.png"
	screen_scene = preload("res://games/cricket/cricket_screen.tscn")
	min_players = 2
	max_players = 8
	options = [
		{"type": "group", "name": "Game"},
		{
			"id": "mode", "type": "enum", "name": "Mode",
			"items": ["Cut-Throat", "Straight"], "default": "Cut-Throat",
			"info": "Close the 7 targets with 3 marks each (single = 1, double = 2, triple = 3). Extra marks on a target you closed score while other players still have it open. Straight: extra marks add to your own score; to win, close everything with the highest score. Cut-Throat: extra marks add to the score of every player who hasn't closed that target; to win, close everything with the lowest score.",
		},
		{
			"id": "targets", "type": "enum", "name": "Targets",
			"items": ["Classic", "Wild", "Ultra-Wild", "Wild & Crazy", "Ultra-Wild & Crazy"], "default": "Classic",
			"info": "Classic: 15 to 20 and the bull. Wild: 6 different random values between 12 and 20, plus the bull. Ultra-Wild: 6 different random values between 1 and 20, plus the bull. Crazy: at the start of every turn, the value of each target that has at least one mark but that nobody has closed yet changes (marks are kept). A target closed by a player keeps its value.",
		},
		{
			"id": "locked_bull", "type": "bool", "name": "Locked Bull",
			"default": false,
			"info": "A player can't mark the bull until they have closed their 6 other targets. Hitting a locked bull has no effect. The bull locks again if one of the other targets reopens.",
		},
		{"type": "group", "name": "Scoring"},
		{
			"id": "score_maniac", "type": "bool", "name": "Score Maniac",
			"default": false,
			"info": "Cut-Throat only. Points given to a player are multiplied by 3 if they have no mark on that target, by 2 with 1 mark and by 1 with 2 marks, on top of the dart's multiplier (triple 20 on a player without mark: 20 x 3 x 3 = 180).",
		},
		{
			"id": "protect_the_weaks", "type": "bool", "name": "Protect the Weaks",
			"default": false,
			"info": "Cut-Throat only. A player can only give points to players whose score is lower than or equal to their own. Protected players show a shield.",
		},
		{
			"id": "only_in_closing_turn", "type": "bool", "name": "Only in Closing Turn",
			"default": false,
			"info": "A player can only score on a target during the turn they closed it (extra marks of the closing dart score). Afterwards, hitting it counts as hitting a target closed by everyone (see All Closed Hit Penalty).",
		},
		{"type": "group", "name": "Penalties"},
		{
			"id": "elite", "type": "enum", "name": "Elite",
			"items": ["None", "Mark", "Mega Mark"], "default": "None",
			"info": "At the end of their turn, a player loses one mark on each of their open targets they didn't mark during the turn. A player who has closed every target (but hasn't won yet) and didn't make any valid hit (a mark or points) during their turn reopens one random closed target by one mark (Mark) or all of them (Mega Mark).",
		},
		{
			"id": "all_closed_penalty", "type": "enum", "name": "All Closed Hit Penalty",
			"items": ["None", "Score", "Mark"], "default": "None",
			"info": "Hitting a target closed by every player (including the extra marks of the dart closing it last). Score: the player gives themselves the points (lost in Straight, never below 0; added in Cut-Throat). Mark: the target reopens by the number of marks of the dart.",
		},
		{"type": "group", "name": "End of game"},
		{
			"id": "max_rounds", "type": "enum", "name": "Max Rounds",
			"items": ["8", "10", "12", "15", "20"], "default": "10",
			"info": "Maximum number of rounds. When it is reached, the game ends and players who haven't finished are ranked by their score (see Ending Rank).",
		},
		{
			"id": "end_at_first_finish", "type": "bool", "name": "End at First Finish",
			"default": true,
			"info": "On: the game ends as soon as a player wins. Off: players who win leave the game with their rank and the others keep playing, until only one player is left or the maximum number of rounds is reached. Players who left no longer count for anything.",
		},
		{
			"id": "ending_rank", "type": "enum", "name": "Ending Rank",
			"items": ["Score", "Score & Marks"], "default": "Score",
			"info": "How players who haven't finished are ranked at the end. Score: by their score. Score & Marks: each missing mark on a target they haven't closed counts its value, removed from the score in Straight, added to it in Cut-Throat.",
		},
		{"type": "group", "name": "Special / Fun"},
		{
			"id": "score_or_die", "type": "bool", "name": "Score or Die",
			"default": false,
			"info": "Every 4th round is a \"Score or Die\" round (skull). At its end, the player with the worst score (lowest in Straight, highest in Cut-Throat) is eliminated, all of them on a tie. Eliminations stop when 2 players are left, and are cancelled if they would leave fewer than 2 players. Eliminated players are ranked last.",
		},
	]
