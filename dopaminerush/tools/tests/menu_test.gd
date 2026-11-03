extends SceneTree

# Godot --headless --path . --script res://tools/tests/menu_test.gd
#
# Prueba el menu principal:
#   - no se guarda nada en disco: cada vez que se abre el juego arranca de
#     cero, con la habitacion de fondo
#   - los volumenes: 100 % es la mezcla tal cual, 50 % son 6 dB menos, 0 %
#     es mudo; Videos mueve los dos buses de video; el agache del
#     AudioManager vuelve al volumen del jugador
#   - el fondo es la habitacion, o el parque si el juego ya se termino
#   - en el fondo no queda nada del juego: ni jugador, ni interfaces, ni
#     sonidos propios, ni scripts andando (salvo la luz del dia)
#   - la camara paneá entre sus limites, sin dar la vuelta
#   - la pestaña Sonido tiene un control por grupo y mueve los buses
const MENU := "res://escenas/00_menu/menu.tscn"

var _fallos: int = 0
var _cfg_viejo: bool = false


func _initialize() -> void:
	call_deferred("_probar")


func _comprobar(condicion: bool, mensaje: String) -> void:
	if not condicion:
		_fallos += 1
		push_error("[Menu TEST] " + mensaje)


func _vol(bus: String) -> float:
	return AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus))


func _probar() -> void:
	create_timer(90.0).timeout.connect(func(): quit(2))
	# Si quedo un archivo de la version que guardaba, no tiene que leerse
	_cfg_viejo = FileAccess.file_exists("user://ajustes.cfg")
	Ajustes._config = null
	_comprobar(not Ajustes.juego_completado(), "Al abrir el juego, nunca esta terminado: el fondo es la habitacion")
	_comprobar(is_equal_approx(Ajustes.volumen("musica"), 1.0), "Y los volumenes arrancan al 100 %")
	var base_apps := _vol("Apps")
	var base_video := _vol("Video")
	var base_slop := _vol("Slop")

	# ---- volumenes ----
	_comprobar(Ajustes.db_usuario("Apps") == 0.0, "Antes del menu, el jugador no suma nada (los tests ven la mezcla)")
	Ajustes.aplicar_audio()
	_comprobar(is_equal_approx(_vol("Apps"), base_apps), "Al 100 %, la mezcla queda tal cual")
	Ajustes.poner_volumen("apps", 0.5)
	_comprobar(absf(_vol("Apps") - (base_apps - 6.02)) < 0.05, "Al 50 %%, 6 dB menos (%.2f)" % (_vol("Apps") - base_apps))
	Ajustes.poner_volumen("videos", 0.5)
	_comprobar(absf(_vol("Video") - (base_video - 6.02)) < 0.05 and absf(_vol("Slop") - (base_slop - 6.02)) < 0.05,
		"Videos baja los dos buses de video")
	Ajustes.poner_volumen("apps", 0.0)
	_comprobar(AudioServer.is_bus_mute(AudioServer.get_bus_index("Apps")), "Al 0 %, mudo")
	Ajustes.poner_volumen("apps", 0.5)
	_comprobar(not AudioServer.is_bus_mute(AudioServer.get_bus_index("Apps")), "Y vuelve")
	var am = root.get_node("AudioManager")
	am.agachar(true)
	await create_timer(0.6).timeout
	am.agachar(false)
	await create_timer(0.6).timeout
	_comprobar(absf(_vol("Apps") - (base_apps - 6.02)) < 0.1,
		"El agache vuelve al volumen del jugador, no al de la mezcla (%.2f)" % _vol("Apps"))
	Ajustes.poner_volumen("apps", 1.0)
	Ajustes.poner_volumen("videos", 1.0)

	# ---- el menu con la habitacion ----
	var menu = load(MENU).instantiate()
	root.add_child(menu)
	await create_timer(0.5).timeout
	var fondo = menu._fondo
	_comprobar(fondo.lugar == "habitacion", "Sin terminar el juego, el fondo es la habitacion")
	var escena: Node = fondo.get_child(0)
	_comprobar(escena.find_child("Jugador", true, false) == null, "En el fondo no hay jugador")
	_comprobar(escena.find_children("*", "CanvasLayer", true, false).is_empty(), "Ni interfaces del juego")
	_comprobar(escena.find_children("*", "AudioStreamPlayer3D", true, false).is_empty(), "Ni sonidos de la escena")
	var con_script := 0
	for n in escena.find_children("*", "", true, false):
		if n.get_script() != null and n.name != "CicloDia":
			con_script += 1
	_comprobar(con_script == 0 and escena.get_script() == null, "Ningun script del juego anda (%d)" % con_script)
	_comprobar(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "El mouse se ve")
	_comprobar(fondo.camara.current, "La camara del fondo es la que se ve")
	var sonidos_pieza: Array = fondo._ambiente.map(func(r): return r.stream.resource_path.get_file())
	_comprobar(sonidos_pieza == ["zumbido.ogg"], "En la habitacion, casi silencio: solo el zumbido (%s)" % str(sonidos_pieza))
	_comprobar(fondo._ambiente[0].get_meta("volumen") <= -28.0, "Y muy bajito")

	# El paneo: nunca se pasa de sus limites
	var base_frente: Vector3 = -fondo._base.basis.z
	var maximo := 0.0
	for i in 40:
		fondo._tiempo = fondo._toma["periodo"] * i / 40.0
		fondo._mover_camara()
		var frente: Vector3 = -fondo.camara.global_basis.z
		var giro := rad_to_deg(Vector2(base_frente.x, base_frente.z).angle_to(Vector2(frente.x, frente.z)))
		maximo = maxf(maximo, absf(giro))
	_comprobar(maximo <= fondo._toma["amplitud"] + 0.5 and maximo > fondo._toma["amplitud"] * 0.8,
		"El paneo va y viene dentro de sus limites (%.1f de %.1f grados)" % [maximo, fondo._toma["amplitud"]])

	# ---- la pestaña Sonido ----
	await create_timer(2.2).timeout
	_comprobar(menu._pantalla == menu.Pantalla.PRINCIPAL, "Terminada la entrada, el menu responde")
	menu._abrir_sonido()
	await create_timer(0.7).timeout
	_comprobar(menu._bloque_sonido.visible and not menu._bloque_principal.visible, "Sonido reemplaza al titulo y los botones")
	_comprobar(menu._opciones_sonido.size() == Ajustes.GRUPOS.size() + 1, "Un control por grupo, y Volver")
	# Cada barra mueve TODOS sus buses (y solo esos)
	for i in Ajustes.GRUPOS.size():
		var grupo: Dictionary = Ajustes.GRUPOS[i]
		var barra: HSlider = menu._opciones_sonido[i].get_meta("foco")
		var antes := {}
		for g in Ajustes.GRUPOS:
			for bus in g["buses"]:
				antes[bus] = _vol(bus)
		barra.value = 25
		for bus in antes:
			var cambio: float = _vol(bus) - antes[bus]
			if bus in grupo["buses"]:
				_comprobar(absf(cambio - linear_to_db(0.25)) < 0.05,
					"La barra %s baja el bus %s (%.1f dB)" % [grupo["nombre"], bus, cambio])
			else:
				_comprobar(absf(cambio) < 0.01, "La barra %s no toca el bus %s" % [grupo["nombre"], bus])
		barra.value = 100
	menu._pantalla = menu.Pantalla.SONIDO
	menu._cerrar_sonido()
	await create_timer(0.7).timeout
	_comprobar(not FileAccess.file_exists("user://ajustes.cfg") or _cfg_viejo,
		"No se escribe ningun archivo de ajustes")
	menu.queue_free()
	await process_frame

	# ---- terminado el juego: el parque ----
	Ajustes._cfg().set_value("progreso", "completado", true)
	menu = load(MENU).instantiate()
	root.add_child(menu)
	await create_timer(0.5).timeout
	_comprobar(menu._fondo.lugar == "parque", "Terminado el juego, el fondo es el parque")
	var parque: Node = menu._fondo.get_child(0)
	_comprobar(parque.find_child("Perrito", true, false) == null and parque.find_child("Jugador", true, false) == null,
		"Sin perro ni jugador")
	var sonidos_parque: Array = menu._fondo._ambiente.map(func(r): return r.stream.resource_path.get_file())
	_comprobar("pajaros.ogg" in sonidos_parque, "En el parque si suenan los pajaros")
	menu.queue_free()
	await process_frame
	Ajustes._config = null

	print("[Menu TEST] completado; fallos=", _fallos)
	quit(_fallos)
