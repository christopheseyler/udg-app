class_name X01ScorePanel
extends PanelContainer

## Panneau de score du X01 : une grille a 3 colonnes (nom du joueur, score,
## texte indiquant ce qu'il doit faire, ex. "Need a master to enter"), une
## ligne par joueur. Le joueur en cours est mis en surbrillance. Une gommette
## (DebtBadge) se pose sur le nom du joueur qui a des fleches en dette
## (mode "Give-me your darts", voir set_debt).
## set_players() construit les lignes, set_row() met a jour score et texte
## d'un joueur, set_current_player() deplace la surbrillance.

const DEBT_BADGE := preload("res://games/x01/debt_badge.tscn")
## Taille et marge de la gommette de dette, posee dans le coin haut-droit de
## la cellule du nom (voir _add_name_cell).
const DEBT_BADGE_SIZE := 56.0
const DEBT_BADGE_MARGIN := 8.0

const NAME_FONT_SIZE := 56
const SCORE_FONT_SIZE := 64
const HINT_FONT_SIZE := 36
const SCORE_COLUMN_WIDTH := 240.0
const CELL_PADDING := Vector2(24, 20)
const HIGHLIGHT_COLOR := Color(0.95, 0.75, 0.2, 0.38)
const NORMAL_COLOR := Color(1, 1, 1, 0.05)

@onready var grid: GridContainer = $Margin/Scroll/Grid

var _row_styles: Array[Array] = []
var _score_labels: Array[Label] = []
var _hint_labels: Array[Label] = []
var _debt_badges: Array[DebtBadge] = []

func set_players(names: Array[String]) -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	_row_styles.clear()
	_score_labels.clear()
	_hint_labels.clear()
	_debt_badges.clear()

	for player_name in names:
		var styles: Array[StyleBoxFlat] = []
		_debt_badges.append(_add_name_cell(player_name, styles))
		_score_labels.append(_add_cell("", SCORE_FONT_SIZE, HORIZONTAL_ALIGNMENT_CENTER, 0.0, SCORE_COLUMN_WIDTH, styles))
		var hint_label := _add_cell("", HINT_FONT_SIZE, HORIZONTAL_ALIGNMENT_LEFT, 4.0, 0.0, styles)
		hint_label.modulate.a = 0.85
		_hint_labels.append(hint_label)
		_row_styles.append(styles)

func set_row(index: int, score: int, hint: String) -> void:
	_score_labels[index].text = str(score)
	_hint_labels[index].text = hint

## Affiche/masque/met a jour la gommette de fleches perdues du joueur
## (debt <= 0 la masque). Voir DebtBadge pour les animations.
func set_debt(index: int, debt: int) -> void:
	_debt_badges[index].set_debt(debt)

func set_current_player(index: int) -> void:
	for i in _row_styles.size():
		var color := HIGHLIGHT_COLOR if i == index else NORMAL_COLOR
		for style: StyleBoxFlat in _row_styles[i]:
			style.bg_color = color

## Ajoute la cellule "nom du joueur" a la grille : comme _add_cell, mais
## enveloppee dans un Control simple (pas un autre PanelContainer) pour
## pouvoir y poser la gommette de dette en overlay, ancree dans son coin
## haut-droit, sans qu'elle soit etiree au fond de la cellule comme le
## ferait un second enfant direct d'un PanelContainer.
func _add_name_cell(player_name: String, styles: Array[StyleBoxFlat]) -> DebtBadge:
	var style := StyleBoxFlat.new()
	style.bg_color = NORMAL_COLOR
	style.content_margin_left = CELL_PADDING.x
	style.content_margin_right = CELL_PADDING.x
	style.content_margin_top = CELL_PADDING.y
	style.content_margin_bottom = CELL_PADDING.y
	styles.append(style)

	var wrap := Control.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.size_flags_stretch_ratio = 3.0
	grid.add_child(wrap)

	var cell := PanelContainer.new()
	cell.add_theme_stylebox_override("panel", style)
	cell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrap.add_child(cell)

	var label := Label.new()
	label.text = player_name
	label.add_theme_font_size_override("font_size", NAME_FONT_SIZE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	cell.add_child(label)

	var badge: DebtBadge = DEBT_BADGE.instantiate()
	badge.anchor_left = 1.0
	badge.anchor_right = 1.0
	badge.offset_left = -(DEBT_BADGE_SIZE + DEBT_BADGE_MARGIN)
	badge.offset_right = -DEBT_BADGE_MARGIN
	badge.offset_top = DEBT_BADGE_MARGIN
	badge.offset_bottom = DEBT_BADGE_MARGIN + DEBT_BADGE_SIZE
	wrap.add_child(badge)
	return badge

## Ajoute une cellule (fond + label) a la grille et retourne son label.
## stretch > 0 : la colonne s'etire avec ce ratio ; min_width fixe sinon.
func _add_cell(text: String, font_size: int, align: HorizontalAlignment, stretch: float, min_width: float, styles: Array[StyleBoxFlat]) -> Label:
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
	if stretch > 0.0:
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.size_flags_stretch_ratio = stretch
	grid.add_child(cell)

	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cell.add_child(label)
	return label
