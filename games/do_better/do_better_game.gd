extends GameDefinition

## Beat the King, if you can (anciennement Do Better If You Can ; l'id, les
## fichiers et les classes gardent l'ancien nom). Regles dans DoBetterRules.

## Regles affichees par le panneau Rules (syntaxe : voir MarkdownView).
const RULES := """
# Beat the King, if you can
Beat the **king** of the round on the target they chose. The player with the most **points** at the end wins.

## Round
1. The **king** throws first: their **first dart sets the target** of the round.
2. Their 3 darts, the first one included, give the **marks to beat**.
3. Each other player then throws **3 darts** at the same target, in order:
   - more marks than the king: **+1 point for the player**;
   - fewer marks: **+1 point for the king**;
   - a tie: no point.

The king role moves to the next player every round: everyone is king the same number of times (unless *Keep the Crown* is on).

## The crown
The king wears the **crown**. Without *Get the Crown*, the first king keeps it, and their marks stay the marks to beat, for the whole round.

## Marks
- On a number: single = **1**, double = **2**, triple = **3**. A first dart in the triple 20 sets the target to 20 and already scores 3 marks.
- On the bull: outer bull = **1**, bull = **2**.
- If the king's first dart misses the board, the target is **Miss**: every missed dart scores 1 mark.
- Darts outside the target score nothing.

## Get the Crown (option)
- A player who beats the **current king** scores 1 point, **takes the crown** and becomes the king: their marks become the marks to beat. The target never changes.
- A tie: the king keeps the crown, and nobody scores.
- If the first king lost the crown, they get a **last turn** after everyone else:
  - better: they take the crown back, score 1 point and **take back every point** the other players scored during this round;
  - worse: the current king scores 1 point;
  - a tie: no point.

## Keep the Crown (option)
The king role no longer moves to the next player: the player wearing the **crown at the end of a round** is the **king of the next round**. A king keeps the crown as long as nobody takes it (with *Get the Crown*; without it, the first king keeps it for the whole game).

## End of game
After the last round, the player with the most points wins. Players with the same points share the same place.
"""

func _init() -> void:
	id = "do_better"
	name = "Beat the King, if you can"
	rules = RULES
	logo_text = "Beat the King\n[if you can]"
	logo_decoration = preload("res://games/do_better/do_better_logo.tscn")
	screen_scene = preload("res://games/do_better/do_better_screen.tscn")
	min_players = 2
	max_players = 8
	options = [
		{
			"id": "rounds_per_player", "type": "enum", "name": "Rounds per Player",
			"items": ["1", "2", "3", "4"], "default": "2",
			"info": "The game has this many rounds **per player** (e.g. 2 with 4 players: 8 rounds), so that everyone is the first king the same number of times (unless Keep the Crown is on).",
		},
		{
			"id": "get_the_lead", "type": "bool", "name": "Get the Crown",
			"default": false,
			"info": "**Off**: the first king keeps the crown, and their marks stay the marks to beat, for the whole round.\n\n**On**: a player who beats the current king scores 1 point and **takes the crown**; their marks become the marks to beat (the target doesn't change). A tie: the king keeps the crown, no point. If the first king lost the crown, they get a last turn: if they do better, they take the crown back, score 1 point and take back every point the other players scored during the round; if they do worse, the current king scores 1 point.",
		},
		{
			"id": "keep_the_crown", "type": "bool", "name": "Keep the Crown",
			"default": false,
			"info": "**Off**: the king role moves to the next player every round.\n\n**On**: the king at the end of a round is the **king of the next round**. With Get the Crown, a king keeps the crown as long as nobody beats them; without it, the first king keeps it for the whole game.",
		},
	]
