extends SceneTree

# Godot --headless --path . --script res://tools/tests/tutorial_test.gd
#
# Prueba los tutoriales y la regla del reloj:
#   - el reloj no corre mientras se explora la pieza
#   - el cartel de la barra sale al arrancar la compu, frena el inicio de
#     la sesion hasta que se aprieta E, y apunta a la barra
#   - el pensamiento de la primera vez en TikBrainRot congela el juego
#     entero y, al cerrarlo, el jugador SIGUE sentado
#   - la oferta es una notificacion del sistema: entra por la derecha,
#     queda arriba de todo (tambien del tropiezo), suena UNA vez, y su
#     boton abre la app, que dice su propio pensamiento la primera vez
#   - LinkedOut, la primera vez que aparece sola, tambien piensa algo
#   - cada tutorial sale una sola vez: el dia nuevo no los repite, la
#     partida nueva (el menu) si
var _fallos: int = 0


func _initialize() -> void:
	call_deferred("_probar")


func _comprobar(condicion: bool, mensaje: String) -> void:
	if not condicion:
		_fallos += 1
		push_error("[Tutorial TEST] " + mensaje)


# La E entra por el mismo camino que una tecla real. Input.action_press()
# no sirve aca: la ve un _process, pero no una corrutina que espera
# frames (y el cartel de la barra espera asi). parse_input_event si.
func _apretar_e() -> void:
	var baja := InputEventAction.new()
	baja.action = "interactuar"
	baja.pressed = true
	Input.parse_input_event(baja)
	for _i in range(3):
		await process_frame
	var sube := InputEventAction.new()
	sube.action = "interactuar"
	sube.pressed = false
	Input.parse_input_event(sube)
	for _i in range(3):
		await process_frame


func _cerrar_pensamiento(habitacion) -> void:
	await create_timer(0.4).timeout
	await _apretar_e()
	await create_timer(0.4).timeout
	await _apretar_e()
	for _i in range(100):
		await process_frame
		if not paused and not habitacion.dialogo.esta_abierto():
			return


func _esperar_pensamiento(habitacion) -> bool:
	for _i in range(200):
		await process_frame
		if paused and habitacion.dialogo.esta_abierto():
			return true
	return false


func _probar() -> void:
	Engine.time_scale = 4.0
	create_timer(150.0).timeout.connect(func(): quit(2))
	var gm = root.get_node("GameManager")
	gm.reiniciar()
	gm.tutoriales_vistos.clear()

	var habitacion = load("res://escenas/01_habitacion/habitacion.tscn").instantiate()
	root.add_child(habitacion)
	current_scene = habitacion
	await process_frame
	var escritorio = habitacion.escritorio
	escritorio._hay_linkedout = false

	# ---- 1. explorar la pieza no hace de noche ----
	await create_timer(6.0).timeout
	_comprobar(escritorio.reloj.text == "08:00", "Explorando la pieza el reloj no avanza")
	habitacion._apagar_despertador()
	await create_timer(4.0).timeout
	_comprobar(escritorio.reloj.text == "08:00", "Caminando por la pieza el reloj sigue quieto")

	# ---- 2. el cartel de la barra frena el inicio de la sesion ----
	_comprobar(gm.tutorial_pendiente("barra_dopamina"), "Partida nueva: el tutorial esta pendiente")
	habitacion._sentarse()        # sin await: se queda esperando la E
	var capa: Control = null
	for _i in range(400):
		await process_frame
		capa = escritorio.get_node_or_null("TutorialBarra")
		if capa != null and capa.modulate.a > 0.9:
			break
	_comprobar(capa != null, "Al arrancar la compu aparece el cartel de la barra")
	if capa == null:
		quit(1)
		return

	_comprobar(not gm.activo, "Con el cartel abierto la sesion todavia no empezo")
	var dopamina_antes: float = gm.dopamina
	await create_timer(2.0).timeout
	_comprobar(is_equal_approx(gm.dopamina, dopamina_antes), "Con el cartel la barra no baja")
	_comprobar(escritorio.reloj.text == "08:00", "Con el cartel el reloj no avanza")
	_comprobar(capa.mouse_filter == Control.MOUSE_FILTER_STOP, "El cartel no deja clickear lo de atras")

	# La flecha apunta a la barra.
	var barra: Control = escritorio.get_node("BarraDopamina")
	var flecha: Polygon2D = null
	for hijo in capa.get_children():
		if hijo is Polygon2D:
			flecha = hijo
	_comprobar(flecha != null, "Hay una flecha")
	if flecha:
		var punta_global: Vector2 = capa.get_global_rect().position + flecha.position
		var r: Rect2 = barra.get_global_rect()
		_comprobar(absf(punta_global.x - r.get_center().x) < 1.0, "La flecha esta centrada bajo la barra")
		_comprobar(punta_global.y > r.end.y, "La flecha esta debajo de la barra, apuntandole")
	_comprobar(barra.z_index > 0, "La barra queda iluminada por encima de la sombra")

	# Todo lo que se escribe se puede dibujar.
	var fuente: Font = ThemeDB.fallback_font
	var sin_glifo := ""
	for n in capa.find_children("*", "Label", true, false):
		for ch in (n as Label).text:
			if ch != " " and not fuente.has_char(ch.unicode_at(0)):
				sin_glifo += ch
	_comprobar(sin_glifo == "", "Los textos del cartel no tienen cuadraditos: '%s'" % sin_glifo)

	await _apretar_e()
	for _i in range(200):
		await process_frame
		if gm.activo:
			break
	_comprobar(not is_instance_valid(capa) or capa.is_queued_for_deletion(), "Con E se va el cartel")
	_comprobar(gm.activo, "Recien despues de la E arranca la sesion")
	_comprobar(barra.z_index == 0, "La barra vuelve a su lugar")
	_comprobar(not gm.tutorial_pendiente("barra_dopamina"), "El cartel queda marcado como visto")

	await create_timer(1.0).timeout
	_comprobar(escritorio.reloj.text != "08:00", "Con la sesion en marcha el reloj ya corre")

	# ---- 3. la primera vez en TikBrainRot ----
	var jugador = habitacion.jugador
	_comprobar(not jugador.puede_mover, "Sentado, el jugador no camina")
	escritorio._abrir_app(0)
	for _i in range(200):
		await process_frame
		if paused:
			break
	_comprobar(paused, "Abrir TikBrainRot la primera vez frena el juego")
	_comprobar(habitacion.dialogo.esta_abierto(), "Y aparece el pensamiento")
	_comprobar(habitacion.dialogo.texto.text.begins_with("Un ratito de tiktoks"), "Es el pensamiento de los tiktoks")

	var dopamina_pausa: float = gm.dopamina
	var hora_pausa: String = escritorio.reloj.text
	await create_timer(2.0).timeout
	_comprobar(is_equal_approx(gm.dopamina, dopamina_pausa), "Con el pensamiento abierto la barra no se mueve")
	_comprobar(escritorio.reloj.text == hora_pausa, "Con el pensamiento abierto el reloj no se mueve")

	# Primera E: termina de escribir. Segunda: cierra.
	await create_timer(0.4).timeout
	await _apretar_e()
	await create_timer(0.4).timeout
	await _apretar_e()
	for _i in range(100):
		await process_frame
		if not paused:
			break
	_comprobar(not paused, "Al cerrar el pensamiento el juego sigue")
	_comprobar(not habitacion.dialogo.esta_abierto(), "El pensamiento se cerro")
	_comprobar(not jugador.puede_mover, "Al cerrar el pensamiento el jugador SIGUE sentado")

	# Una segunda vez en la misma partida: nada.
	var ventana = escritorio._ventanas.get(0)
	if is_instance_valid(ventana):
		ventana.cerrar()
	await create_timer(0.6).timeout
	escritorio._abrir_app(0)
	await create_timer(1.0).timeout
	_comprobar(not paused and not habitacion.dialogo.esta_abierto(), "La segunda vez TikBrainRot no repite el pensamiento")

	# ---- 4. la notificacion de instalacion ----
	var cartel = escritorio.cartel
	gm.dopamina = 20.0
	gm._tiempo_desde_oferta = 999.0
	for _i in range(200):
		await process_frame
		if cartel.visible:
			break
	gm.dopamina = 80.0
	_comprobar(cartel.visible, "Con la barra baja llega la notificacion de una app nueva")
	_comprobar(cartel.sonido.playing, "Suena al aparecer")
	await create_timer(0.8).timeout   # que termine de entrar

	var app_ofrecida: Dictionary = gm.APPS[gm.apps_desbloqueadas]
	_comprobar(cartel.get_node("Titulo").text == app_ofrecida["nombre"], "La notificacion dice el nombre de la app")
	_comprobar(cartel.get_node("Encabezado").text.begins_with("Se terminó de instalar"), "Dice que se termino de instalar")
	var r: Rect2 = cartel.get_global_rect()
	_comprobar(r.end.x <= 1920.0 and r.end.x > 1850.0, "Queda pegada al borde derecho")
	_comprobar(r.end.y <= 1080.0 - 64.0 and r.end.y > 1080.0 - 120.0, "Queda justo arriba de la barra de tareas")
	_comprobar(cartel.z_index > escritorio.tropiezo.z_index, "Se dibuja arriba del tropiezo: una caida no la tapa")
	_comprobar(cartel.sonido.stream != null, "Tiene sonido (el propio o el de respaldo)")

	var fuente_n: Font = ThemeDB.fallback_font
	var sin_glifo_n := ""
	for n in cartel.find_children("*", "Label", true, false):
		for ch in (n as Label).text:
			if ch != " " and not fuente_n.has_char(ch.unicode_at(0)):
				sin_glifo_n += ch
	for ch in (cartel.get_node("BotonAceptar") as Button).text:
		if ch != " " and not fuente_n.has_char(ch.unicode_at(0)):
			sin_glifo_n += ch
	_comprobar(sin_glifo_n == "", "La notificacion no tiene cuadraditos: '%s'" % sin_glifo_n)

	# Suena UNA sola vez, al aparecer. Se corta a mano y se comprueba que
	# no vuelva a sonar aunque nadie la atienda (en tiempo real: el audio
	# no se acelera con time_scale; 3 s reales son 12 s de juego).
	cartel.sonido.stop()
	var volvio_a_sonar := false
	var limite := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < limite:
		await process_frame
		if cartel.sonido.playing:
			volvio_a_sonar = true
			break
	_comprobar(not volvio_a_sonar, "Suena una sola vez: no insiste")
	gm.dopamina = 80.0

	# El boton instala Y abre la app, que piensa lo suyo la primera vez.
	var indice_nueva: int = gm.apps_desbloqueadas
	cartel.get_node("BotonAceptar").pressed.emit()
	_comprobar(gm.esta_desbloqueada(indice_nueva), "Aceptar desbloquea la app")
	_comprobar(escritorio._ventanas.has(indice_nueva), "Y la abre")
	_comprobar(await _esperar_pensamiento(habitacion), "La primera vez que se abre, la app nueva tambien frena el juego")
	var clave_nueva: String = "primera_vez_" + app_ofrecida["id"]
	_comprobar(habitacion.dialogo.texto.text == habitacion._pensamientos.get(clave_nueva, "?"),
		"Y dice su propio pensamiento")
	await _cerrar_pensamiento(habitacion)
	_comprobar(not paused, "Al cerrarlo el juego sigue")
	await create_timer(0.5).timeout
	_comprobar(not cartel.visible, "La notificacion se fue")

	# ---- 5. LinkedOut, la primera vez que aparece sola ----
	gm.dopamina = 80.0
	escritorio._abrir_linkedout()
	_comprobar(await _esperar_pensamiento(habitacion), "La primera vez que salta LinkedOut tambien frena el juego")
	_comprobar(habitacion.dialogo.texto.text.begins_with("Uf"), "Y el personaje piensa que es un virus")
	await _cerrar_pensamiento(habitacion)
	var ventana_lo = escritorio._ventanas.get(escritorio.CLAVE_LINKEDOUT)
	if is_instance_valid(ventana_lo):
		ventana_lo.cerrar()
	await create_timer(0.6).timeout
	escritorio._abrir_linkedout()
	await create_timer(1.0).timeout
	_comprobar(not paused and not habitacion.dialogo.esta_abierto(), "La segunda vez LinkedOut no repite el pensamiento")
	ventana_lo = escritorio._ventanas.get(escritorio.CLAVE_LINKEDOUT)
	if is_instance_valid(ventana_lo):
		ventana_lo.cerrar()
	gm.dopamina = 80.0

	# ---- 6. una sola vez por partida ----
	gm.reiniciar()     # lo que hace el dia nuevo
	_comprobar(not gm.tutorial_pendiente("barra_dopamina") and not gm.tutorial_pendiente("primera_vez_scroll"),
		"Un dia nuevo no repite los tutoriales")

	var menu = load("res://escenas/00_menu/menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	_comprobar(gm.tutorial_pendiente("barra_dopamina") and gm.tutorial_pendiente("primera_vez_scroll"),
		"Una partida nueva desde el menu los vuelve a mostrar")
	menu.queue_free()

	paused = false
	await create_timer(0.5).timeout
	print("[Tutorial TEST] completado; fallos=", _fallos)
	quit(_fallos)
