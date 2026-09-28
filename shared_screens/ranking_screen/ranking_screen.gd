class_name RankingScreen
extends Control

## Ecran de classement de fin de partie : le podium en haut, avec le nom des
## joueurs des trois premieres places pose sur leur marche (plusieurs noms
## sur une meme marche en cas d'egalite), puis une grille de tous les
## joueurs du premier au dernier : rang (icone de coupe pour les trois
## premiers), nom, score final et une colonne de statistiques de jeu libres
## (texte fourni par le jeu). show_standings() l'affiche ; continue_pressed
## est emis quand le joueur le ferme.

signal continue_pressed

const RANK_ICONS: Array[Texture2D] = [
	preload("res://assets/game_screen/ranking/icon_1.png"),
	preload("res://assets/game_screen/ranking/icon_2.png"),
	preload("res://assets/game_screen/ranking/icon_3.png"),
]

## Position des marches dans podium.png, en fraction de l'image, dans
## l'ordre des rangs (1, 2, 3) : centre horizontal de la marche et haut de
## son plateau (le nom est pose juste au-dessus).
const STEP_ANCHORS: Array[Vector2] = [Vector2(0.502, 0.18), Vector2(0.186, 0.345), Vector2(0.812, 0.425)]
## Largeur d'un nom sur le podium, en fraction de la largeur de l'image
## (un peu plus large qu'une marche : les noms voisins sont a des hauteurs
## differentes), et ecart entre le nom et le plateau de sa marche.
const STEP_NAME_WIDTH := 0.36
const STEP_NAME_GAP := 4.0
const PODIUM_NAME_FONT_SIZE := 52

const HEADER_FONT_SIZE := 32
const NAME_FONT_SIZE := 44
const SCORE_FONT_SIZE := 48
const STATS_FONT_SIZE := 34
const RANK_FONT_SIZE := 44
const RANK_COLUMN_WIDTH := 150.0
const SCORE_COLUMN_WIDTH := 220.0
const RANK_ICON_SIZE := Vector2(64, 64)
const CELL_PADDING := Vector2(24, 8)
const ROW_COLOR := Color(1, 1, 1, 0.05)
const WINNER_ROW_COLOR := Color(0.95, 0.75, 0.2, 0.28)

@onready var podium: Control = $Margin/Content/Podium
@onready var podium_image: TextureRect = $Margin/Content/Podium/PodiumImage
@onready var grid: GridContainer = $Margin/Content/Panel/Margin/Scroll/Grid
@onready var continue_button: Button = $Margin/Content/Podium/ContinueButton

var _step_labels: Array[Label] = []

func _ready() -> void:
	visible = false
	continue_button.pressed.connect(func(): continue_pressed.emit())
	for i in STEP_ANCHORS.size():
		var label := Label.new()
		label.add_theme_font_size_override("font_size", PODIUM_NAME_FONT_SIZE)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 14)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		podium.add_child(label)
		_step_labels.append(label)
	podium_image.resized.connect(_layout_podium)

## Affiche le classement. standings : un Dictionary par joueur, deja trie du
## premier au dernier (voir GameScreen.rank_standings) : "name", "rank"
## (les ex aequo partagent le meme), "score" et "stats" (texte libre,
## facultatif).
func show_standings(standings: Array[Dictionary]) -> void:
	for i in _step_labels.size():
		var names := PackedStringArray()
		for entry in standings:
			if entry.rank == i + 1:
				names.append(entry.name)
		_step_labels[i].text = "\n".join(names)
	_build_grid(standings)
	visible = true
	_layout_podium()

## Pose chaque nom au-dessus de sa marche, d'apres le rectangle ou l'image
## du podium est reellement affichee (centree en gardant ses proportions).
func _layout_podium() -> void:
	var texture_size := podium_image.texture.get_size()
	var box := podium_image.size
	var scale_factor := minf(box.x / texture_size.x, box.y / texture_size.y)
	var shown_size := texture_size * scale_factor
	var image_rect := Rect2(podium_image.position + (box - shown_size) / 2.0, shown_size)
	for i in _step_labels.size():
		var anchor := STEP_ANCHORS[i]
		var width := STEP_NAME_WIDTH * image_rect.size.x
		var step_top := image_rect.position.y + anchor.y * image_rect.size.y
		var label := _step_labels[i]
		var font_size := _fit_font_size(label, width)
		label.add_theme_font_size_override("font_size", font_size)
		# Hauteur du texte (une ligne par ex aequo), pose sur le plateau.
		var lines := label.text.split("\n").size()
		var height := label.get_theme_font("font").get_height(font_size) * lines
		label.size = Vector2(width, height)
		label.position = Vector2(
			image_rect.position.x + anchor.x * image_rect.size.x - width / 2.0,
			step_top - STEP_NAME_GAP - height
		)

## Taille de police des noms d'une marche : PODIUM_NAME_FONT_SIZE, reduite
## pour que le nom le plus long (contour compris) tienne dans width plutot
## que d'etre coupe.
func _fit_font_size(label: Label, width: float) -> int:
	var font := label.get_theme_font("font")
	var widest := 0.0
	for line in label.text.split("\n"):
		widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, PODIUM_NAME_FONT_SIZE).x)
	widest += label.get_theme_constant("outline_size")
	if widest <= width:
		return PODIUM_NAME_FONT_SIZE
	return maxi(floori(PODIUM_NAME_FONT_SIZE * width / widest), 1)

func _build_grid(standings: Array[Dictionary]) -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()

	for title in ["Rank", "Player", "Score", "Stats"]:
		var header := _add_label_cell(title, HEADER_FONT_SIZE, Color.TRANSPARENT)
		header.modulate.a = 0.7
	_set_column_layout(grid.get_child_count() - 4)

	for entry in standings:
		var color := WINNER_ROW_COLOR if entry.rank == 1 else ROW_COLOR
		var first := grid.get_child_count()
		_add_rank_cell(entry.rank, color)
		_add_label_cell(entry.name, NAME_FONT_SIZE, color)
		_add_label_cell(str(entry.score), SCORE_FONT_SIZE, color)
		var stats := _add_label_cell(entry.get("stats", ""), STATS_FONT_SIZE, color)
		stats.get_parent().modulate.a = 0.85
		_set_column_layout(first)

## Largeur des 4 cellules d'une ligne (commencant a l'enfant first) : rang
## et score de largeur fixe, nom et stats etires ; rang et score centres.
func _set_column_layout(first: int) -> void:
	var cells := grid.get_children().slice(first, first + 4)
	cells[0].custom_minimum_size.x = RANK_COLUMN_WIDTH
	cells[1].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cells[1].size_flags_stretch_ratio = 3.0
	cells[2].custom_minimum_size.x = SCORE_COLUMN_WIDTH
	cells[3].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cells[3].size_flags_stretch_ratio = 2.0
	for index in [0, 2]:
		var label := cells[index].get_child(0) as Label
		if label:
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

## Cellule de rang : icone de coupe pour les trois premiers, "#x" sinon.
func _add_rank_cell(rank: int, color: Color) -> void:
	if rank < 1 or rank > RANK_ICONS.size():
		_add_label_cell("#%d" % rank, RANK_FONT_SIZE, color)
		return
	var cell := _add_cell(color)
	var icon := TextureRect.new()
	icon.texture = RANK_ICONS[rank - 1]
	icon.custom_minimum_size = RANK_ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cell.add_child(icon)

func _add_label_cell(text: String, font_size: int, color: Color) -> Label:
	var cell := _add_cell(color)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	cell.add_child(label)
	return label

func _add_cell(color: Color) -> PanelContainer:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.content_margin_left = CELL_PADDING.x
	style.content_margin_right = CELL_PADDING.x
	style.content_margin_top = CELL_PADDING.y
	style.content_margin_bottom = CELL_PADDING.y
	var cell := PanelContainer.new()
	cell.add_theme_stylebox_override("panel", style)
	grid.add_child(cell)
	return cell
