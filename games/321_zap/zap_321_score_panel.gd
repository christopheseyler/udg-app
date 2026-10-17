class_name Zap321ScorePanel
extends PanelContainer

## Panneau de score du 321 Zap : une ligne par joueur avec son nom, la
## fleche du sens de son chemin (mode Both Ways : vers le haut de 0 a 321,
## vers le bas de 321 a 0), son score ("Out" tant qu'il n'est pas entre),
## l'eclair de zap (voir ZapBolt) et un texte d'aide. Le
## joueur en cours est mis en surbrillance. set_players() construit les
## lignes (et choisit les colonnes), set_row() met a jour un joueur,
## set_current_player() deplace la surbrillance, set_zap_delta() affiche
## l'encadre "points a marquer pour le zapper", a droite du nom.

## direction_arrows.png : 2 cases carrees identiques (vers le haut, vers le
## bas).
const ARROWS_ATLAS := preload("res://assets/games/321_zap/direction_arrows.png")

const SCORE_COLUMN_WIDTH := 200.0
const ICON_COLUMN_WIDTH := 96.0
const ICON_SIZE := Vector2(60, 60)
## Tailles selon le nombre de joueurs (le premier seuil atteint), pour
## afficher jusqu'a 8 joueurs sans defilement : polices du nom, du score et
## du texte d'aide, et marge verticale des cellules.
const ROW_SIZES := [
	{"players": 8, "name": 38, "score": 44, "hint": 26, "pad": 8},
	{"players": 6, "name": 46, "score": 52, "hint": 30, "pad": 12},
	{"players": 0, "name": 56, "score": 64, "hint": 36, "pad": 20},
]
const CELL_PADDING_X := 24.0
## Encadre du delta de zap, pose en overlay a droite de la cellule du nom
## (centre verticalement), aux couleurs de l'eclair.
const DELTA_MARGIN := 8.0
const DELTA_FONT_RATIO := 0.7
const DELTA_BG_COLOR := Color(1.0, 0.78, 0.16)
const DELTA_BORDER_COLOR := Color(0.45, 0.28, 0.02)
const DELTA_TEXT_COLOR := Color(0.12, 0.08, 0.0)
## Delta jouable avec les fleches restantes : encadre plus clair, bord
## blanc, halo dore, et pulsation lumineuse (self_modulate > 1).
const DELTA_BRIGHT_BG_COLOR := Color(1.0, 0.92, 0.45)
const DELTA_BRIGHT_BORDER_COLOR := Color(1.0, 1.0, 1.0)
const DELTA_GLOW_COLOR := Color(1.0, 0.85, 0.2, 0.75)
const DELTA_GLOW_SIZE := 14
const DELTA_PULSE_COLOR := Color(1.45, 1.35, 1.1)
const DELTA_PULSE_DURATION := 0.45

@onready var grid: GridContainer = $Margin/Scroll/Grid

var _sizes: Dictionary = ROW_SIZES[-1]
## Plaques des lignes (creees au premier set_players).
var _row_plates: ScoreRowPlates
var _score_labels: Array[Label] = []
var _hint_labels: Array[Label] = []
var _arrows: Array[TextureRect] = []
var _bolts: Array[ZapBolt] = []
var _delta_boxes: Array[PanelContainer] = []
var _delta_labels: Array[Label] = []
var _delta_bright: Array[bool] = []
var _delta_tweens: Array[Tween] = []
var _delta_style := _delta_box_style(false)
var _delta_bright_style := _delta_box_style(true)
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
	if _row_plates == null:
		_row_plates = ScoreRowPlates.new(grid)
	_score_labels.clear()
	_hint_labels.clear()
	_arrows.clear()
	_bolts.clear()
	_delta_boxes.clear()
	_delta_labels.clear()
	_delta_bright.clear()
	for tween in _delta_tweens:
		if tween:
			tween.kill()
	_delta_tweens.clear()
	for sizes in ROW_SIZES:
		if names.size() >= sizes.players:
			_sizes = sizes
			break
	grid.columns = 4 + int(show_direction)

	for player_name in names:
		_add_name_cell(player_name)
		if show_direction:
			var arrow := TextureRect.new()
			arrow.custom_minimum_size = ICON_SIZE
			arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			arrow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			_add_cell(arrow, ICON_COLUMN_WIDTH)
			_arrows.append(arrow)
		var score_label := _add_label_cell("", _sizes.score, HORIZONTAL_ALIGNMENT_CENTER)
		score_label.get_parent().custom_minimum_size.x = SCORE_COLUMN_WIDTH
		_score_labels.append(score_label)
		var bolt := ZapBolt.new()
		bolt.custom_minimum_size = ICON_SIZE
		_add_cell(bolt, ICON_COLUMN_WIDTH)
		_bolts.append(bolt)
		var hint_label := _add_label_cell("", _sizes.hint, HORIZONTAL_ALIGNMENT_LEFT)
		hint_label.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hint_label.get_parent().size_flags_stretch_ratio = 4.0
		hint_label.modulate.a = 0.85
		_hint_labels.append(hint_label)

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
	_row_plates.set_current(index)

## Points que le joueur en cours doit marquer pour zapper le joueur index,
## affiches dans l'encadre a droite de son nom, precedes du symbole delta
## (ex. "Δ40") ; delta <= 0 le masque.
## reachable : delta jouable avec les fleches restantes, encadre brillant et
## pulsant.
func set_zap_delta(index: int, delta: int, reachable: bool) -> void:
	var box := _delta_boxes[index]
	box.visible = delta > 0
	if delta > 0:
		_delta_labels[index].text = "Δ%d" % delta
	var bright := delta > 0 and reachable
	if bright == _delta_bright[index]:
		return
	_delta_bright[index] = bright
	box.add_theme_stylebox_override("panel", _delta_bright_style if bright else _delta_style)
	if _delta_tweens[index]:
		_delta_tweens[index].kill()
		_delta_tweens[index] = null
	box.self_modulate = Color.WHITE
	if bright:
		var tween := create_tween().set_loops()
		tween.tween_property(box, "self_modulate", DELTA_PULSE_COLOR, DELTA_PULSE_DURATION) 			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(box, "self_modulate", Color.WHITE, DELTA_PULSE_DURATION) 			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_delta_tweens[index] = tween

static func _delta_box_style(bright: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = DELTA_BRIGHT_BG_COLOR if bright else DELTA_BG_COLOR
	style.border_color = DELTA_BRIGHT_BORDER_COLOR if bright else DELTA_BORDER_COLOR
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 2.0
	style.content_margin_bottom = 2.0
	if bright:
		style.shadow_color = DELTA_GLOW_COLOR
		style.shadow_size = DELTA_GLOW_SIZE
	return style

## Ajoute la cellule "nom du joueur" a la grille : comme _add_cell, mais
## enveloppee dans un Control simple pour pouvoir y poser l'encadre du delta
## de zap en overlay, ancre a droite, sans qu'il soit etire au fond de la
## cellule comme le ferait un second enfant direct d'un PanelContainer.
func _add_name_cell(player_name: String) -> void:
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.content_margin_left = CELL_PADDING_X
	style.content_margin_right = CELL_PADDING_X
	style.content_margin_top = float(_sizes.pad)
	style.content_margin_bottom = float(_sizes.pad)

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
	label.add_theme_font_size_override("font_size", _sizes.name)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	cell.add_child(label)
	# La ligne prend la hauteur du nom (le wrap n'a pas de taille minimale
	# propre).
	wrap.custom_minimum_size.y = label.get_minimum_size().y + 2.0 * _sizes.pad

	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", _delta_style)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.visible = false
	# Ancre au bord droit, centre verticalement ; grandit vers la gauche.
	box.anchor_left = 1.0
	box.anchor_right = 1.0
	box.anchor_top = 0.5
	box.anchor_bottom = 0.5
	box.offset_right = -DELTA_MARGIN
	box.offset_left = -DELTA_MARGIN
	box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	wrap.add_child(box)

	var value := Label.new()
	value.add_theme_font_size_override("font_size", int(_sizes.name * DELTA_FONT_RATIO))
	value.add_theme_color_override("font_color", DELTA_TEXT_COLOR)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(value)
	_delta_boxes.append(box)
	_delta_labels.append(value)
	_delta_bright.append(false)
	_delta_tweens.append(null)

func _add_label_cell(text: String, font_size: int, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_add_cell(label, 0.0)
	return label

## Ajoute une cellule (contenu, sans fond : voir ScoreRowPlates) a la grille ; min_width > 0 fixe sa
## largeur.
func _add_cell(content: Control, min_width: float) -> PanelContainer:
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.content_margin_left = CELL_PADDING_X
	style.content_margin_right = CELL_PADDING_X
	style.content_margin_top = float(_sizes.pad)
	style.content_margin_bottom = float(_sizes.pad)

	var cell := PanelContainer.new()
	cell.add_theme_stylebox_override("panel", style)
	cell.custom_minimum_size.x = min_width
	grid.add_child(cell)
	cell.add_child(content)
	return cell
