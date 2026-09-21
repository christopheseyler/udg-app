class_name DartSimulator
extends CanvasLayer

## Panneau de simulation des jets, affiche par-dessus le jeu (bouton
## "Simulator" en haut de l'ecran ou touche F1). Choisir Single / Double /
## Triple puis un numero, ou Bull / Miss. Le multiplicateur revient a Single
## apres chaque jet. Les jets sont envoyes au SimulatedDartInput fourni par
## setup().

const NUMBER_COUNT := 20
const NUMBER_COLUMNS := 5

@onready var toggle_button: Button = $ToggleButton
@onready var panel: PanelContainer = $Panel
@onready var multiplier_row: HBoxContainer = $Panel/Margin/Content/MultiplierRow
@onready var number_grid: GridContainer = $Panel/Margin/Content/NumberGrid
@onready var bull_button: Button = $Panel/Margin/Content/ExtraRow/BullButton
@onready var miss_button: Button = $Panel/Margin/Content/ExtraRow/MissButton

var _input: SimulatedDartInput
var _multiplier := 1
var _multiplier_buttons: Array[Button] = []

func _ready() -> void:
	toggle_button.pressed.connect(_toggle_panel)
	_build_multiplier_buttons()
	_build_number_buttons()
	bull_button.pressed.connect(func(): _send_hit(DartHit.create(DartHit.BULL, _multiplier)))
	miss_button.pressed.connect(func(): _send_hit(DartHit.miss()))
	panel.visible = false

func setup(input: SimulatedDartInput) -> void:
	_input = input

## Affiche ou masque le simulateur (bouton et panneau) selon qu'une partie
## est en cours.
func set_available(available: bool) -> void:
	visible = available
	if not available:
		panel.visible = false

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		_toggle_panel()

func _toggle_panel() -> void:
	panel.visible = not panel.visible

func _build_multiplier_buttons() -> void:
	var group := ButtonGroup.new()
	for i in multiplier_row.get_child_count():
		var button: Button = multiplier_row.get_child(i)
		button.toggle_mode = true
		button.button_group = group
		button.pressed.connect(func(): _multiplier = i + 1)
		_multiplier_buttons.append(button)
	_reset_multiplier()

func _build_number_buttons() -> void:
	number_grid.columns = NUMBER_COLUMNS
	for number in range(1, NUMBER_COUNT + 1):
		var button := Button.new()
		button.text = str(number)
		button.custom_minimum_size = Vector2(120, 90)
		button.add_theme_font_size_override("font_size", 40)
		button.pressed.connect(func(): _send_hit(DartHit.create(number, _multiplier)))
		number_grid.add_child(button)

func _send_hit(hit: DartHit) -> void:
	if _input:
		_input.simulate_hit(hit)
	_reset_multiplier()

func _reset_multiplier() -> void:
	_multiplier = 1
	_multiplier_buttons[0].button_pressed = true
