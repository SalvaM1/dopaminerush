extends SceneTree

# Godot --headless --path . --script res://tools/tests/tiktok_x2_test.gd
#
# Prueba que el 2x de TikTok se note, adentro de la app y sin dialogos:
#   - antes del umbral no hay nada
#   - al desbloquearse sale el cartel grande, y despues la pista latiendo
#   - cerrar y reabrir la app no lo vuelve a anunciar (pero la pista sigue
#     si todavia no se uso)
#   - usarlo un ratito hace desaparecer la pista, para siempre en la partida
#   - mientras se usa: la pastilla "2x" y la barra rosa
const ESCENA := "res://escenas/03_apps/app_01_scroll/app_scroll.tscn"

var _fallos: int = 0


func _initialize() -> void:
	call_deferred("_probar")


func _comprobar(condicion: bool, mensaje: String) -> void:
	if not condicion:
		_fallos += 1
		push_error("[TikTokX2 TEST] " + mensaje)


func _abrir() -> Node:
	var app = load(ESCENA).instantiate()
	root.add_child(app)
	return app


func _probar() -> void:
	create_timer(60.0).timeout.connect(func(): quit(2))
	Engine.max_fps = 60
	var gm = root.get_node("GameManager")
	gm.reiniciar()
	gm.tutoriales_vistos.clear()

	var app := _abrir()
	await create_timer(0.3).timeout
	_comprobar(not app._x2_desbloqueado and not app._banner_x2.visible and not app._pista_x2.visible,
		"Antes del umbral, nada del 2x")
	app._al_cambiar_dopamina(80.0, 100.0)
	_comprobar(not app._x2_desbloqueado, "Con dopamina alta todavia no")

	app._al_cambiar_dopamina(55.0, 100.0)
	await create_timer(0.5).timeout
	_comprobar(app._x2_desbloqueado, "Bajo el umbral se desbloquea")
	_comprobar(app._banner_x2.visible, "Sale el cartel grande")
	await create_timer(3.6).timeout
	_comprobar(not app._banner_x2.visible, "El cartel se va solo")
	_comprobar(app._pista_x2.visible, "Y queda la pista latiendo")

	# Cerrar y reabrir: no se anuncia otra vez, pero la pista sigue
	app.queue_free()
	await process_frame
	app = _abrir()
	await create_timer(0.5).timeout
	_comprobar(app._x2_desbloqueado, "Reabierta la app, el 2x sigue desbloqueado")
	app._al_cambiar_dopamina(40.0, 100.0)
	await create_timer(0.3).timeout
	_comprobar(not app._banner_x2.visible, "Y no se vuelve a anunciar")
	_comprobar(app._pista_x2.visible, "La pista sigue hasta que se usa")

	# Usarlo
	app._manteniendo = true
	app._actualizar_velocidad()
	await create_timer(0.2).timeout
	_comprobar(app.etiqueta_velocidad.visible, "Mientras se usa, la pastilla 2x")
	_comprobar(app.barra.get_theme_stylebox("fill") == app._relleno_rapido, "Y la barra rosa")
	await create_timer(1.0).timeout
	app._manteniendo = false
	app._actualizar_velocidad()
	await create_timer(0.5).timeout
	_comprobar(not app._pista_x2.visible, "Usarlo un ratito hace desaparecer la pista")
	_comprobar(not app.etiqueta_velocidad.visible, "Al soltar, se va la pastilla")
	_comprobar(app.barra.get_theme_stylebox("fill") == app._relleno_normal, "Y la barra vuelve a su color")

	app.queue_free()
	await process_frame
	app = _abrir()
	await create_timer(0.5).timeout
	_comprobar(not app._pista_x2.visible, "Ya usado, la pista no vuelve")
	app.queue_free()

	# Partida nueva (el menu limpia los tutoriales): se puede anunciar otra vez
	gm.tutoriales_vistos.clear()
	app = _abrir()
	await create_timer(0.3).timeout
	_comprobar(not app._x2_desbloqueado, "En una partida nueva, el 2x arranca bloqueado")
	app.queue_free()

	print("[TikTokX2 TEST] completado; fallos=", _fallos)
	quit(_fallos)
