extends SceneTree

# Godot --headless --path . --script res://tools/tests/loopify_test.gd
#
# Prueba Loopify:
#   - al abrirla suena un tema y las OTRAS apps rinden x1.3
#   - a los 10 segundos el tema aburre: baja el volumen y se va el x1.3
#   - vienen 5 temas reales, cada uno con su tapa y su artista
#   - "Siguiente" pone otro tema (nunca el mismo) y vuelve el x1.3
#   - la TV, el vape y la propia Loopify no se multiplican
#   - mientras suena, las apps y el ambiente bajan (la UI no): la musica
#     se escucha si o si. Aburrido suena apagado, no mas bajo
#   - al cerrarla se calla, se apaga el multiplicador y todo vuelve a su
#     volumen
#   - sin temas en la carpeta no se rompe nada
#   - el escritorio la abre en el lugar de la sexta app
var _fallos: int = 0


func _initialize() -> void:
	call_deferred("_probar")


func _comprobar(condicion: bool, mensaje: String) -> void:
	if not condicion:
		_fallos += 1
		push_error("[Loopify TEST] " + mensaje)


func _probar() -> void:
	Engine.time_scale = 4.0
	create_timer(120.0).timeout.connect(func(): quit(2))
	var gm = root.get_node("GameManager")
	gm.reiniciar()
	gm.activo = true
	gm.set_process(false)   # sin drenaje: se miden los premios exactos

	var escena: PackedScene = load("res://escenas/03_apps/app_06_musica/app_musica.tscn")
	var app = escena.instantiate()
	var marco := Control.new()
	marco.size = Vector2(560, 282)
	root.add_child(marco)
	marco.add_child(app)
	await process_frame

	_comprobar(app._temas.size() == 5, "Encuentra los 5 temas (%d)" % app._temas.size())
	var esperados := {
		"Charly García": "Promesas sobre el bidet",
		"Patricio Rey y sus Redonditos de Ricota": "Esa estrella era mi lujo",
		"The Beatles": "Don't Let Me Down",
		"Nirvana": "Smells Like Teen Spirit",
		"Luis Fonsi ft. Daddy Yankee": "Despacito",
	}
	for ruta in app._temas:
		var partes: Array = app._partes(ruta)
		_comprobar(esperados.get(partes[0], "") == partes[1], "Artista y tema bien leidos: %s" % str(partes))
		_comprobar(app._tapa_de(ruta) != null, "Tiene su tapa: %s" % partes[1])
		var stream: AudioStream = load(ruta)
		_comprobar(stream.get_length() > 25.0 and stream.get_length() < 35.0, "Es un recorte de ~30 s: %s" % partes[1])
	_comprobar(app._partes("res://x/Queen - Bohemian Rhapsody.mp3") == ["Queen", "Bohemian Rhapsody"],
		"Saca artista y tema del nombre del archivo")
	_comprobar(app._partes("res://x/zumbido.ogg") == ["", "zumbido"], "Sin guion, todo es el tema")

	# ---- abrirla ----
	app.iniciar()
	await process_frame
	_comprobar(app._reproductor.playing, "Al abrirla suena un tema")
	_comprobar(app._reproductor.bus == "Loopify", "Suena por su propio bus")
	var i_loopify := AudioServer.get_bus_index("Loopify")
	_comprobar(i_loopify >= 0 and AudioServer.get_bus_send(i_loopify) == &"Musica", "El bus Loopify existe y va a Musica")

	# El resto se agacha. Se miden los buses contra su volumen original.
	var originales := {}
	for bus in ["Apps", "Ambiente", "UI"]:
		originales[bus] = root.get_node("AudioManager")._volumen_original.get(bus,
			AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus)))
	await create_timer(0.8).timeout
	var vol := func(bus: String) -> float: return AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus))
	_comprobar(absf(vol.call("Apps") - (originales["Apps"] - 10.0)) < 0.5, "Las apps bajan 10 dB (%.1f)" % vol.call("Apps"))
	_comprobar(absf(vol.call("Ambiente") - (originales["Ambiente"] - 10.0)) < 0.5, "El ambiente baja 10 dB")
	_comprobar(absf(vol.call("UI") - originales["UI"]) < 0.1, "La interfaz no baja: las notificaciones se escuchan")
	_comprobar(is_equal_approx(gm.mult_dopamina_musica, 1.3), "Con el tema fresco, las otras apps rinden x1.3")
	var primero: int = app._actual

	gm.dopamina = 20.0
	gm.sumar_dopamina(10.0, "slots")
	_comprobar(is_equal_approx(gm.dopamina, 33.0), "Una app del catalogo da 13 en vez de 10 (%.1f)" % (gm.dopamina - 20.0))
	gm.dopamina = 20.0
	gm.sumar_dopamina(10.0, "netflox")
	_comprobar(is_equal_approx(gm.dopamina, 30.0), "La TV no se multiplica")
	gm.dopamina = 20.0
	gm.sumar_dopamina(10.0, "linkedin")
	_comprobar(is_equal_approx(gm.dopamina, 30.0), "LinkedOut no se multiplica")

	_comprobar(app._tapa.visible and not app._iniciales.visible, "Se ve la tapa del disco, no las iniciales")
	_comprobar(app._reproductor.get_playback_position() < 2.0, "Un recorte arranca desde el principio (el estribillo)")

	# ---- se aburre ----
	_comprobar(is_equal_approx(app.duracion_fresca, 10.0), "Cada tema dura 10 s fresco")
	await create_timer(app.duracion_fresca - 2.0).timeout
	_comprobar(not app._aburrido and is_equal_approx(gm.mult_dopamina_musica, 1.3), "A los 8 s todavia no aburre")
	await create_timer(3.5).timeout
	_comprobar(app._aburrido, "A los 10 s el tema ya aburre")
	_comprobar(is_equal_approx(gm.mult_dopamina_musica, 1.0), "Aburrido, se va el x1.3")
	await create_timer(1.2).timeout
	_comprobar(app._filtro().cutoff_hz < 2000.0, "Aburrido, suena apagado: solo pasan los graves (%.0f Hz)" % app._filtro().cutoff_hz)
	_comprobar(app._reproductor.volume_db >= app.volumen_temas - 4.0, "Pero casi no baja de volumen: se sigue escuchando (%.1f dB)" % app._reproductor.volume_db)
	_comprobar(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Apps")) < originales["Apps"] - 5.0, "Aburrido, el resto sigue agachado")
	_comprobar(app._reproductor.playing, "Pero sigue sonando: no se corta")

	# ---- siguiente ----
	app._boton.pressed.emit()
	await process_frame
	_comprobar(app._actual != primero, "Siguiente pone OTRO tema")
	_comprobar(not app._aburrido and is_equal_approx(gm.mult_dopamina_musica, 1.3), "Y vuelve el x1.3")
	await create_timer(1.0).timeout
	_comprobar(app._reproductor.volume_db > app.volumen_temas - 2.0, "Y vuelve a escucharse fuerte")
	_comprobar(app._filtro().cutoff_hz > 20000.0, "Y sin el filtro: vuelve a sonar claro")

	# Lo que se ve, se puede dibujar.
	var fuente: Font = ThemeDB.fallback_font
	var sin_glifo := ""
	for n in app.find_children("*", "Label", true, false):
		for ch in (n as Label).text:
			if ch != " " and not fuente.has_char(ch.unicode_at(0)):
				sin_glifo += ch
	_comprobar(sin_glifo == "", "La interfaz no tiene cuadraditos: '%s'" % sin_glifo)

	# ---- cerrarla ----
	app.detener()
	await process_frame
	_comprobar(not app._reproductor.playing, "Al cerrarla se calla")
	await create_timer(0.8).timeout
	_comprobar(absf(vol.call("Apps") - originales["Apps"]) < 0.1 and absf(vol.call("Ambiente") - originales["Ambiente"]) < 0.1,
		"Al cerrarla, las apps y el ambiente vuelven a su volumen")
	_comprobar(app._filtro().cutoff_hz > 20000.0, "Y el filtro queda abierto")
	_comprobar(is_equal_approx(gm.mult_dopamina_musica, 1.0), "Y se apaga el multiplicador")
	marco.queue_free()
	await process_frame

	# ---- sin temas ----
	var vacia = escena.instantiate()
	vacia.carpeta_temas = "res://no_existe"
	root.add_child(vacia)
	await process_frame
	vacia.iniciar()
	await process_frame
	_comprobar(vacia._temas.is_empty() and vacia._boton.disabled, "Sin temas avisa y no deja apretar")
	_comprobar(is_equal_approx(gm.mult_dopamina_musica, 1.0), "Sin temas no hay multiplicador")
	vacia.detener()
	vacia.queue_free()

	# ---- el escritorio la abre como sexta app ----
	var esc = load("res://escenas/02_computadora/escritorio.tscn").instantiate()
	var contenedor := Node.new()
	root.add_child(contenedor)
	contenedor.add_child(esc)
	await process_frame
	gm.apps_desbloqueadas = gm.APPS.size()
	esc._abrir_app(5)
	await process_frame
	var ventana = esc._ventanas.get(5)
	_comprobar(is_instance_valid(ventana) and ventana.app.id_app == "musica", "El escritorio abre Loopify como sexta app")
	if is_instance_valid(ventana):
		_comprobar(ventana.size == Vector2(560, 320), "Con su tamano de mini-reproductor")
		ventana.cerrar()
	await create_timer(0.5).timeout
	_comprobar(is_equal_approx(gm.mult_dopamina_musica, 1.0), "Cerrar la ventana apaga el multiplicador")

	print("[Loopify TEST] completado; fallos=", _fallos)
	quit(_fallos)
