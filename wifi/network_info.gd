class_name NetworkInfo
extends RefCounted

## Interfaces reseau de la machine, separees en filaires et sans fil, pour
## les onglets Information et Network de l'ecran Settings.
##
## Sous Linux (la borne), une interface est sans fil si elle a un dossier
## /sys/class/net/<nom>/wireless, et son lien est monte si
## /sys/class/net/<nom>/carrier vaut 1. Ailleurs (PC de dev), on se contente
## du nom donne par IP.get_local_interfaces().

## Liste des interfaces (sauf loopback) : {name, wireless, ip, carrier}.
## `ip` est la premiere IPv4 utilisable ("" sans adresse) ; `carrier` est vrai
## si le cable est branche (filaire) ou le lien etabli (sans fil).
static func interfaces() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var linux := OS.get_name() == "Linux"
	var seen := {}
	for iface in IP.get_local_interfaces():
		var iface_name: String = iface.name
		if iface_name == "lo" or seen.has(iface_name):
			continue
		seen[iface_name] = true
		var label: String = iface.get("friendly", iface_name)
		var wireless := false
		var carrier := true
		if linux:
			wireless = DirAccess.dir_exists_absolute("/sys/class/net/%s/wireless" % iface_name)
			carrier = FileAccess.get_file_as_string("/sys/class/net/%s/carrier" % iface_name).strip_edges() == "1"
		else:
			wireless = label.to_lower().contains("wi-fi") or label.to_lower().contains("wireless")
		result.append({"name": iface_name, "label": label, "wireless": wireless,
				"ip": _ipv4(iface.addresses), "carrier": carrier})
	if linux:
		# Une interface sans adresse n'est pas toujours listee par
		# IP.get_local_interfaces() : on complete avec /sys/class/net, pour
		# afficher "cable debranche" plutot que rien.
		var dir := DirAccess.open("/sys/class/net")
		if dir:
			for iface_name in dir.get_directories():
				if iface_name == "lo" or seen.has(iface_name):
					continue
				result.append({"name": iface_name, "label": iface_name,
						"wireless": DirAccess.dir_exists_absolute("/sys/class/net/%s/wireless" % iface_name),
						"ip": "", "carrier": FileAccess.get_file_as_string("/sys/class/net/%s/carrier" % iface_name).strip_edges() == "1"})
	return result

## Premiere IPv4 utilisable des interfaces filaires (wireless = false) ou
## sans fil (wireless = true), ou "".
static func first_ip(wireless: bool) -> String:
	for iface in interfaces():
		if iface.wireless == wireless and iface.ip != "":
			return iface.ip
	return ""

## Premiere IPv4 ni loopback ni link-local, ou "".
static func _ipv4(addresses: Array) -> String:
	for address: String in addresses:
		if address.contains(":") or address.begins_with("127.") or address.begins_with("169.254."):
			continue
		return address
	return ""
