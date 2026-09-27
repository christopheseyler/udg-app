class_name DartBoardInput
extends DartInput

## Source de jets reelle : carte d'interface de la cible (Raspberry Pi Pico,
## firmware udg-dartboard-if). Suit le protocole de
## udg-yocto/doc/DARTBOARD-INTERFACE.md et de l'ICD du firmware
## (udg-dartboardif-rbpico/icd.md) : port stable /dev/udg-dartboard, mode
## brut sans echo (stty), lu en continu par un thread. Chaque ligne recue est
## classee par son premier caractere ("#..." reponse, "*..." evenement, ">"
## prompt, sinon echo a ignorer) ; un evenement "*HIT:<valeur>-<mult>-<extra>*"
## est converti en DartHit et emis via hit_detected.
##
## Le tour est pilote de l'exterieur : start_waiting() arme WaitForHit sans
## timeout (voir DartInputManager.start_turn(), appele au debut du tour puis
## reargue apres chaque jet tant qu'il en reste) et stop_waiting() envoie
## StopWaitingHit (bouton Next player, ou jet lance via le simulateur tenu en
## parallele - voir DartInputManager).
##
## Si la carte n'est pas branchee, le lien /dev/udg-dartboard n'existe pas
## (il ne l'est que lorsque le firmware tourne) : connect_to_board() echoue
## alors silencieusement et toutes les autres methodes deviennent des no-op,
## le jeu continuant avec le seul simulateur.
##
## Lecture et ecriture utilisent deux FileAccess distincts (deux ouvertures
## du meme peripherique) : ecrire une commande pendant que le thread est
## bloque dans une lecture ne doit jamais attendre que cette lecture
## aboutisse.

const PORT := "/dev/udg-dartboard"
const HIT_EVENT_PATTERN := "^\\*HIT:(\\d+)-(\\d+)-([A-Za-z])\\*$"

var _read_file: FileAccess
var _write_file: FileAccess
var _read_thread: Thread
var _connected := false
var _waiting := false
var _stop_requested := false

var _hit_regex := RegEx.new()

func _init() -> void:
	_hit_regex.compile(HIT_EVENT_PATTERN)

func _exit_tree() -> void:
	disconnect_from_board()

func is_connected_to_board() -> bool:
	return _connected

## Ouvre le port (mode brut, sans echo) et demarre le thread de lecture.
## Ne fait rien si la carte n'est pas branchee ou deja connectee.
func connect_to_board() -> void:
	if _connected:
		return
	if not FileAccess.file_exists(PORT):
		return
	if OS.execute("stty", ["-F", PORT, "raw", "-echo"], [], true) != 0:
		push_warning("DartBoardInput: stty a echoue sur %s, carte ignoree" % PORT)
		return

	var read_file := FileAccess.open(PORT, FileAccess.READ_WRITE)
	if read_file == null:
		push_warning("DartBoardInput: impossible d'ouvrir %s en lecture (%s)" % [PORT, error_string(FileAccess.get_open_error())])
		return
	var write_file := FileAccess.open(PORT, FileAccess.READ_WRITE)
	if write_file == null:
		push_warning("DartBoardInput: impossible d'ouvrir %s en ecriture (%s)" % [PORT, error_string(FileAccess.get_open_error())])
		read_file.close()
		return

	_read_file = read_file
	_write_file = write_file
	_connected = true
	_waiting = false
	_stop_requested = false
	_read_thread = Thread.new()
	_read_thread.start(_read_loop)

## Ferme le port et arrete le thread de lecture ; libere la carte pour un
## autre usage (ex : mise a jour du firmware depuis l'ecran Settings). No-op
## si deja deconnecte.
func disconnect_from_board() -> void:
	if not _connected:
		return
	_connected = false
	_waiting = false
	_stop_requested = true
	# Debloque le get_line() en cours dans le thread : n'importe quelle
	# commande provoque une reponse du firmware (voir icd.md), "alive" est
	# valide dans tous les etats. Le thread ferme _read_file lui-meme (voir
	# _read_loop) ; le manipuler depuis ce thread-ci serait une course.
	if _write_file:
		_write_file.store_string("alive\r\n")
	if _read_thread:
		_read_thread.wait_to_finish()
		_read_thread = null
	if _write_file:
		_write_file.close()
		_write_file = null
	_read_file = null

## Arme l'attente d'un jet, sans timeout (icd.md : WaitForHit 0 = pas de
## timeout). No-op si la carte n'est pas connectee ou deja en attente.
func start_waiting() -> void:
	if not _connected or _waiting:
		return
	_waiting = true
	_send_line("WaitForHit 0")

## Interrompt l'attente en cours. No-op si la carte n'est pas connectee ou
## pas en attente.
func stop_waiting() -> void:
	if not _connected or not _waiting:
		return
	_waiting = false
	_send_line("StopWaitingHit")

func _send_line(command: String) -> void:
	if _write_file:
		_write_file.store_string(command + "\r\n")

## Tourne dans _read_thread : lecture bloquante ligne par ligne. Seuls les
## evenements *HIT:...* nous interessent ici (pas de suivi commande/reponse,
## la politique de tour n'en a pas besoin) ; ils sont postes sur le thread
## principal via call_deferred, DartHit ne devant etre manipule que la-bas.
func _read_loop() -> void:
	var file := _read_file
	while not _stop_requested:
		var line := file.get_line().strip_edges()
		var err := file.get_error()
		if _stop_requested:
			break
		if err != OK:
			call_deferred("_on_port_lost")
			break
		if line.begins_with("*"):
			call_deferred("_on_event_line", line)
	file.close()

func _on_event_line(line: String) -> void:
	var result := _hit_regex.search(line)
	if result == null:
		return
	# Le HIT met fin a l'attente en cours cote firmware ; c'est au jeu de
	# reargue (DartInputManager.start_turn()) s'il reste des flechettes.
	_waiting = false
	var extra := result.get_string(3).to_upper()
	if extra == "T":
		# Ne devrait pas arriver : le tour est toujours arme sans timeout.
		return
	var value := int(result.get_string(1))
	var multiplier := int(result.get_string(2))
	if value == DartHit.MISS_SEGMENT or multiplier == 0:
		hit_detected.emit(DartHit.miss())
	else:
		hit_detected.emit(DartHit.create(value, multiplier))

func _on_port_lost() -> void:
	if _connected:
		push_warning("DartBoardInput: connexion a %s perdue" % PORT)
	disconnect_from_board()
