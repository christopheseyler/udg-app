class_name SettingsScreen
extends Control

## Ecran de reglages systeme. Deux mises a jour depuis une cle USB (voir
## udg-yocto : meta-udg-min pour le pipeline RAUC app-only A/B + recovery, et
## doc/DARTBOARD-INTERFACE.md pour la carte d'interface cible) :
##
## 1. "Check for update from USB" (application) : liste tous les fichiers
## .raucb trouves dans UPDATE_DIR (convention retenue : la cle USB est
## montee - ou son contenu copie - a ce chemin fixe, /media/udg-update) et
## laisse choisir lequel installer - plusieurs versions peuvent cohabiter sur
## la meme cle (ex. pour revenir en arriere). Sur selection, lit sa version
## via `rauc info`, puis demande confirmation ("Application vX.Y.Z, Do you
## want to upgrade?"). Sur confirmation, `udg-app-selector.sh --install`
## tourne dans un thread (ca peut prendre du temps) ; une fois termine avec
## succes, le meme dialogue est reutilise pour proposer un redemarrage
## (udg-app-selector.sh reprend la main au prochain demarrage et bascule sur
## le nouveau slot) - voir _confirm_action, qui distingue les deux usages du
## dialogue.
##
## PAS `rauc install` directement : confirme cote systeme (udg-yocto) que ca
## ne fonctionne pas pour ce design (bootloader=noop empeche RAUC de
## determiner seul le slot inactif, donc il installe toujours dans le meme
## slot quel que soit celui reellement actif). udg-app-selector.sh --install
## fait le meme travail correctement : verifie la signature puis ecrit dans
## le slot que l'etat systeme sait etre inactif.
##
## 2. "DartBoard Interface Update" (firmware du Raspberry Pi Pico) : meme
## principe avec les fichiers udg_dartboard_if_MM.mm.bbbb.dpkg. Chaque
## candidat est valide par `udg-dartboard-flash --info` (les fichiers
## invalides sont ignores), puis la version actuelle (commande `alive` sur
## /dev/udg-dartboard) et la version cible sont affichees pour confirmation.
## Le flash (`udg-dartboard-flash <fichier>`, bloquant) est lance en
## processus separe surveille par un timeout global ; ensuite on attend que
## le port reapparaisse et on verifie par `alive` que la nouvelle version
## est bien celle du fichier. Le jeu n'ouvre jamais le port serie lui-meme
## (il est ouvert brievement, en `stty raw -echo`, par _read_alive_version) :
## rien a fermer avant le flash. Aucune politique sur les retrogradations
## (l'outil ne les interdit pas) : le choix est laisse a l'utilisateur.
##
## 1bis. "Check for update online" (application) : meme installation que
## ci-dessus, mais le bundle vient de la derniere release GitHub du depot
## (GITHUB_LATEST_RELEASE_URL). Le `tag_name` (avec ou sans "v") est compare
## a application/config/version ; si la release est plus recente et porte un
## fichier .raucb, on demande confirmation, on telecharge le bundle dans
## DOWNLOAD_DIR (avec progression), puis on lance la meme installation que
## pour l'USB (udg-app-selector.sh verifie la signature RAUC : un bundle non
## signe par notre cle est refuse, quelle que soit sa provenance). Le fichier
## telecharge est supprime a la fin de l'installation. Sans reseau, affiche
## simplement que GitHub est injoignable.
##
## Suppose que quelque chose (udev/systemd, hors scope de ce script) monte
## deja la cle USB sur ce chemin fixe : ce script ne monte rien lui-meme.
## Suppose aussi que le processus a le droit d'executer ces outils (le jeu
## tourne en root sur l'image actuelle). Sans ces binaires ni ce point de
## montage (ex. en test dans l'editeur sous Windows), se degrade proprement
## sur "No update found".
##
## 3. "DartBoard Interface Test" : diagnostic materiel, sans rapport avec les
## mises a jour ci-dessus. Se connecte a la carte via DartInputManager.
## board_input (la meme instance que celle du jeu - voir dart_board_input.gd,
## libre ici puisqu'aucune partie n'est en cours quand Settings est ouvert) ;
## si la connexion echoue, affiche simplement que la carte n'est pas branchee.
## Sinon, envoie `alive` pour afficher la version, puis `WaitForHits 0`
## (icd.md 1.1 : un *HIT* par impact jusqu'a StopWaitingHit, envoye par le
## bouton Close) et affiche chaque jet ; un terminal montre les commandes
## envoyees et les lignes brutes recues. send_command()/response_received
## n'imposent aucune politique de tour (a la difference de start_waiting()/
## stop_waiting()) : chaque commande recoit simplement sa reponse "#...#".

signal back_pressed

## Chemin fixe ou la cle USB de mise a jour est attendue montee (convention
## retenue avec l'equipe systeme, voir doc de classe ci-dessus).
const UPDATE_DIR := "/media/udg-update"
const BUNDLE_EXTENSION := ".raucb"

const GITHUB_LATEST_RELEASE_URL := "https://api.github.com/repos/christopheseyler/udg-app/releases/latest"
## Dossier (persistant, hors tmpfs) ou est telecharge le bundle avant installation.
const DOWNLOAD_DIR := "user://update"
const RELEASE_CHECK_TIMEOUT_S := 15.0
const BUNDLE_DOWNLOAD_TIMEOUT_S := 900.0

const DARTBOARD_FILE_PREFIX := "udg_dartboard_if_"
const DARTBOARD_FILE_EXTENSION := ".dpkg"
const DARTBOARD_FLASH_TOOL := "/usr/bin/udg-dartboard-flash"
const DARTBOARD_PORT := "/dev/udg-dartboard"
## Timeout global du flash (l'outil est bloquant et n'a pas de timeout propre).
const DARTBOARD_FLASH_TIMEOUT_S := 60.0
## Delai max pour que le port serie reapparaisse apres le flash.
const DARTBOARD_PORT_WAIT_S := 10.0
const DARTBOARD_FLASH_LOG := "/tmp/udg-dartboard-flash.log"
const DARTBOARD_FLASH_RC := "/tmp/udg-dartboard-flash.rc"
const DARTBOARD_ALIVE_LOG := "/tmp/udg-dartboard-alive.out"

## Attente max de la reponse a une commande du test (icd.md : 1 s suggere).
const DARTBOARD_REPLY_TIMEOUT_S := 1.0
## Nombre de lignes gardees dans le terminal du test.
const DARTBOARD_TEST_LOG_LINES := 10

## Ce que "Yes" declenche dans le dialogue de confirmation, partage entre
## la confirmation d'upgrade et la proposition de redemarrage qui suit une
## installation reussie.
enum ConfirmAction { NONE, UPGRADE, DOWNLOAD, REBOOT }

## Quelle mise a jour est en cours de selection / d'installation.
enum UpdateKind { APP, DARTBOARD }

@onready var check_update_button: Button = $Panel/Layout/Margin/Content/Buttons/CheckUpdateButton
@onready var check_online_button: Button = $Panel/Layout/Margin/Content/Buttons/CheckOnlineUpdateButton
@onready var dartboard_update_button: Button = $Panel/Layout/Margin/Content/Buttons/DartboardUpdateButton
@onready var dartboard_test_button: Button = $Panel/Layout/Margin/Content/Buttons/DartboardTestButton
@onready var back_button: Button = $Panel/Layout/Margin/Content/Buttons/BackButton
@onready var app_version_label: Label = $Panel/Layout/Margin/Content/Buttons/InfoBox/AppVersionLabel
@onready var dartboard_version_label: Label = $Panel/Layout/Margin/Content/Buttons/InfoBox/DartboardVersionLabel
@onready var ip_label: Label = $Panel/Layout/Margin/Content/Buttons/InfoBox/IpLabel
@onready var status_label: Label = $Panel/Layout/Margin/Content/Selection/StatusLabel
@onready var bundle_scroll: ScrollContainer = $Panel/Layout/Margin/Content/Selection/BundleScroll
@onready var bundle_list: VBoxContainer = $Panel/Layout/Margin/Content/Selection/BundleScroll/ListMargin/BundleList
@onready var confirm_overlay: Control = $ConfirmOverlay
@onready var confirm_label: Label = $ConfirmOverlay/Center/Dialog/Margin/Content/ConfirmLabel
@onready var no_button: Button = $ConfirmOverlay/Center/Dialog/Margin/Content/Buttons/NoButton
@onready var yes_button: Button = $ConfirmOverlay/Center/Dialog/Margin/Content/Buttons/YesButton
@onready var test_overlay: Control = $DartboardTestOverlay
@onready var test_version_label: Label = $DartboardTestOverlay/Center/Dialog/Margin/Content/VersionLabel
@onready var test_hit_label: Label = $DartboardTestOverlay/Center/Dialog/Margin/Content/HitLabel
@onready var test_terminal_label: Label = $DartboardTestOverlay/Center/Dialog/Margin/Content/Terminal/TerminalLabel
@onready var test_close_button: Button = $DartboardTestOverlay/Center/Dialog/Margin/Content/CloseButton

var _pending_bundle_path := ""
var _pending_kind := UpdateKind.APP
var _pending_target_version := ""
## Vrai si _pending_bundle_path est un fichier telecharge (a supprimer apres
## l'installation) plutot qu'un fichier de la cle USB.
var _pending_is_download := false
var _online_version := ""
var _online_asset_url := ""
var _online_asset_name := ""
var _download_request: HTTPRequest
var _install_thread: Thread
var _info_thread: Thread
var _confirm_action := ConfirmAction.NONE
var _test_running := false
## Numero du test en cours : une boucle _run_dartboard_test() d'un test ferme
## puis rouvert s'arrete d'elle-meme au lieu de tourner en double.
var _test_serial := 0
## Vrai tant qu'une boucle _run_dartboard_test() tourne, jusqu'a la
## deconnexion de la carte (StopWaitingHit compris) : un nouveau test attend
## la fin.
var _test_loop_running := false
## Numero du test qui a connecte la carte : lignes et jets encore en vol d'un
## test precedent sont ignores.
var _test_connected_serial := -1
## Vrai des la premiere ligne recue de la carte pendant le test.
var _test_board_answered := false
var _test_hits := 0
var _test_log := PackedStringArray()

func _ready() -> void:
	check_update_button.pressed.connect(_on_check_update_pressed)
	check_online_button.pressed.connect(_on_check_online_pressed)
	dartboard_update_button.pressed.connect(_on_dartboard_update_pressed)
	dartboard_test_button.pressed.connect(_on_dartboard_test_pressed)
	back_button.pressed.connect(func(): back_pressed.emit())
	no_button.pressed.connect(_on_confirm_no)
	yes_button.pressed.connect(_on_confirm_yes)
	test_close_button.pressed.connect(_stop_dartboard_test)
	DartInputManager.board_input.line_received.connect(_on_board_line)
	DartInputManager.board_input.hit_detected.connect(_on_test_hit)
	for button in [check_update_button, check_online_button, dartboard_update_button,
			dartboard_test_button, back_button, no_button, yes_button, test_close_button]:
		PressScale.attach(button)
	bundle_scroll.visible = false
	test_overlay.visible = false
	set_process(false)
	_show_system_info()

func _exit_tree() -> void:
	DartInputManager.board_input.line_received.disconnect(_on_board_line)
	DartInputManager.board_input.hit_detected.disconnect(_on_test_hit)
	if _install_thread:
		_install_thread.wait_to_finish()
	if _info_thread:
		_info_thread.wait_to_finish()
	if _test_running or _test_loop_running:
		# Filet de securite si l'ecran est libere pendant un test (ex. sortie
		# du jeu) : _run_dartboard_test() arrete normalement l'attente et
		# ferme la carte lui-meme, mais ne tournera plus une fois ce noeud
		# detruit.
		_test_running = false
		DartInputManager.board_input.send_command("StopWaitingHit")
		DartInputManager.board_input.disconnect_from_board()

func _on_check_update_pressed() -> void:
	_set_status("Looking for a USB drive...")
	_clear_bundle_list()

	var bundle_paths := _find_files(BUNDLE_EXTENSION, "")
	if bundle_paths.is_empty():
		_set_status("No update found on USB.")
		return

	_set_status("Found %d update(s) on USB. Choose one:" % bundle_paths.size())
	for path in bundle_paths:
		_add_list_button(path.get_file(), _on_bundle_selected.bind(path))
	bundle_scroll.visible = true

func _on_check_online_pressed() -> void:
	_set_status("Checking for updates online...")
	_clear_bundle_list()
	_set_busy(true)

	var request := _new_http_request(RELEASE_CHECK_TIMEOUT_S)
	request.request_completed.connect(_on_release_info_received.bind(request))
	var headers := PackedStringArray(["Accept: application/vnd.github+json", "User-Agent: udg-game"])
	if request.request(GITHUB_LATEST_RELEASE_URL, headers) != OK:
		request.queue_free()
		_set_busy(false)
		_set_status("Could not start the online check.")

func _new_http_request(timeout_s: float) -> HTTPRequest:
	var request := HTTPRequest.new()
	request.timeout = timeout_s
	add_child(request)
	return request

func _on_release_info_received(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, request: HTTPRequest) -> void:
	request.queue_free()
	_set_busy(false)

	if result != HTTPRequest.RESULT_SUCCESS:
		_set_status("Could not reach GitHub (no connection?). HTTPRequest result: %d" % result)
		return
	if code == 404:
		_set_status("No release published yet.")
		return
	if code != 200:
		_set_status("GitHub answered HTTP %d." % code)
		return

	var data = JSON.parse_string(body.get_string_from_utf8())
	if not data is Dictionary:
		_set_status("Unexpected answer from GitHub.")
		return

	var remote_version := str(data.get("tag_name", "")).trim_prefix("v")
	var current_version: String = ProjectSettings.get_setting("application/config/version", "0.0.0")
	if remote_version == "" or not _is_newer_version(remote_version, current_version):
		_set_status("Application is up to date (v%s)." % current_version)
		return

	var asset := _find_bundle_asset(data.get("assets", []))
	if asset.is_empty():
		_set_status("Release v%s has no update bundle." % remote_version)
		return

	_online_version = remote_version
	_online_asset_url = asset.url
	_online_asset_name = asset.name
	_confirm_action = ConfirmAction.DOWNLOAD
	confirm_label.text = "Application v%s available online\n(installed: v%s)\nDownload and upgrade?" % [remote_version, current_version]
	confirm_overlay.visible = true
	_set_status("Update v%s available." % remote_version)

## Premier asset .raucb d'une release, sous forme {name, url}, ou {} s'il n'y en a pas.
func _find_bundle_asset(assets) -> Dictionary:
	if not assets is Array:
		return {}
	for asset in assets:
		if asset is Dictionary:
			var asset_name := str(asset.get("name", ""))
			var url := str(asset.get("browser_download_url", ""))
			if asset_name.ends_with(BUNDLE_EXTENSION) and url != "":
				return {"name": asset_name, "url": url}
	return {}

## Compare deux versions "X.Y.Z" numeriquement (les champs manquants valent 0,
## les suffixes non numeriques comme "-rc1" sont ignores).
func _is_newer_version(candidate: String, current: String) -> bool:
	var a := candidate.split(".")
	var b := current.split(".")
	for i in maxi(a.size(), b.size()):
		var x := a[i].to_int() if i < a.size() else 0
		var y := b[i].to_int() if i < b.size() else 0
		if x != y:
			return x > y
	return false

func _start_download() -> void:
	var dir := ProjectSettings.globalize_path(DOWNLOAD_DIR)
	if DirAccess.make_dir_recursive_absolute(dir) != OK:
		_set_status("Could not create the download folder.")
		return
	var path := dir.path_join(_online_asset_name.get_file())

	_set_busy(true)
	_set_status("Downloading v%s..." % _online_version)
	_download_request = _new_http_request(BUNDLE_DOWNLOAD_TIMEOUT_S)
	_download_request.download_file = path
	_download_request.request_completed.connect(_on_download_finished.bind(_download_request, path))
	if _download_request.request(_online_asset_url) != OK:
		_download_request.queue_free()
		_download_request = null
		_set_busy(false)
		_set_status("Could not start the download.")
		return
	set_process(true)

func _process(_delta: float) -> void:
	if _download_request == null:
		set_process(false)
		return
	var done := _download_request.get_downloaded_bytes()
	var total := _download_request.get_body_size()
	var done_mb := done / 1048576.0
	if total > 0:
		_set_status("Downloading v%s... %d%% (%.1f / %.1f MB)" % [_online_version, 100 * done / total, done_mb, total / 1048576.0])
	else:
		_set_status("Downloading v%s... %.1f MB" % [_online_version, done_mb])

func _on_download_finished(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray, request: HTTPRequest, path: String) -> void:
	request.queue_free()
	_download_request = null
	set_process(false)

	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		DirAccess.remove_absolute(path)
		_set_busy(false)
		_set_status("Download failed (result %d, HTTP %d)." % [result, code])
		return

	_pending_bundle_path = path
	_pending_kind = UpdateKind.APP
	_pending_is_download = true
	_start_install()

func _on_dartboard_update_pressed() -> void:
	_set_status("Looking for a USB drive...")
	_clear_bundle_list()

	var found: Array[Dictionary] = []
	for path in _find_files(DARTBOARD_FILE_EXTENSION, DARTBOARD_FILE_PREFIX):
		var info := _read_dartboard_file_info(path)
		if info.ok:
			found.append({"path": path, "version": info.version})
	if found.is_empty():
		_set_status("No valid DartBoard Interface update found on USB.")
		return

	_set_status("Found %d DartBoard Interface update(s) on USB. Choose one:" % found.size())
	for item in found:
		_add_list_button(
			"%s (v%s)" % [item.path.get_file(), item.version],
			_on_dartboard_file_selected.bind(item.path, item.version))
	bundle_scroll.visible = true

func _add_list_button(text: String, on_pressed: Callable) -> void:
	var button := Button.new()
	button.theme_type_variation = &"RowButton"
	button.text = text
	button.custom_minimum_size = Vector2(0, 90)
	button.add_theme_font_size_override("font_size", 32)
	button.pressed.connect(on_pressed)
	PressScale.attach(button)
	bundle_list.add_child(button)

func _clear_bundle_list() -> void:
	bundle_scroll.visible = false
	for child in bundle_list.get_children():
		bundle_list.remove_child(child)
		child.queue_free()

## Liste les fichiers directement sous UPDATE_DIR ayant l'extension (et le
## prefixe, s'il n'est pas vide) donnes, tries par nom. Renvoie un tableau
## vide si le dossier n'existe pas (pas de cle montee) ou ne contient rien
## de correspondant.
func _find_files(extension: String, prefix: String) -> Array[String]:
	var paths: Array[String] = []
	var dir := DirAccess.open(UPDATE_DIR)
	if dir == null:
		return paths

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.ends_with(extension) and entry.begins_with(prefix):
			paths.append(UPDATE_DIR.path_join(entry))
		entry = dir.get_next()
	dir.list_dir_end()

	paths.sort()
	return paths

func _on_bundle_selected(path: String) -> void:
	var info := _read_bundle_info(path)
	if not info.ok:
		_set_status("Could not read %s: %s" % [path.get_file(), info.error])
		return

	_pending_bundle_path = path
	_pending_kind = UpdateKind.APP
	_pending_is_download = false
	_confirm_action = ConfirmAction.UPGRADE
	confirm_label.text = "Application v%s\nDo you want to upgrade?" % info.version
	confirm_overlay.visible = true

func _on_dartboard_file_selected(path: String, target_version: String) -> void:
	var current_version := _read_alive_version()
	var current_text := ("v" + current_version) if current_version != "" else "unknown"

	_pending_bundle_path = path
	_pending_kind = UpdateKind.DARTBOARD
	_pending_target_version = target_version
	_confirm_action = ConfirmAction.UPGRADE
	confirm_label.text = "DartBoard Interface\n%s -> v%s\nDo you want to upgrade?" % [current_text, target_version]
	confirm_overlay.visible = true

## Lit le manifeste du bundle via `rauc info` (verifie sa structure, pas sa
## signature : `udg-app-selector.sh --install` la verifiera de toute facon).
func _read_bundle_info(path: String) -> Dictionary:
	var output := []
	var exit_code := OS.execute("rauc", ["info", path], output, true)
	var text: String = output[0] if output.size() > 0 else ""
	if exit_code != 0:
		# Derniere ligne de la sortie de rauc (le motif de l'echec y figure).
		var lines := text.strip_edges().split("
")
		var reason: String = lines[lines.size() - 1].strip_edges() if not lines.is_empty() else ""
		return {"ok": false, "error": "rauc info exited with code %d: %s" % [exit_code, reason]}

	var version := _extract_field(text, "Version")
	if version == "":
		return {"ok": false, "error": "no version field in bundle manifest"}
	return {"ok": true, "version": version, "compatible": _extract_field(text, "Compatible")}

func _extract_field(text: String, field_name: String) -> String:
	var regex := RegEx.new()
	regex.compile("%s:\\s*'([^']*)'" % field_name)
	var result := regex.search(text)
	return result.get_string(1) if result else ""

## Valide un .dpkg via `udg-dartboard-flash --info` (aucun acces au Pico, sans
## effet de bord). Code 0 : valide, la version s'extrait de la sortie ; code 1 :
## invalide, le motif est sur la sortie d'erreur.
func _read_dartboard_file_info(path: String) -> Dictionary:
	var output := []
	var exit_code := OS.execute(DARTBOARD_FLASH_TOOL, ["--info", path], output, true)
	var text: String = output[0] if output.size() > 0 else ""
	if exit_code != 0:
		return {"ok": false, "error": text.strip_edges()}

	var version := _regex_group(text, "version (\\d\\d\\.\\d\\d\\.\\d{4})")
	if version == "":
		return {"ok": false, "error": "no version in udg-dartboard-flash --info output"}
	return {"ok": true, "version": version}

## Interroge le Pico : `alive` -> `#alive-vMM.mm.bbbb#`. Renvoie la version, ou
## "" si le port n'existe pas ou si le Pico ne repond pas (ex. en BOOTSEL). Le
## port doit etre en raw sans echo a chaque ouverture (sinon le pilote tty et
## le firmware se renvoient les caracteres en boucle) ; pas de `timeout` sur
## l'image, d'ou le `cat` en arriere-plan tue apres 1 s.
##
## Les "$" sont echappes : avec un tableau de sortie, OS.execute() passe la
## commande a popen(), donc a un premier shell, en mettant chaque argument
## entre guillemets doubles sans rien echapper. Sans "\$", ce shell-la
## remplacerait $! et $P par du vide avant que le script ne tourne : le `cat`
## ne serait jamais tue et continuerait a lire le port, volant ensuite les
## reponses et les jets destines a DartBoardInput.
func _read_alive_version() -> String:
	var script := (
		"stty -F %s raw -echo && "
		+ "(cat %s > %s & P=\\$!; sleep 0.3; printf 'alive\\r\\n' > %s; sleep 1; kill \\$P) 2>/dev/null; "
		+ "tr -d '\\r' < %s"
	) % [DARTBOARD_PORT, DARTBOARD_PORT, DARTBOARD_ALIVE_LOG, DARTBOARD_PORT, DARTBOARD_ALIVE_LOG]
	var output := []
	if OS.execute("sh", ["-c", script], output, true) != 0 or output.is_empty():
		return ""
	return _regex_group(output[0], "#alive-v(\\d\\d\\.\\d\\d\\.\\d{4})#")

func _regex_group(text: String, pattern: String) -> String:
	var regex := RegEx.new()
	regex.compile(pattern)
	var result := regex.search(text)
	return result.get_string(1) if result else ""

func _on_confirm_no() -> void:
	confirm_overlay.visible = false
	_confirm_action = ConfirmAction.NONE

func _on_confirm_yes() -> void:
	confirm_overlay.visible = false
	var action := _confirm_action
	_confirm_action = ConfirmAction.NONE
	match action:
		ConfirmAction.UPGRADE:
			if _pending_kind == UpdateKind.DARTBOARD:
				_flash_dartboard()
			else:
				_start_install()
		ConfirmAction.DOWNLOAD:
			_start_download()
		ConfirmAction.REBOOT:
			OS.execute("systemctl", ["reboot"])

func _set_busy(busy: bool) -> void:
	check_update_button.disabled = busy
	check_online_button.disabled = busy
	dartboard_update_button.disabled = busy
	dartboard_test_button.disabled = busy
	back_button.disabled = busy

func _start_install() -> void:
	_set_status("Installing update, please wait...")
	_set_busy(true)

	_install_thread = Thread.new()
	_install_thread.start(_install_worker.bind(_pending_bundle_path))

## Tourne sur un thread a part : l'installation peut prendre plusieurs
## dizaines de secondes (ecriture du slot inactif), ce qui gelerait
## l'interface si lance sur le thread principal.
##
## Passe par udg-app-selector.sh --install, PAS par `rauc install`
## directement : confirme cote systeme (udg-yocto) que `rauc install`
## ne peut pas fonctionner pour ce design app-only A/B
## (bootloader=noop empeche RAUC de determiner lui-meme le slot
## inactif, donc il cible toujours le meme slot quel que soit celui
## reellement actif). Le wrapper fait exactement ce que `rauc install`
## aurait du faire : verifie la signature (`rauc extract`) puis ecrit
## dans le slot que l'etat systeme sait etre inactif (`rauc
## write-slot`) - voir udg-yocto/scripts/UPDATE-BUNDLE.md.
func _install_worker(bundle_path: String) -> void:
	var output := []
	var exit_code := OS.execute("/usr/bin/udg-app-selector.sh", ["--install", bundle_path], output, true)
	var log_text: String = output[0] if output.size() > 0 else ""
	call_deferred("_on_install_finished", exit_code, log_text)

## Le nouveau slot n'est pris en compte qu'au prochain demarrage
## (udg-app-selector.sh choisit le slot actif au boot) : sur succes, le
## dialogue de confirmation est reutilise (voir ConfirmAction) pour
## proposer un redemarrage immediat.
func _on_install_finished(exit_code: int, log_text: String) -> void:
	_install_thread.wait_to_finish()
	_install_thread = null
	_set_busy(false)
	if _pending_is_download:
		# Le bundle telecharge n'est plus utile (installe ou en echec).
		DirAccess.remove_absolute(_pending_bundle_path)
		_pending_is_download = false

	if exit_code == 0:
		_set_status("Update installed. Restart to switch to the new version.")
		_confirm_action = ConfirmAction.REBOOT
		confirm_label.text = "Update installed.\nRestart now?"
		confirm_overlay.visible = true
	else:
		_set_status("Update failed: %s" % log_text)

## Sequence du doc DARTBOARD-INTERFACE.md §3.5 (apres la confirmation) :
## flash (processus separe + timeout), attente du port, verification `alive`.
## `udg-dartboard-flash` est bloquant : lance via `sh -c` en processus non
## bloquant dont on sonde la fin, pour pouvoir le tuer au bout de
## DARTBOARD_FLASH_TIMEOUT_S sans thread. Le code retour est ecrit dans un
## fichier (OS.create_process ne le renvoie pas).
func _flash_dartboard() -> void:
	_set_busy(true)
	_set_status("Flashing DartBoard Interface, do not power off...")

	DirAccess.remove_absolute(DARTBOARD_FLASH_RC)
	var command := "%s '%s' > %s 2>&1; echo $? > %s" % [
		DARTBOARD_FLASH_TOOL, _pending_bundle_path, DARTBOARD_FLASH_LOG, DARTBOARD_FLASH_RC]
	var pid := OS.create_process("sh", ["-c", command])
	if pid <= 0:
		_finish_dartboard_update(false, "could not start udg-dartboard-flash")
		return

	var waited := 0.0
	while OS.is_process_running(pid):
		if waited >= DARTBOARD_FLASH_TIMEOUT_S:
			OS.kill(pid)
			_finish_dartboard_update(false, "flash timed out after %d s" % int(DARTBOARD_FLASH_TIMEOUT_S))
			return
		await get_tree().create_timer(0.5).timeout
		waited += 0.5

	var rc := FileAccess.get_file_as_string(DARTBOARD_FLASH_RC).strip_edges()
	if rc != "0":
		var log_text := FileAccess.get_file_as_string(DARTBOARD_FLASH_LOG).strip_edges()
		_finish_dartboard_update(false, log_text if log_text != "" else "udg-dartboard-flash exited with code %s" % rc)
		return

	_set_status("Waiting for the DartBoard Interface to restart...")
	waited = 0.0
	while waited < DARTBOARD_PORT_WAIT_S and OS.execute("test", ["-e", DARTBOARD_PORT]) != 0:
		await get_tree().create_timer(0.5).timeout
		waited += 0.5
	if waited >= DARTBOARD_PORT_WAIT_S:
		_finish_dartboard_update(false, "%s did not reappear (the board may be stuck in BOOTSEL, run the update again)" % DARTBOARD_PORT)
		return

	var new_version := _read_alive_version()
	if new_version == _pending_target_version:
		_finish_dartboard_update(true, "DartBoard Interface updated to v%s." % new_version)
	elif new_version == "":
		_finish_dartboard_update(false, "no answer to `alive` after the update")
	else:
		_finish_dartboard_update(false, "board reports v%s, expected v%s" % [new_version, _pending_target_version])

## Renseigne le bloc d'infos en haut a gauche : version de l'application,
## adresse IP (tout de suite) et version du firmware de la carte
## d'interface (`alive`, dans un thread : ca dure ~1,5 s, ce qui gelerait
## l'ecran a l'ouverture).
func _show_system_info() -> void:
	var app_version: String = ProjectSettings.get_setting("application/config/version", "0.0.0")
	app_version_label.text = "Application: v%s" % app_version
	var ip := _local_ip()
	ip_label.text = "IP: %s" % ip if ip != "" else "No network connection"

	dartboard_version_label.text = "DartBoard firmware: ..."
	_info_thread = Thread.new()
	_info_thread.start(_info_worker)

func _info_worker() -> void:
	call_deferred("_on_dartboard_version_read", _read_alive_version())

func _on_dartboard_version_read(version: String) -> void:
	_info_thread.wait_to_finish()
	_info_thread = null
	_set_dartboard_version(version)

func _set_dartboard_version(version: String) -> void:
	dartboard_version_label.text = "DartBoard firmware: v%s" % version if version != "" \
			else "DartBoard firmware: not connected"

## Premiere adresse IPv4 utilisable (ni loopback ni link-local), ou "" sans reseau.
func _local_ip() -> String:
	for iface in IP.get_local_interfaces():
		if iface.name == "lo":
			continue
		for address: String in iface.addresses:
			if address.contains(":") or address.begins_with("127.") or address.begins_with("169.254."):
				continue
			return address
	return ""

func _finish_dartboard_update(success: bool, message: String) -> void:
	if success:
		_set_dartboard_version(_pending_target_version)
	_set_busy(false)
	_set_status(message if success else "DartBoard Interface update failed: %s" % message)

func _set_status(text: String) -> void:
	status_label.text = text

## Ouvre le dialogue de test et se connecte a la carte
## (DartInputManager.board_input, libre puisqu'aucune partie n'est en cours).
## Attend d'abord la fin de la lecture de version lancee a l'ouverture de
## l'ecran (_read_alive_version, ~1,3 s) et la fin complete d'un test
## precedent : un second lecteur du port volerait reponses et jets, et une
## reponse en vol de l'ancien test arriverait dans le nouveau. Si la
## carte n'est pas branchee (voir dart_board_input.gd), le signale au lieu
## du dialogue.
func _on_dartboard_test_pressed() -> void:
	_test_running = true
	_test_serial += 1
	var serial := _test_serial
	_test_hits = 0
	_test_board_answered = false
	_test_log.clear()
	test_terminal_label.text = ""
	test_version_label.text = "Connecting..."
	test_hit_label.text = "Throw a dart at the target to test it."
	test_overlay.visible = true
	while (_info_thread or _test_loop_running) and _is_current_test(serial):
		await get_tree().process_frame
	if not _is_current_test(serial):
		return

	var board := DartInputManager.board_input
	board.connect_to_board()
	if not board.is_connected_to_board():
		_test_running = false
		test_overlay.visible = false
		_set_status("DartBoard Interface not connected.")
		return
	_test_connected_serial = serial
	_run_dartboard_test(serial)

func _stop_dartboard_test() -> void:
	_test_running = false
	test_overlay.visible = false
	# _run_dartboard_test() constate l'arret, envoie StopWaitingHit et ferme
	# la carte lui-meme une fois la reponse recue : le faire ici couperait
	# une reponse deja en vol.

func _is_current_test(serial: int) -> bool:
	return _test_running and serial == _test_serial

## Deroulement du test, lance par _on_dartboard_test_pressed() : envoie
## `alive` toutes les DARTBOARD_REPLY_TIMEOUT_S jusqu'a la premiere ligne
## recue de la carte (connexion etablie, voir _on_board_line, qui affiche
## aussi la version a l'arrivee de "#alive-v...#", meme en retard), puis arme
## une seule fois `WaitForHits 0` (icd.md 1.1 : un *HIT* par impact, sans
## timeout, jusqu'a StopWaitingHit) ; chaque jet est affiche par
## _on_test_hit(). A la fermeture (bouton Close), envoie StopWaitingHit et
## rend la carte. Commandes envoyees par send_command(), hors de la politique
## de tour de start_waiting()/stop_waiting() (faite pour WaitForHit, qui se
## termine a chaque impact).
func _run_dartboard_test(serial: int) -> void:
	_test_loop_running = true
	var board := DartInputManager.board_input
	while not _test_board_answered and _is_current_test(serial):
		_send_test_command("alive")
		var deadline := Time.get_ticks_msec() + int(DARTBOARD_REPLY_TIMEOUT_S * 1000.0)
		while not _test_board_answered and Time.get_ticks_msec() < deadline \
				and _is_current_test(serial):
			await get_tree().process_frame
	if _is_current_test(serial):
		_send_test_command("WaitForHits 0")

	while _is_current_test(serial):
		await get_tree().process_frame

	# Ferme (bouton Close) ou remplace par un nouveau test, qui attend la fin
	# de celui-ci : arrete l'attente, puis rend la carte.
	board.send_command("StopWaitingHit")
	await _await_reply(func(r: String) -> bool: return r == "#stopped#" or r == "#idle#",
		func() -> bool: return false)
	board.disconnect_from_board()
	_test_loop_running = false

## Jet recu pendant le test (`WaitForHits` continue apres chaque impact :
## rien a rearmer). La ligne brute, avec la zone O/I, est dans le terminal.
func _on_test_hit(hit: DartHit) -> void:
	if not _is_current_test(_test_connected_serial):
		return
	_test_hits += 1
	test_hit_label.text = "Hit %d: %s" % [_test_hits, hit.get_label()]

func _send_test_command(command: String) -> void:
	_log_test_line("TX: %s" % command)
	DartInputManager.board_input.send_command(command)

## Attend une reponse "#...#" de la carte reconnue par accept() (les autres,
## en retard d'une commande precedente, sont ignorees) au plus
## DARTBOARD_REPLY_TIMEOUT_S ; "" si elle n'arrive pas ou si cancelled()
## devient vrai.
func _await_reply(accept: Callable, cancelled: Callable) -> String:
	var board := DartInputManager.board_input
	var reply := [""]
	var on_reply := func(text: String) -> void:
		if reply[0] == "" and accept.call(text):
			reply[0] = text
	board.response_received.connect(on_reply)
	var deadline := Time.get_ticks_msec() + int(DARTBOARD_REPLY_TIMEOUT_S * 1000.0)
	while reply[0] == "" and Time.get_ticks_msec() < deadline and not cancelled.call():
		await get_tree().process_frame
	if board.response_received.is_connected(on_reply):
		board.response_received.disconnect(on_reply)
	return reply[0]

## Ligne brute recue de la carte (DartInputManager.board_input.line_received),
## ajoutee au terminal du test. La premiere prouve que la connexion est
## etablie (fin des `alive`) ; "#alive-v...#" donne la version et une erreur
## de la carte ("#error:...#", ex. WaitForHits inconnu d'un firmware
## anterieur a la v01.01) est affichee.
func _on_board_line(text: String) -> void:
	if not _is_current_test(_test_connected_serial):
		return
	_log_test_line(text)
	if not _test_board_answered:
		_test_board_answered = true
		test_version_label.text = "Connected"
	var line := text.lstrip(">")
	var version := _regex_group(line, "^#alive-v(\\d\\d\\.\\d\\d\\.\\d{4})#$")
	if version != "":
		test_version_label.text = "DartBoard Interface v%s" % version
	elif line.begins_with("#error:"):
		test_hit_label.text = "Board error: %s" % line

func _log_test_line(text: String) -> void:
	_test_log.append(text)
	while _test_log.size() > DARTBOARD_TEST_LOG_LINES:
		_test_log.remove_at(0)
	test_terminal_label.text = "\n".join(_test_log)
