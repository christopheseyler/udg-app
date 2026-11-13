extends Node

## WiFi de la borne, autoload "UdgWifi". Repris de l'exemple fourni par
## udg-yocto (doc/godot/udg_wifi.gd, branche wifi-support) ; le contrat de
## l'outil (champs, codes d'erreur) est dans doc/WIFI-INTERFACE.md de ce
## depot.
##
##     var st: Dictionary = await UdgWifi.status()   # {"available": true, "state": "connected", "ssid": ..., "ip": ...}
##     var sc: Dictionary = await UdgWifi.scan()     # {"ok": true, "networks": [{"ssid": ..., "bars": ..., "security": ...}]}
##     var r: Dictionary = await UdgWifi.join("Livebox-1234", password)
##     if not r.ok:
##         show_error(r.error)            # "wrong_password", "not_found", ...
##
## Chaque appel lance /usr/bin/udg-wifi de l'image dans un thread (un scan
## dure quelques secondes, une connexion jusqu'a ~50 s) et reprend
## l'appelant avec la reponse JSON de l'outil. Les appels passent un par un,
## dans l'ordre : jamais de "busy". Les nombres reviennent en float (JSON de
## Godot) : int(net.signal).
##
## Ajout par rapport a l'exemple : avec la variable d'environnement
## UDG_WIFI_FAKE=1, les reponses sont simulees (reseaux fictifs, mot de passe
## "password" accepte, delais raccourcis), pour travailler l'ecran sur PC ou
## l'outil n'existe pas.

const TOOL := "/usr/bin/udg-wifi"
## Mot de passe accepte par la simulation.
const FAKE_PASSWORD := "password"

signal _idle

var _busy := false
var _fake := OS.get_environment("UDG_WIFI_FAKE") == "1"
var _fake_connected := "Livebox-1234"
var _fake_saved: Array[String] = ["Livebox-1234"]

## Faux sur un PC de dev (pas d'udg-wifi) : l'ecran cache le WiFi.
func is_supported() -> bool:
	return _fake or (OS.get_name() == "Linux" and FileAccess.file_exists(TOOL))

## Etat courant. "available" faux : pas de WiFi sur cette machine ou carte.
func status() -> Dictionary:
	if not is_supported():
		return {"ok": true, "available": false, "state": "unavailable", "reason": "no_tool"}
	return await _run(PackedStringArray(["status"]))

## Reseaux a portee, du plus fort au plus faible.
func scan() -> Dictionary:
	return await _run(PackedStringArray(["scan"]))

## Reseaux enregistres sur la borne.
func saved() -> Dictionary:
	return await _run(PackedStringArray(["saved"]))

## Rejoint un reseau et, si ca marche, l'enregistre : la borne s'y reconnecte
## a chaque demarrage. Mot de passe vide : reseau ouvert. hidden : reseau qui
## ne diffuse pas son nom (saisi a la main).
func join(ssid: String, password: String = "", hidden: bool = false) -> Dictionary:
	var args := PackedStringArray(["connect"])
	if hidden:
		args.append("--hidden")
	# "--" : un SSID qui commence par "--" reste un SSID.
	args.append("--")
	args.append(ssid)
	if password != "":
		args.append(password)
	return await _run(args)

## Supprime un reseau enregistre (deconnecte si c'est le reseau courant).
func forget(ssid: String) -> Dictionary:
	return await _run(PackedStringArray(["forget", "--", ssid]))

func _run(args: PackedStringArray) -> Dictionary:
	if not is_supported():
		return {"ok": false, "error": "unavailable", "message": "udg-wifi not found (not on the cabinet)"}
	while _busy:
		await _idle
	_busy = true
	var result: Dictionary
	if _fake:
		result = await _fake_run(args)
	else:
		var thread := Thread.new()
		if thread.start(_execute.bind(args)) != OK:
			result = {"ok": false, "error": "internal", "message": "cannot start a thread"}
		else:
			# Sonde a chaque image plutot que bloquer : le jeu continue.
			while thread.is_alive():
				await get_tree().process_frame
			result = thread.wait_to_finish()
	_busy = false
	_idle.emit()
	return result

# Thread de travail : seulement OS.execute et JSON, aucun acces a la scene.
# Ne jamais logguer args : ils contiennent le mot de passe WiFi.
func _execute(args: PackedStringArray) -> Dictionary:
	var output := []
	var code := OS.execute(TOOL, args, output)
	var text: String = output[0] if not output.is_empty() else ""
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	return {"ok": false, "error": "bad_output",
			"message": "udg-wifi exit %d: %s" % [code, text.strip_edges().left(200)]}

## Simulation (UDG_WIFI_FAKE=1), memes formes de reponse que l'outil.
func _fake_run(args: PackedStringArray) -> Dictionary:
	match args[0]:
		"status":
			if _fake_connected == "":
				return {"ok": true, "available": true, "interface": "wlan0", "state": "disconnected", "ip": null}
			return {"ok": true, "available": true, "interface": "wlan0", "state": "connected",
					"ssid": _fake_connected, "ip": "192.168.1.23", "signal": -52.0, "bars": 4.0,
					"band": "2.4GHz"}
		"scan":
			await get_tree().create_timer(1.5).timeout
			var networks := []
			for n in [["Livebox-1234", -48, 4, "wpa"], ["Café du coin", -70, 2, "open"],
					["Bbox-ABCD", -61, 3, "wpa3"], ["Freebox-5G", -75, 1, "wpa"],
					["Corporate", -66, 2, "enterprise"], ["Old router", -80, 1, "wep"]]:
				networks.append({"ssid": n[0], "signal": float(n[1]), "bars": float(n[2]),
						"band": "2.4GHz", "security": n[3],
						"supported": n[3] in ["open", "wpa", "wpa3"],
						"saved": n[0] in _fake_saved, "connected": n[0] == _fake_connected})
			return {"ok": true, "fresh": true, "networks": networks}
		"saved":
			var saved_list := []
			for s in _fake_saved:
				saved_list.append({"ssid": s, "connected": s == _fake_connected, "disabled": false})
			return {"ok": true, "networks": saved_list}
		"connect":
			await get_tree().create_timer(3.0).timeout
			var rest := args.slice(args.find("--") + 1)
			var ssid: String = rest[0]
			var password: String = rest[1] if rest.size() > 1 else ""
			if password != "" and (password.length() < 8 or password.length() > 63):
				return {"ok": false, "error": "invalid_password", "message": "8 to 63 characters"}
			if ssid != "Café du coin" and password != FAKE_PASSWORD:
				return {"ok": false, "error": "wrong_password", "message": "4-way handshake failed"}
			_fake_connected = ssid
			if not ssid in _fake_saved:
				_fake_saved.append(ssid)
			return {"ok": true, "ssid": ssid, "ip": "192.168.1.23"}
		"forget":
			var ssid: String = args[args.size() - 1]
			_fake_saved.erase(ssid)
			if _fake_connected == ssid:
				_fake_connected = ""
			return {"ok": true, "removed": 1}
	return {"ok": false, "error": "internal", "message": "unknown command"}
