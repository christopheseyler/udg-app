class_name Zap321ScorePanel
extends PanelContainer

## Panneau de score du 321 Zap : une ligne par joueur avec son nom, la
## fleche du sens de son chemin (mode Both Ways : vers le haut de 0 a 321,
## vers le bas de 321 a 0), son score ("Out" tant qu'il n'est pas entre),
## l'eclair de zap (voir ZapBolt) et un texte d'aide. Le
## joueur en cours est mis en surbrillance. set_players() construit les
## lignes (et choisit les colonnes), set_row() met a jour un joueur,
## set_current_player() deplace la surbrillance.

## direction_arrows.png : 2 cases carrees identiques (vers le haut, vers le
## bas).
const ARROWS_ATLAS := preload("res://assets/games/321_zap/direction_arrows.png")

const NAME_FONT_SIZE := 56
const SCORE_FONT_SIZE := 64
const HINT_FONT_SIZE := 36
const SCORE_COLUMN_WIDTH := 200.0
const ICON_COLUMN_WIDTH := 96.0
const ICON_SIZE := Vector2(60, 60)
const CELL_PADDING := Vector2(24, 20)
const HIGHLIGHT_COLOR := Color(0.95, 0.75, 0.2, 0.38)
const NORMAL_COLOR := Color(1, 1, 1, 0.05)

@onready var grid: GridContainer = $Margin/Scroll/Grid

var _row_styles: Array[Array] = []
var _score_labels: Array[Label] = []
var _hint_labels: Array[Label] = []
var _arrows: Array[TextureRect] = []
var _bolts: Array[ZapBolt] = []
var _arrow_textures: Array[AtlasTexture] = []

func _ready() -> void:
	var cell_size := Vector2(ARROWS_ATLAS.get_width() / 2.0, ARROWS_ATLAS.get_height())
	for i in 2:
		var cell := AtlasTexture.new()
		cell.atlas = ARROWS_ATLAS
		cell.region = Rect2(Vector2(i * cell_size.x, 0), cell_size)
		_arrow_textures.append(cell)

## Construit une ligne par joueur. show_direction : colonne de la fleche de
## sens (Both Ways).
func set_players(names: Array[String], show_direction: bool) -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	_row_styles.clear()
	_score_labels.clear()
	_hint_labels.clear()
	_arrows.clear()
	_bolts.clear()
	grid.columns = 4 + int(show_direction)

	for player_name in names:
		var styles: Array[StyleBoxFlat] = []
		var name_label := _add_label_cell(player_name, NAME_FONT_SIZE, HORIZONTAL_ALIGNMENT_LEFT, styles)
		name_label.clip_text = true
		name_label.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.get_parent().size_flags_stretch_ratio = 3.0
		if show_direction:
			var arrow := TextureRect.new()
			arrow.custom_minimum_size = ICON_SIZE
			arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			arrow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			_add_cell(arrow, ICON_COLUMN_WIDTH, styles)
			_arrows.append(arrow)
		var score_label := _add_label_cell("", SCORE_FONT_SIZE, HORIZONTAL_ALIGNMENT_CENTER, styles)
		score_label.get_parent().custom_minimum_size.x = SCORE_COLUMN_WIDTH
		_score_labels.append(score_label)
		var bolt := ZapBolt.new()
		bolt.custom_minimum_size = ICON_SIZE
		_add_cell(bolt, ICON_COLUMN_WIDTH, styles)
		_bolts.append(bolt)
		var hint_label := _add_label_cell("", HINT_FONT_SIZE, HORIZONTAL_ALIGNMENT_LEFT, styles)
		hint_label.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hint_label.get_parent().size_flags_stretch_ratio = 4.0
		hint_label.modulate.a = 0.85
		_hint_labels.append(hint_label)
		_row_styles.append(styles)

## Met a jour la ligne d'un joueur. score_text : son score ou "Out" ;
## direction : +1 (vers 321), -1 (vers 0), 0 pour ne pas afficher de fleche ;
## zap_state : etat de l'eclair.
func set_row(index: int, score_text: String, direction: int, zap_state: ZapBolt.State, hint: String) -> void:
	_score_labels[index].text = score_text
	_hint_labels[index].text = hint
	if not _arrows.is_empty():
		_arrows[index].texture = null if direction == 0 else _arrow_textures[0 if direction > 0 else 1]
	_bolts[index].set_state(zap_state)

func set_current_player(index: int) -> void:
	for i in _row_styles.size():
		var color := HIGHLIGHT_COLOR if i == index else NORMAL_COLOR
		for style: StyleBoxFlat in _row_styles[i]:
			style.bg_color = color

func _add_label_cell(text: String, font_size: int, align: HorizontalAlignment, styles: Array[StyleBoxFlat]) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_add_cell(label, 0.0, styles)
	return label

## Ajoute une cellule (fond + contenu) a la grille ; min_width > 0 fixe sa
## largeur.
func _add_cell(content: Control, min_width: float, styles: Array[StyleBoxFlat]) -> PanelContainer:
	var style := StyleBoxFlat.new()
	style.bg_color = NORMAL_COLOR
	style.content_margin_left = CELL_PADDING.x
	style.content_margin_right = CELL_PADDING.x
	style.content_margin_top = CELL_PADDING.y
	style.content_margin_bottom = CELL_PADDING.y
	styles.append(style)

	var cell := PanelContainer.new()
	cell.add_theme_stylebox_override("panel", style)
	cell.custom_minimum_size.x = min_width
	grid.add_child(cell)
	cell.add_child(content)
	return cell
