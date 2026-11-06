class_name GameDefinition
extends RefCounted

## Definition d'un jeu, exposee a l'ecran de selection. Chaque jeu vit dans
## games/<nom_du_jeu>/ et etend cette classe en renseignant ses champs dans
## _init(). "logo_text", "logo_text_offset", "logo_decoration", "min_players", "max_players",
## "options", "uses_players_order" et "reverse_players_order" sont facultatifs (voir
## game_options.gd pour le
## format des options ; un jeu sans option desactive le bouton Options ;
## "uses_players_order" indique si le demarrage passe par l'ecran d'ordre de
## passage, vrai par defaut ; "reverse_players_order" inverse cet ordre : le
## joueur le plus proche du centre joue en dernier).

const DEFAULT_MAX_PLAYERS := 4

var id: String
var name: String
## Texte du logo 3D de l'ecran de selection, quand il differe du nom : un
## "\n" force un retour a la ligne, et une ligne entre crochets, comme
## "[the]", est plus petite (voir GameLogo3D.set_text()).
var logo_text: String
## Decalage du texte du logo par rapport a sa place habituelle, en metres
## (y vers le haut), comme le titre de Shanghai descendu pour laisser voir la
## calligraphie peinte sur la cible.
var logo_text_offset := Vector2.ZERO
## Decor ajoute au logo 3D, comme le hachoir plante dans la cible de Halve It :
## une scene placee dans le repere du logo, ou la cible est centree sur
## l'origine (rayon 0.2485 m), sa face avant en z = 0 vers la camera et son
## dos en z = -0.04 (voir GameLogo3D.set_text()). Ses noeuds LogoMover
## bougent : les flechettes de X01 flottent (LogoFloat), les aiguilles et les
## roues de Around the Clock tournent (LogoSpin). Ses lumieres LogoGlow, comme
## celle de l'eclair de 3-2-1 Zap, scintillent. Ses noeuds du groupe
## GameLogo3D.UNMERGED_GROUP, comme la marque du logo Cricket, restent tels
## quels.
var logo_decoration: PackedScene
var image: String
var min_players: int = 1
var max_players: int = DEFAULT_MAX_PLAYERS
var options: Array = []
var uses_players_order := true
var reverse_players_order := false
## Ecran de jeu (herite de GameScreen). Null tant que le jeu n'en a pas.
var screen_scene: PackedScene
