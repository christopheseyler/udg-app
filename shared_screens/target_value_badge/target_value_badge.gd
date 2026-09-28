class_name TargetValueBadge
extends Control

## Affiche un jet dans les jeux a cibles definies (Halve It, Around the
## Clock, Shanghai, Cricket, 321 Zap...) : soit l'image "MISSED" (jet rate),
## soit une petite medaille montrant la valeur visee (segment, 1-20 ou 25
## pour le bull) et son multiplicateur (simple, double, triple, bull simple,
## bull double). La medaille est neutre quand le jet ne compte pas pour le
## score du joueur, doree ("highlight") quand il compte : voir show_hit().

const MISSED_TEXTURE := preload("res://assets/game_screen/target_missed.png")
const BACKGROUND_ATLAS := preload("res://assets/game_screen/target_background_atlas.png")
const VALUES_ATLAS := preload("res://assets/game_screen/target_values_full_atlas.png")

## target_background_atlas.png : une colonne par type de medaille (voir
## Badge), neutre en haut, highlight en bas. Les plaques ne sont pas placees
## au meme endroit dans leurs cases (la plaque neutre est en bas de sa case,
## la doree en haut) : bornes exactes de chaque plaque mesurees pixel par
## pixel dans l'image, sans le halo autour.
const PLATE_REGIONS := [
	[Rect2(22, 117, 405, 238), Rect2(449, 117, 408, 238), Rect2(879, 117, 413, 238),
		Rect2(1313, 118, 415, 237), Rect2(1751, 118, 400, 237)],
	[Rect2(22, 373, 405, 236), Rect2(449, 373, 410, 237), Rect2(879, 373, 413, 237),
		Rect2(1310, 373, 418, 237), Rect2(1749, 373, 401, 237)],
]

## target_values_full_atlas.png : 7 colonnes x 3 lignes ([1..7], [8..14],
## [15..20, BullEye]), neutre (lignes 0-2) puis highlight (lignes 3-5).
## Genere par IA, ce n'est pas une vraie grille : boite exacte de chaque
## valeur mesuree pixel par pixel (hors halo), voir _value_region.
const GLYPH_REGIONS := [
	[Rect2(109, 18, 75, 120), Rect2(355, 16, 112, 119), Rect2(616, 15, 112, 125), Rect2(876, 16, 126, 121),
		Rect2(1145, 17, 113, 124), Rect2(1410, 16, 118, 126), Rect2(1712, 18, 103, 120)],
	[Rect2(92, 154, 113, 120), Rect2(352, 153, 112, 121), Rect2(585, 155, 171, 118), Rect2(865, 157, 139, 113),
		Rect2(1111, 155, 171, 116), Rect2(1382, 156, 168, 117), Rect2(1671, 158, 173, 113)],
	[Rect2(56, 290, 177, 118), Rect2(318, 287, 179, 121), Rect2(580, 289, 176, 116), Rect2(843, 287, 180, 121),
		Rect2(1106, 287, 179, 121), Rect2(1362, 288, 206, 120), Rect2(1654, 312, 199, 83)],
	[Rect2(108, 438, 77, 119), Rect2(354, 437, 113, 117), Rect2(615, 436, 112, 122), Rect2(872, 436, 128, 120),
		Rect2(1144, 437, 112, 122), Rect2(1409, 438, 116, 121), Rect2(1711, 439, 105, 120)],
	[Rect2(90, 563, 117, 117), Rect2(352, 562, 113, 118), Rect2(584, 563, 172, 116), Rect2(864, 565, 140, 112),
		Rect2(1112, 564, 174, 114), Rect2(1380, 565, 173, 115), Rect2(1669, 566, 173, 112)],
	[Rect2(58, 682, 178, 119), Rect2(318, 682, 180, 119), Rect2(581, 684, 177, 114), Rect2(844, 682, 182, 119),
		Rect2(1104, 682, 178, 120), Rect2(1355, 683, 207, 120), Rect2(1652, 703, 200, 85)],
]
## Bandes verticales de chaque ligne de valeurs : la marge ajoutee autour
## d'une valeur (GLYPH_PADDING, pour garder le bord adouci du contour) ne
## doit jamais deborder dessus : les lignes highlight 8-14 et 15-20 se
## touchent dans l'image (le bas des chiffres du dessus deborde de 1-2 px
## dans le haut de 15-20, d'ou une bande qui ne commence qu'a 682).
const GLYPH_ROW_BANDS := [
	Vector2(0, 147), Vector2(147, 280), Vector2(280, 422),
	Vector2(422, 560), Vector2(560, 680), Vector2(682, 821),
]
const GLYPH_PADDING := 3.0
## Hauteur (dans l'atlas) d'un chiffre : sert d'etalon pour que toutes les
## valeurs soient affichees a la meme echelle (un "1" etroit n'est pas
## agrandi pour remplir la place d'un "20").
const DIGIT_HEIGHT := 120.0
## Hauteur d'un chiffre affiche, en fraction de la hauteur de la plaque.
const VALUE_HEIGHT_RATIO := 0.38

## Zone horizontale (fraction de la largeur de la plaque) ou la valeur est
## centree : toute la plaque quand il n'y a pas d'icone de multiplicateur
## (SINGLE), a droite de l'icone sinon.
const VALUE_ZONE_FULL := Vector2(0.08, 0.92)
const VALUE_ZONE_RIGHT := Vector2(0.54, 0.91)

enum Badge { SINGLE, DOUBLE, TRIPLE, SINGLE_BULL, DOUBLE_BULL }

@onready var background: TextureRect = $Background
@onready var value: TextureRect = $Value
@onready var missed: TextureRect = $Missed

var _badge := Badge.SINGLE

func _ready() -> void:
	missed.texture = MISSED_TEXTURE
	_hide_all()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_layout_value()

## Affiche l'image "MISSED" (jet rate ou hors cible selon le jeu).
func show_missed() -> void:
	_hide_all()
	missed.visible = true

## Vide le badge (aucun jet a cet emplacement, ex. fleche pas encore lancee).
func clear() -> void:
	_hide_all()

## Affiche le jet hit sous forme de medaille : segment (1-20, ou 25 pour le
## bull) et multiplicateur (1 simple, 2 double, 3 triple ; au bull, 2 = bull
## double). highlighted = ce jet compte pour le score du joueur (medaille
## doree) sinon medaille neutre (grise). Un jet manque (hit.is_miss())
## affiche directement "MISSED".
func show_hit(hit: DartHit, highlighted: bool) -> void:
	if hit.is_miss():
		show_missed()
		return
	_hide_all()
	background.visible = true
	value.visible = true
	_badge = _badge_for(hit)
	background.texture = _atlas_region(BACKGROUND_ATLAS, PLATE_REGIONS[1 if highlighted else 0][_badge])
	value.texture = _value_region(hit.segment, highlighted)
	_layout_value()

func _hide_all() -> void:
	missed.visible = false
	background.visible = false
	value.visible = false

func _badge_for(hit: DartHit) -> Badge:
	if hit.segment == DartHit.BULL:
		return Badge.DOUBLE_BULL if hit.multiplier == 2 else Badge.SINGLE_BULL
	match hit.multiplier:
		3: return Badge.TRIPLE
		2: return Badge.DOUBLE
		_: return Badge.SINGLE

## Place la valeur sur la plaque, a une echelle commune a toutes les valeurs
## (voir DIGIT_HEIGHT), reduite seulement si elle ne tient pas dans sa zone.
## La plaque est affichee centree en gardant ses proportions (voir la scene),
## on recalcule donc ici le rectangle qu'elle occupe reellement.
func _layout_value() -> void:
	if background.texture == null or value.texture == null:
		return
	var plate_size: Vector2 = background.texture.get_size()
	var plate_scale := minf(size.x / plate_size.x, size.y / plate_size.y)
	var plate := Rect2((size - plate_size * plate_scale) / 2.0, plate_size * plate_scale)

	var zone := VALUE_ZONE_FULL if _badge == Badge.SINGLE else VALUE_ZONE_RIGHT
	var zone_left := plate.position.x + zone.x * plate.size.x
	var zone_width := (zone.y - zone.x) * plate.size.x

	var glyph_size: Vector2 = value.texture.get_size()
	var glyph_scale := plate.size.y * VALUE_HEIGHT_RATIO / DIGIT_HEIGHT
	glyph_scale = minf(glyph_scale, zone_width / glyph_size.x)
	value.size = glyph_size * glyph_scale
	value.position = Vector2(
		zone_left + (zone_width - value.size.x) / 2.0,
		plate.position.y + (plate.size.y - value.size.y) / 2.0
	)

func _atlas_region(atlas: Texture2D, rect: Rect2) -> AtlasTexture:
	var region := AtlasTexture.new()
	region.atlas = atlas
	region.region = rect
	return region

## Valeur (1-20, ou 25 pour le bull -> case BullEye) recadree a sa boite
## mesuree (voir GLYPH_REGIONS), agrandie de GLYPH_PADDING sans jamais sortir
## de sa ligne (voir GLYPH_ROW_BANDS).
func _value_region(segment: int, highlighted: bool) -> AtlasTexture:
	var cell := _value_cell(segment)
	var row := (3 if highlighted else 0) + cell.x
	var rect: Rect2 = GLYPH_REGIONS[row][cell.y].grow(GLYPH_PADDING)
	var band: Vector2 = GLYPH_ROW_BANDS[row]
	var top := maxf(rect.position.y, band.x)
	var bottom := minf(rect.end.y, band.y)
	return _atlas_region(VALUES_ATLAS, Rect2(rect.position.x, top, rect.size.x, bottom - top))

## Position (ligne 0-2, colonne 0-6) d'une valeur dans le bloc de 7x3 (voir
## GLYPH_REGIONS) : BullEye occupe la derniere case (segment bull).
func _value_cell(segment: int) -> Vector2i:
	if segment == DartHit.BULL:
		return Vector2i(2, 6)
	var index := segment - 1
	return Vector2i(index / 7, index % 7)
