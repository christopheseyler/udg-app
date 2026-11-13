class_name DartBoardInput
extends DartInput

## Source de jets reelle : carte d'interface de la cible (Raspberry Pi Pico,
## firmware udg-dartboard-if). Suit le protocole de
## udg-yocto/doc/DARTBOARD-INTERFACE.md et de l'ICD du firmware
## (udg-dartboardif-rbpico/icd.md) : port stable /dev/udg-dartboard, mode
## brut sans echo (stty), lu en continu par un thread. Chaque ligne recue est
## classee par son premier caractere ("#..." reponse, "*..." evenement, sinon
## echo a ignorer), une fois retire le prompt ">" qui la precede : le firmware
## ne termine pas la ligne apres le prompt, donc un evenement spontane arrive
## colle derriere lui (">*HIT:20-3-N*"). Un evenement
## "*HIT:<valeur>-<mult>-<extra>*" est converti en DartHit et emis via
## hit_detected.
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
## Le port n'est pas ouvert avec FileAccess : sous Linux, FileAccess.open()
## et FileAccess.file_exists() refusent tout ce qui n'est pas un fichier
## regulier, donc un peripherique comme /dev/udg-dartboard. Il passe par deux
## processus lances avec OS.execute_with_pipe() : un lecteur
## (`dd if=PORT`, dont la sortie est lue par le thread) et un ecrivain
## (`cat > PORT`, qui recoit les commandes sur son entree). Deux processus
## distincts : ecrire une commande pendant que le thread est bloque dans une
## lecture ne doit jamais attendre que cette lecture aboutisse.
##
## Le lecteur n'est pas `cat` : celui de busybox copie avec sendfile() et,
## vers un tube, le noyau garde le tube verrouille pendant que la lecture du
## port attend des octets. Ce qui est deja dans le tube n'est alors lu qu'a
## l'arrivee des octets suivants : mesure sur la cible, chaque reponse
## n'arrivait qu'apres la commande suivante, et un HIT jamais. dd lit et
## ecrit (read/write), et transmet tout de suite chaque lecture partielle.
##
## Instance precedente tuee ou plantee pendant une partie (redemarrage du
## service, remplacement du jeu) : Godot n'arrete pas ses processus lecteur et
## ecrivain, qui lui survivent ouverts sur le port. Un lecteur survivant vole
## des lignes de la carte et, constate sur la cible, fait perdre la connexion
## au nouveau lecteur. connect_to_board() libere donc d'abord le port de tout
## processus qui le tient encore (_release_stale_port_users), puis annule
## l'attente que l'instance precedente a pu laisser armee (StopWaitingHit :
## sinon WaitForHit repond #error:busy#). Une connexion perdue en cours de
## partie est signalee par connection_lost (DartInputManager se reconnecte).
##
## send_command()/response_received permettent d'envoyer une commande
## quelconque (alive, scan, help, ...) et de recuperer sa reponse "#...#",
## en dehors de la politique de tour ; utilise par l'ecran Settings pour le
## test de l'interface (voir settings_screen.gd), qui affiche aussi les lignes
## brutes recues (line_received).

const PORT := "/dev/udg-dartboard"
const HIT_EVENT_PATTERN := "^\\*HIT:(\\d+)-(\\d+)-([A-Za-z])\\*$"

## Emis (sur le thread principal) pour chaque reponse "#...#" recue, guillemets
## compris (ex. "#alive-v01.00.0000#", "#3,4 5,2#", "##").
signal response_received(text: String)

## Emis (sur le thread principal) pour chaque ligne recue, brute (prompt, echo,
## reponse ou evenement, ex. ">scan", "#3,4#", ">*HIT:20-3-N*"), avant
## response_received/hit_detected : terminal du test de l'ecran Settings.
signal line_received(text: String)

## Emis quand la connexion se perd sans avoir ete demandee (le processus
## lecteur s'est arrete) ; la carte est alors deconnectee.
signal connection_lost

## Sortie du processus lecteur (dd if=PORT) et entree du processus ecrivain
## (cat > PORT), voir connect_to_board().
var _read_file: FileAccess
var _write_file: FileAccess
var _reader_pid := -1
var _writer_pid := -1
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

## Vrai si le lien du port existe. Pas FileAccess.file_exists(), toujours faux
## pour un peripherique (voir plus haut) ; DirAccess n'exclut que les dossiers.
static func _port_exists() -> bool:
	var dev := DirAccess.open(PORT.get_base_dir())
	return dev != null and dev.file_exists(PORT)

## Libere le port des processus restes d'une instance precedente, passe le
## port en mode brut sans echo, lance les processus lecteur et ecrivain puis
## le thread de lecture, et annule toute attente deja armee sur la carte. Ne
## fait rien si la carte n'est pas branchee ou deja connectee.
func connect_to_board() -> void:
	if _connected:
		return
	if not _port_exists():
		return
	_release_stale_port_users()
	# Avant que les processus n'ouvrent le port : avec l'echo du pilote tty,
	# carte et hote s'echangeraient les caracteres en boucle
	# (DARTBOARD-INTERFACE.md §2.2).
	if OS.execute("stty", ["-F", PORT, "raw", "-echo"], [], true) != 0:
		push_warning("DartBoardInput: stty a echoue sur %s, carte ignoree" % PORT)
		return

	# Pas `cat PORT` (voir plus haut). Sans iflag=fullblock, dd ecrit chaque
	# lecture partielle des qu'elle revient.
	var reader := OS.execute_with_pipe("dd", ["if=" + PORT, "bs=256"])
	if reader.is_empty():
		push_warning("DartBoardInput: impossible de lancer la lecture de %s" % PORT)
		return
	var writer := OS.execute_with_pipe("sh", ["-c", "exec cat > %s" % PORT])
	if writer.is_empty():
		push_warning("DartBoardInput: impossible de lancer l'ecriture sur %s" % PORT)
		OS.kill(reader["pid"])
		return

	_read_file = reader["stdio"]
	_reader_pid = reader["pid"]
	_write_file = writer["stdio"]
	_writer_pid = writer["pid"]
	_connected = true
	_waiting = false
	_stop_requested = false
	_read_thread = Thread.new()
	_read_thread.start(_read_loop)
	# Attente laissee armee par une instance precedente (#idle# sinon) :
	# WaitForHit repondrait #error:busy#.
	_send_line("StopWaitingHit")

## Tue les processus qui tiennent encore le port (lecteur et ecrivain d'une
## instance precedente du jeu, voir plus haut) et attend leur fin, au plus
## une seconde, avant que le nouveau lecteur ne l'ouvre. Aucun de nos propres
## processus ne le tient ici : on n'est pas connecte.
func _release_stale_port_users() -> void:
	var script := "fuser -k %s >/dev/null 2>&1; i=0; " % PORT \
		+ "while fuser %s >/dev/null 2>&1 && [ $i -lt 20 ]; do sleep 0.05; i=$((i+1)); done" % PORT
	OS.execute("sh", ["-c", script])

## Arrete les processus lecteur et ecrivain et le thread de lecture ; libere
## la carte pour un autre usage (ex : mise a jour du firmware depuis l'ecran
## Settings). No-op si deja deconnecte.
func disconnect_from_board() -> void:
	if not _connected:
		return
	_connected = false
	_waiting = false
	_stop_requested = true
	if _write_file:
		_write_file.close()
		_write_file = null
	# OS.kill() attend la fin du processus (et le recolte). Tuer le lecteur
	# ferme son tube de sortie, ce qui debloque le get_line() en cours dans
	# le thread. Le thread ferme _read_file lui-meme (voir _read_loop) ; le
	# manipuler depuis ce thread-ci serait une course.
	OS.kill(_writer_pid)
	OS.kill(_reader_pid)
	if _read_thread:
		_read_thread.wait_to_finish()
		_read_thread = null
	_read_file = null
	_reader_pid = -1
	_writer_pid = -1

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

## Envoie une commande brute (alive, scan, help, ...) sans suivre de
## protocole particulier : la reponse arrive via response_received. No-op si
## la carte n'est pas connectee.
func send_command(command: String) -> void:
	if not _connected:
		return
	_send_line(command)

func _send_line(command: String) -> void:
	if _write_file:
		_write_file.store_string(command + "\r\n")

## Tourne dans _read_thread : lecture bloquante ligne par ligne. Les
## evenements *HIT:...* et les reponses #...# sont postes sur le thread
## principal via call_deferred (DartHit et les signaux ne doivent etre
## manipules que la-bas) ; le prompt ">" et l'echo sont ignores.
func _read_loop() -> void:
	var file := _read_file
	while not _stop_requested:
		var raw := file.get_line().strip_edges()
		var err := file.get_error()
		if _stop_requested:
			break
		if err != OK:
			call_deferred("_on_port_lost")
			break
		call_deferred("_on_raw_line", raw)
		# Le prompt ">" n'est jamais suivi d'une fin de ligne : il prefixe la
		# ligne suivante (echo de commande ou evenement *...*).
		var line := raw.lstrip(">")
		if line.begins_with("*"):
			call_deferred("_on_event_line", line)
		elif line.begins_with("#"):
			call_deferred("_on_response_line", line)
	file.close()

func _on_raw_line(line: String) -> void:
	line_received.emit(line)

func _on_response_line(line: String) -> void:
	response_received.emit(line)

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
	if not _connected:
		return
	push_warning("DartBoardInput: connexion a %s perdue" % PORT)
	disconnect_from_board()
	connection_lost.emit()
