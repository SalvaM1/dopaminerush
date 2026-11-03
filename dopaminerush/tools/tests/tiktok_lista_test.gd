extends SceneTree

# Godot --headless --path . --script res://tools/tests/tiktok_lista_test.gd
#
# Prueba el orden de los videos de TikBrainRot:
#   - el primero del juego es clip_03, clip_06 o clip_08 (cual, al azar)
#   - no se repite ninguno hasta haber visto todos
#   - al terminar la lista se mezcla de nuevo, toda al azar, y la vuelta
#     nueva no arranca con el mismo con el que termino la anterior
#   - cerrar y reabrir la app sigue la misma lista
#   - cada juego nuevo arranca con otro orden
const ESCENA := "res://escenas/03_apps/app_01_scroll/app_scroll.tscn"
const SCRIPT := "res://escenas/03_apps/app_01_scroll/app_scroll.gd"
const PRIMEROS := ["clip_03.ogv", "clip_06.ogv", "clip_08.ogv"]

var _fallos: int = 0


func _initialize() -> void:
	call_deferred("_probar")


func _comprobar(condicion: bool, mensaje: String) -> void:
	if not condicion:
		_fallos += 1
		push_error("[TikTokLista TEST] " + mensaje)


func _nombre(ruta: String) -> String:
	return ruta.get_file()


func _abrir() -> Node:
	var app = load(ESCENA).instantiate()
	root.add_child(app)
	return app


func _probar() -> void:
	create_timer(60.0).timeout.connect(func(): quit(2))
	var guion = load(SCRIPT)
	guion.reiniciar_lista()

	# ---- el primero ----
	var app := _abrir()
	await process_frame
	var total: int = app._videos.size()
	_comprobar(total >= 3, "Hay videos (%d)" % total)
	var vistos: Array[String] = [app._ultimo_video]
	_comprobar(_nombre(vistos[0]) in PRIMEROS, "El primero es uno de los elegidos (%s)" % _nombre(vistos[0]))

	# ---- la primera vuelta: todos, sin repetir ----
	# A mitad de camino se cierra la app y se vuelve a abrir.
	for i in range(1, total):
		if i == total / 2:
			app.queue_free()
			await process_frame
			app = _abrir()
			await process_frame
			vistos.append(app._ultimo_video)
		else:
			app._cargar_video()
			vistos.append(app._ultimo_video)
	var unicos := {}
	for v in vistos:
		unicos[v] = true
	_comprobar(unicos.size() == total, "La primera vuelta pasa por los %d sin repetir (%d distintos)" % [total, unicos.size()])
	_comprobar(not (_nombre(app._ultimo_video) in PRIMEROS and vistos.count(app._ultimo_video) > 1),
		"Reabrir la app no vuelve a sacar uno de los primeros")

	# ---- la segunda vuelta: otra mezcla, sin costura repetida ----
	var segunda: Array[String] = []
	for i in total:
		app._cargar_video()
		segunda.append(app._ultimo_video)
	unicos.clear()
	for v in segunda:
		unicos[v] = true
	_comprobar(unicos.size() == total, "La segunda vuelta tambien pasa por todos (%d)" % unicos.size())
	_comprobar(segunda[0] != vistos[-1], "La vuelta nueva no arranca con el ultimo de la anterior")
	_comprobar(segunda != vistos, "La segunda vuelta tiene otro orden")
	app.queue_free()
	await process_frame

	# ---- muchos juegos nuevos ----
	# Siempre arranca con uno de los tres, los tres salen alguna vez, y el
	# orden de cada juego es distinto.
	app = _abrir()
	await process_frame
	var primeros := {}
	var ordenes := {}
	for juego in 30:
		guion.reiniciar_lista()
		var orden: Array[String] = []
		for i in 6:
			orden.append(_nombre(app._siguiente_video()))
		primeros[orden[0]] = true
		ordenes[",".join(orden)] = true
		_comprobar(orden[0] in PRIMEROS, "Cada juego arranca con uno de los elegidos (%s)" % orden[0])
	_comprobar(primeros.size() == 3, "Los tres elegidos salen primeros alguna vez (%s)" % str(primeros.keys()))
	_comprobar(ordenes.size() >= 28, "Cada juego tiene su propio orden (%d de 30 distintos)" % ordenes.size())
	app.queue_free()
	guion.reiniciar_lista()

	print("[TikTokLista TEST] completado; fallos=", _fallos)
	quit(_fallos)
