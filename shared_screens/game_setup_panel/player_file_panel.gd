class_name PlayerFilePanel
extends VBoxContainer

## Fiche d'un joueur de la base (PlayerDatabase) : photo, nom et
## statistiques. open() affiche un joueur inscrit, open_new() prepare
## l'inscription d'un nouveau joueur (enregistre seulement a Save / Select).
## Le bouton Photo choisit une image sur le disque (cle USB, ...).
## Save enregistre et revient a la liste (saved), Select enregistre et
## donne ce joueur a la place en cours d'edition (selected), Back abandonne
## les modifications (back_pressed).
## Le nom ne peut etre ni vide ni deja pris par un autre joueur inscrit.

signal back_pressed
signal saved
signal selected(player_name: String)

const PHOTO_PLACEHOLDER := preload("res://assets/ui/setup/icon_person.svg")
const PHOTO_FILTERS: Array[String] = ["*.png, *.jpg, *.jpeg, *.webp ; Images"]

@onready var photo_rect: TextureRect = $Content/PhotoColumn/Photo
@onready var photo_button: Button = $Content/PhotoColumn/PhotoButton
@onready var name_edit: LineEdit = $Content/Info/NameEdit
@onready var hint_label: Label = $Content/Info/HintLabel
@onready var stats_label: Label = $Content/Info/StatsLabel
@onready var back_button: Button = $Buttons/BackButton
@onready var save_button: Button = $Buttons/SaveButton
@onready var select_button: Button = $Buttons/SelectButton

## Identifiant du joueur affiche ("" pour un nouveau joueur).
var _id := ""
## Image choisie, importee a l'enregistrement.
var _pending_photo := ""
var _file_dialog: FileDialog

## Vignette de la photo du joueur `id` (ou silhouette s'il n'en a pas).
static func photo_thumbnail(id: String, size: int) -> TextureRect:
	var rect := TextureRect.new()
	var photo := PlayerDatabase.get_photo(id)
	rect.texture = photo if photo else PHOTO_PLACEHOLDER
	rect.custom_minimum_size = Vector2(size, size)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect

func _ready() -> void:
	name_edit.text_changed.connect(func(_text: String): _update_buttons())
	name_edit.text_submitted.connect(func(_text: String): _save_and(saved.emit))
	photo_button.pressed.connect(_choose_photo)
	back_button.pressed.connect(func(): back_pressed.emit())
	save_button.pressed.connect(func(): _save_and(saved.emit))
	select_button.pressed.connect(func(): _save_and(func(): selected.emit(name_edit.text.strip_edges())))
	for button in [photo_button, back_button, save_button, select_button]:
		PressScale.attach(button)

func open(id: String) -> void:
	var player := PlayerDatabase.get_player(id)
	_id = id
	_pending_photo = ""
	name_edit.text = player.get("name", "")
	var photo := PlayerDatabase.get_photo(id)
	photo_rect.texture = photo if photo else PHOTO_PLACEHOLDER
	stats_label.text = _stats_text(player.get("stats", {}))
	_open_common()

func open_new(suggested_name: String) -> void:
	_id = ""
	_pending_photo = ""
	name_edit.text = suggested_name
	photo_rect.texture = PHOTO_PLACEHOLDER
	stats_label.text = _stats_text({})
	_open_common()

func _open_common() -> void:
	_update_buttons()
	name_edit.grab_focus()
	name_edit.select_all()

func _stats_text(stats: Dictionary) -> String:
	if stats.is_empty():
		return "No statistics yet."
	var lines: PackedStringArray = []
	for key in stats:
		lines.append("%s: %s" % [str(key).capitalize(), str(stats[key])])
	return "\n".join(lines)

func _name_error(player_name: String) -> String:
	if player_name.is_empty():
		return "Enter a name."
	if PlayerDatabase.has_name(player_name, _id):
		return "This name is already registered."
	return ""

func _update_buttons() -> void:
	var error := _name_error(name_edit.text.strip_edges())
	hint_label.text = error
	save_button.disabled = not error.is_empty()
	select_button.disabled = not error.is_empty()

func _save_and(then: Callable) -> void:
	var player_name := name_edit.text.strip_edges()
	if not _name_error(player_name).is_empty():
		return
	if _id.is_empty():
		_id = PlayerDatabase.add_player(player_name)
	else:
		PlayerDatabase.rename_player(_id, player_name)
	if not _pending_photo.is_empty():
		PlayerDatabase.set_photo(_id, _pending_photo)
		_pending_photo = ""
	then.call()

func _choose_photo() -> void:
	if _file_dialog == null:
		_file_dialog = FileDialog.new()
		_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_file_dialog.filters = PackedStringArray(PHOTO_FILTERS)
		_file_dialog.title = "Choose a photo"
		_file_dialog.file_selected.connect(_on_photo_selected)
		add_child(_file_dialog)
	_file_dialog.popup_centered_ratio(0.7)

func _on_photo_selected(path: String) -> void:
	var image := Image.load_from_file(path)
	if image == null or image.is_empty():
		hint_label.text = "This image cannot be read."
		return
	_pending_photo = path
	photo_rect.texture = ImageTexture.create_from_image(image)
