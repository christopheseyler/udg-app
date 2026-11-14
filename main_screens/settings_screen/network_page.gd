class_name SettingsNetworkPage
extends VBoxContainer

## Onglet Network de l'ecran Settings (issue #7) : deux vues, Ethernet et
## Wi-Fi, choisies par les deux boutons du haut.
##
## - Ethernet : etat du cable et adresse IP de chaque interface filaire
##   (NetworkInfo).
## - Wi-Fi : etat courant (UdgWifi.status(), rafraichi toutes les
##   STATUS_REFRESH_S tant que la vue est affichee), liste des reseaux
##   detectes (UdgWifi.scan()) et une entree "Other network..." pour un reseau
##   cache. Toucher un reseau ouvre le dialogue WifiDialog (hors de la page,
##   pour couvrir tout l'ecran) : mot de passe masque saisi au clavier
##   virtuel, puis UdgWifi.join(), qui n'enregistre le reseau sur la borne
##   (/data/wifi, partie persistante) qu'en cas de succes. Un reseau
##   enregistre peut aussi y etre oublie (UdgWifi.forget()).
##
## Le choix Ethernet / Wi-Fi ne change que la vue : l'image n'a pas de
## commande pour couper l'une des deux interfaces. Quand les deux sont
## branchees, dhcpcd donne la priorite a l'Ethernet (udg-yocto,
## doc/WIFI-INTERFACE.md section 3).
##
## Le mot de passe ne passe que par UdgWifi.join() : jamais dans un log ni
## dans un message affiche.

## Emis pendant une connexion (true) puis a la fin (false) : l'ecran
## desactive ses onglets et son bouton Back pendant ce temps.
signal busy_changed(busy: bool)

const STATUS_REFRESH_S := 8.0

## Message affiche pour chaque code d'erreur de udg-wifi
## (doc/WIFI-INTERFACE.md, section 4).
const ERROR_MESSAGES := {
	"wrong_password": "Wrong password.",
	"not_found": "Network not found (out of range, or another security type).",
	"timeout": "The network does not answer.",
	"invalid_password": "The password must have 8 to 63 characters.",
	"invalid_ssid": "Invalid network name.",
	"busy": "Wi-Fi is busy, try again.",
	"unavailable": "Wi-Fi is not available.",
	"save_failed": "Connected, but the network could not be saved.",
}

## Dialogue de connexion et clavier virtuel, a la racine de l'ecran.
@export var wifi_dialog: Control
@export var keyboard: Control

@onready var ethernet_button: Button = $ModeButtons/EthernetButton
@onready var wifi_button: Button = $ModeButtons/WifiButton
@onready var ethernet_view: Control = $EthernetView
@onready var ethernet_list: VBoxContainer = $EthernetView/EthernetList
@onready var wifi_view: Control = $WifiView
@onready var wifi_icon: WifiSignalIcon = $WifiView/Header/StatusIcon
@onready var wifi_status_label: Label = $WifiView/Header/StatusLabel
@onready var scan_button: Button = $WifiView/Header/ScanButton
@onready var wifi_message_label: Label = $WifiView/MessageLabel
@onready var wifi_list: VBoxContainer = $WifiView/Scroll/ListMargin/NetworkList

var _dialog_title: Label
var _ssid_edit: LineEdit
var _password_row: Control
var _password_edit: LineEdit
var _show_button: Button
var _dialog_message: Label
var _forget_button: Button
var _cancel_button: Button
var _connect_button: Button

var _wifi_available := false
var _scanning := false
var _connecting := false
var _refresh_timer: Timer
## Reseau du dialogue : {ssid, security, saved, connected} ; hidden = saisi a
## la main ("Other network...").
var _dialog_network: Dictionary = {}
var _dialog_hidden := false

func _ready() -> void:
	var content := wifi_dialog.get_node("Top/Dialog/Margin/Content")
	_dialog_title = content.get_node("TitleLabel")
	_ssid_edit = content.get_node("SsidEdit")
	_password_row = content.get_node("PasswordRow")
	_password_edit = content.get_node("PasswordRow/PasswordEdit")
	_show_button = content.get_node("PasswordRow/ShowButton")
	_dialog_message = content.get_node("MessageLabel")
	_forget_button = content.get_node("Buttons/ForgetButton")
	_cancel_button = content.get_node("Buttons/CancelButton")
	_connect_button = content.get_node("Buttons/ConnectButton")

	ethernet_button.pressed.connect(_show_mode.bind(false))
	wifi_button.pressed.connect(_show_mode.bind(true))
	scan_button.pressed.connect(_scan)
	_show_button.toggled.connect(func(on: bool): _password_edit.secret = not on)
	_password_edit.text_changed.connect(func(_t): _update_connect_button())
	_ssid_edit.text_changed.connect(func(_t): _update_connect_button())
	_password_edit.text_submitted.connect(func(_t): _on_connect_pressed())
	_ssid_edit.text_submitted.connect(func(_t): _password_edit.grab_focus())
	_password_edit.focus_entered.connect(keyboard.show)
	_ssid_edit.focus_entered.connect(keyboard.show)
	_forget_button.pressed.connect(_on_forget_pressed)
	_cancel_button.pressed.connect(_close_dialog)
	_connect_button.pressed.connect(_on_connect_pressed)
	for button in [ethernet_button, wifi_button, scan_button, _show_button,
			_forget_button, _cancel_button, _connect_button]:
		PressScale.attach(button)

	_refresh_timer = Timer.new()
	_refresh_timer.wait_time = STATUS_REFRESH_S
	_refresh_timer.timeout.connect(_on_refresh_timer)
	add_child(_refresh_timer)
	wifi_dialog.visible = false
	visibility_changed.connect(_on_visibility_changed)
	_show_mode(UdgWifi.is_supported())

## Appele par l'ecran a chaque affichage de l'onglet.
func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		_refresh_ethernet()
		if wifi_view.visible:
			_open_wifi()
	else:
		_refresh_timer.stop()

func _show_mode(wifi: bool) -> void:
	ethernet_button.theme_type_variation = &"PillButton" if wifi else &"PillButtonActive"
	wifi_button.theme_type_variation = &"PillButtonActive" if wifi else &"PillButton"
	ethernet_view.visible = not wifi
	wifi_view.visible = wifi
	if not is_visible_in_tree():
		return
	if wifi:
		_open_wifi()
	else:
		_refresh_timer.stop()
		_refresh_ethernet()

# --- Ethernet -----------------------------------------------------------

func _refresh_ethernet() -> void:
	for child in ethernet_list.get_children():
		child.queue_free()
	var wired := NetworkInfo.interfaces().filter(func(i): return not i.wireless)
	if wired.is_empty():
		ethernet_list.add_child(_info_row("Ethernet", "No wired interface"))
	for iface in wired:
		var state: String
		if not iface.carrier:
			state = "Cable unplugged"
		elif iface.ip == "":
			state = "Waiting for an address..."
		else:
			state = "Connected - IP %s" % iface.ip
		ethernet_list.add_child(_info_row(iface.label, state))

## Ligne "nom : valeur" sur une plaque (style RowPlate du theme).
func _info_row(title: String, value: String) -> Control:
	var plate := PanelContainer.new()
	plate.theme_type_variation = &"RowPlate"
	var row := HBoxContainer.new()
	plate.add_child(row)
	var name_label := Label.new()
	name_label.text = title
	name_label.add_theme_font_size_override("font_size", 32)
	# Largeur fixe : sous Windows, les noms d'interface sont tres longs.
	name_label.custom_minimum_size.x = 300
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(name_label)
	var value_label := Label.new()
	value_label.text = value
	value_label.add_theme_font_size_override("font_size", 32)
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(value_label)
	return plate

# --- Wi-Fi --------------------------------------------------------------

func _open_wifi() -> void:
	await _refresh_status()
	if _wifi_available:
		_refresh_timer.start()
		_scan()

func _on_refresh_timer() -> void:
	if not _connecting and not _scanning:
		_refresh_status()

func _refresh_status() -> void:
	var st: Dictionary = await UdgWifi.status()
	_wifi_available = st.get("available", false)
	scan_button.disabled = not _wifi_available or _scanning or _connecting
	if not _wifi_available:
		wifi_icon.bars = 0
		wifi_status_label.text = "Wi-Fi is not available on this machine." \
				if st.get("reason", "") != "no_service" else "Wi-Fi service is not running."
		_clear_list()
		return
	var state: String = st.get("state", "")
	var ip = st.get("ip")
	match state:
		"connected":
			wifi_icon.bars = int(st.get("bars", 0))
			wifi_status_label.text = "Connected to %s\n%s" % [st.get("ssid", "?"),
					("IP %s" % ip) if ip else "Waiting for an address..."]
		"connecting":
			wifi_icon.bars = 0
			wifi_status_label.text = "Connecting..."
		_:
			wifi_icon.bars = 0
			wifi_status_label.text = "Not connected"

func _scan() -> void:
	if _scanning or not _wifi_available:
		return
	_scanning = true
	scan_button.disabled = true
	wifi_message_label.text = "Searching for networks..."
	var sc: Dictionary = await UdgWifi.scan()
	_scanning = false
	scan_button.disabled = _connecting
	if not sc.get("ok", false):
		wifi_message_label.text = _error_text(sc)
		return
	var networks: Array = sc.get("networks", [])
	wifi_message_label.text = "%d network%s found. Touch one to connect." % [
			networks.size(), "" if networks.size() == 1 else "s"]
	_fill_list(networks)

func _clear_list() -> void:
	for child in wifi_list.get_children():
		wifi_list.remove_child(child)
		child.queue_free()

func _fill_list(networks: Array) -> void:
	_clear_list()
	for net: Dictionary in networks:
		wifi_list.add_child(_network_row(net))
	var other := _row_button()
	var other_label := _row_label("Other network...")
	other.get_child(0).add_child(other_label)
	other.pressed.connect(_open_dialog.bind({}, true))
	wifi_list.add_child(other)

func _row_button() -> Button:
	var button := Button.new()
	button.theme_type_variation = &"RowButton"
	button.custom_minimum_size = Vector2(0, 90)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 32
	row.offset_right = -32
	row.add_theme_constant_override("separation", 24)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(row)
	PressScale.attach(button)
	return button

func _row_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 34)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

## Une ligne par reseau : barres et cadenas, nom, "Connected" ou "Saved".
## Les reseaux a la securite non prise en charge sont grises.
func _network_row(net: Dictionary) -> Button:
	var button := _row_button()
	var row: HBoxContainer = button.get_child(0)
	var icon := WifiSignalIcon.new()
	icon.bars = int(net.get("bars", 0))
	icon.locked = net.get("security", "open") != "open"
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	row.add_child(_row_label(str(net.get("ssid", ""))))
	var tag := ""
	if not net.get("supported", true):
		tag = "Not supported"
	elif net.get("connected", false):
		tag = "Connected"
	elif net.get("saved", false):
		tag = "Saved"
	if tag != "":
		var tag_label := _row_label(tag)
		tag_label.size_flags_horizontal = Control.SIZE_SHRINK_END
		# Sans troncature, sinon sa largeur minimale tombe a 0 a cote du nom.
		tag_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		tag_label.add_theme_font_size_override("font_size", 28)
		tag_label.modulate = Color(1, 1, 1, 0.75)
		row.add_child(tag_label)
	if not net.get("supported", true):
		button.modulate = Color(1, 1, 1, 0.45)
		button.pressed.connect(func(): wifi_message_label.text = \
				"%s uses a security type the cabinet does not support." % net.get("ssid", ""))
	else:
		button.pressed.connect(_open_dialog.bind(net, false))
	return button

# --- Dialogue de connexion ---------------------------------------------

## Ouvre le dialogue pour `net` (reseau detecte) ou, si `hidden`, pour un
## reseau saisi a la main. Un reseau ouvert non enregistre est rejoint tout
## de suite, sans dialogue de saisie.
func _open_dialog(net: Dictionary, hidden: bool) -> void:
	if _connecting:
		return
	_dialog_network = net
	_dialog_hidden = hidden
	var open: bool = not hidden and net.get("security", "open") == "open"
	var connected: bool = net.get("connected", false)
	var saved: bool = net.get("saved", false)

	_ssid_edit.text = ""
	_password_edit.text = ""
	_password_edit.secret = true
	_show_button.set_pressed_no_signal(false)
	_ssid_edit.visible = hidden
	_password_row.visible = not open and not connected
	_forget_button.visible = saved
	_connect_button.visible = not connected
	_cancel_button.text = "Close" if connected else "Cancel"
	_dialog_message.text = ""
	if hidden:
		_dialog_title.text = "Other network"
		_dialog_message.text = "Leave the password empty for an open network."
	else:
		_dialog_title.text = str(net.get("ssid", ""))
		if connected:
			_dialog_message.text = "The cabinet is connected to this network."
		elif open:
			_dialog_message.text = "Open network, no password."
		elif saved:
			_dialog_message.text = "Saved network. Enter the password to connect again."
	_set_dialog_busy(false)
	_update_connect_button()
	wifi_dialog.visible = true
	if hidden:
		_ssid_edit.grab_focus()
	elif _password_row.visible:
		_password_edit.grab_focus()
	else:
		keyboard.hide()

func _close_dialog() -> void:
	if _connecting:
		return
	_password_edit.text = ""
	wifi_dialog.visible = false
	keyboard.hide()

## Mot de passe accepte par udg-wifi : 8 a 63 caracteres ASCII imprimables,
## ou la cle brute de 64 caracteres hexadecimaux ; vide pour un reseau
## ouvert (ou un reseau cache sans mot de passe).
func _password_ok(password: String) -> bool:
	if password == "":
		return _dialog_hidden or not _password_row.visible
	if password.length() == 64 and password.is_valid_hex_number():
		return true
	if password.length() < 8 or password.length() > 63:
		return false
	for i in password.length():
		var c := password.unicode_at(i)
		if c < 32 or c > 126:
			return false
	return true

func _update_connect_button() -> void:
	var ssid_ok := not _dialog_hidden or _ssid_edit.text.strip_edges() != ""
	_connect_button.disabled = _connecting or not ssid_ok or not _password_ok(_password_edit.text)

func _set_dialog_busy(busy: bool) -> void:
	_connecting = busy
	for control in [_ssid_edit, _password_edit]:
		control.editable = not busy
	for button in [_show_button, _forget_button, _cancel_button]:
		button.disabled = busy
	scan_button.disabled = busy or _scanning or not _wifi_available
	_update_connect_button()
	busy_changed.emit(busy)

func _on_connect_pressed() -> void:
	if _connect_button.disabled or not _connect_button.visible:
		return
	var ssid: String = _ssid_edit.text.strip_edges() if _dialog_hidden else str(_dialog_network.get("ssid", ""))
	var password := _password_edit.text if _password_row.visible else ""
	keyboard.hide()
	_set_dialog_busy(true)
	_dialog_message.text = "Connecting to %s...\nThis can take up to a minute." % ssid
	var r: Dictionary = await UdgWifi.join(ssid, password, _dialog_hidden)
	_set_dialog_busy(false)
	if r.get("ok", false):
		_close_dialog()
		await _refresh_status()
		await _scan()
		var ip = r.get("ip")
		wifi_message_label.text = "Connected to %s (%s). The cabinet will reconnect at every start." % [
				ssid, ("IP %s" % ip) if ip else "address pending"]
	else:
		_dialog_message.text = _error_text(r)
		if r.get("error", "") in ["wrong_password", "invalid_password"]:
			_password_edit.grab_focus()
			_password_edit.select_all()
			keyboard.show()

func _on_forget_pressed() -> void:
	var ssid := str(_dialog_network.get("ssid", ""))
	_set_dialog_busy(true)
	_dialog_message.text = "Forgetting %s..." % ssid
	var r: Dictionary = await UdgWifi.forget(ssid)
	_set_dialog_busy(false)
	if r.get("ok", false):
		_close_dialog()
		await _refresh_status()
		await _scan()
		wifi_message_label.text = "%s forgotten." % ssid
	else:
		_dialog_message.text = _error_text(r)

## Texte a afficher pour une reponse en erreur de udg-wifi ; le "message"
## technique part dans les logs (il ne contient jamais le mot de passe).
func _error_text(r: Dictionary) -> String:
	var code: String = r.get("error", "failed")
	if not ERROR_MESSAGES.has(code):
		push_warning("udg-wifi: %s (%s)" % [code, r.get("message", "")])
	return ERROR_MESSAGES.get(code, "Wi-Fi error (%s)." % code)
