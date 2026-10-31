extends SceneTree

# Godot --headless --path . --script res://tools/tests/pasos_test.gd
#
# Prueba los pasos del jugador. Hay dos formas de sonar:
#   - PIEZA: un paso suelto por cada tranco, al ritmo de lo que se camina
#   - PARQUE: una grabacion de alguien caminando en ripio, en loop, que
#     suena mientras se camina, se pausa al parar y sigue desde donde quedo
# Se prueba todo en el parque porque es abierto: en la pieza se choca
# enseguida contra una pared.
var _fallos: int = 0
var _caminando: bool = false


func _initialize() -> void:
	call_deferred("_probar")


func _comprobar(condicion: bool, mensaje: String) -> void:
	if not condicion:
		_fallos += 1
		push_error("[Pasos TEST] " + mensaje)


func _caminar(segundos: float) -> void:
	Input.action_press("mover_adelante")
	await create_timer(segundos).timeout
	Input.action_release("mover_adelante")


func _probar() -> void:
	Engine.time_scale = 4.0
	create_timer(150.0).timeout.connect(func(): quit(2))
	var gm = root.get_node("GameManager")
	gm.reiniciar()
	gm.activo = false

	# ---- la pieza: un paso suelto ----
	var jugador_pieza = load("res://escenas/01_habitacion/jugador.tscn").instantiate()
	root.add_child(jugador_pieza)
	await process_frame
	_comprobar(jugador_pieza.carpeta_pasos == "res://assets/audio/pasos/pieza", "En la pieza se usan los pasos de adentro")
	_comprobar(jugador_pieza._pasos.size() == 1, "La pieza tiene su paso suelto (%d)" % jugador_pieza._pasos.size())
	_comprobar(jugador_pieza._caminata == null, "En la pieza no hay caminata continua")
	jugador_pieza.queue_free()
	await process_frame

	# ---- el parque: la caminata de ripio ----
	var parque = load("res://escenas/04_parque/parque.tscn").instantiate()
	root.add_child(parque)
	current_scene = parque
	var jugador = parque.jugador
	var caminata: AudioStreamPlayer = jugador._reproductor_caminata
	_comprobar(jugador._caminata != null, "En el parque esta la caminata de ripio")
	_comprobar(jugador._caminata != null and jugador._caminata.loop, "Y esta en loop")
	_comprobar(jugador._pasos.is_empty(), "En el parque no hay pasos sueltos")
	await create_timer(3.0).timeout
	_comprobar(jugador.is_on_floor() and jugador.puede_mover, "El jugador esta parado y puede caminar")
	_comprobar(not caminata.playing or caminata.stream_paused, "Quieto, el ripio no suena")

	var pasos_antes: int = jugador.pasos_dados
	Input.action_press("mover_adelante")
	await create_timer(1.0).timeout
	_comprobar(caminata.playing and not caminata.stream_paused, "Caminando suena el ripio")
	_comprobar(caminata.volume_db > -40.0, "Y se escucha (%.1f dB)" % caminata.volume_db)
	await create_timer(1.0).timeout
	Input.action_release("mover_adelante")
	_comprobar(jugador.pasos_dados == pasos_antes, "En el parque no suenan pasos sueltos encima")

	await create_timer(0.8).timeout
	_comprobar(caminata.stream_paused, "Al parar, el ripio se pausa")
	var posicion_pausa: float = caminata.get_playback_position()

	await _caminar(0.6)
	_comprobar(caminata.get_playback_position() >= posicion_pausa, "Al volver a caminar sigue desde donde quedo")
	await create_timer(0.8).timeout

	# Sin poder moverse (en un dialogo, por ejemplo): nada.
	jugador.puede_mover = false
	await _caminar(1.0)
	_comprobar(caminata.stream_paused or not caminata.playing, "Sin poder moverse el ripio no suena")
	jugador.puede_mover = true

	# Sentarse en el banco apaga la fisica del jugador CAMINANDO. Si el
	# loop dependiera de la fisica, quedaria sonando para siempre.
	Input.action_press("mover_adelante")
	await create_timer(0.6).timeout
	jugador.set_physics_process(false)
	await create_timer(0.8).timeout
	Input.action_release("mover_adelante")
	_comprobar(caminata.stream_paused or not caminata.playing, "Con la fisica apagada (el banco) el ripio se calla")
	jugador.set_physics_process(true)
	await create_timer(0.5).timeout

	# ---- pasos sueltos: ritmo y variantes ----
	# Se apaga la caminata y se usa una carpeta con varios sonidos (los de
	# la interfaz) para probar las variantes.
	jugador.caminata_continua = ""
	jugador.carpeta_pasos = "res://assets/audio/ui"
	_comprobar(jugador._caminata == null and jugador._pasos.size() >= 3, "Sin caminata vuelven los pasos sueltos")

	var antes: int = jugador.pasos_dados
	var variantes := []
	Input.action_press("mover_adelante")
	_caminando = true
	create_timer(3.0).timeout.connect(func(): _caminando = false)
	while _caminando:
		await physics_frame
		if jugador.pasos_dados > antes + variantes.size():
			variantes.append(jugador._ultimo_paso)
	Input.action_release("mover_adelante")
	var dados: int = jugador.pasos_dados - antes
	var esperados: float = 3.0 * jugador.velocidad / jugador._tranco()
	print("[Pasos TEST] en 3 s caminando: %d pasos (esperados ~%.1f, un tranco cada %.2f m)" % [
		dados, esperados, jugador._tranco()])
	_comprobar(dados >= int(esperados) - 2 and dados <= int(esperados) + 2, "Caminando suenan pasos al ritmo esperado")

	var repetida := false
	for i in range(1, variantes.size()):
		if variantes[i] == variantes[i - 1]:
			repetida = true
	_comprobar(not repetida, "Nunca la misma variante dos veces seguidas: %s" % str(variantes))

	await create_timer(0.5).timeout
	antes = jugador.pasos_dados
	await create_timer(1.5).timeout
	_comprobar(jugador.pasos_dados == antes, "Quieto no suenan pasos")

	jugador.puede_mover = false
	await _caminar(1.5)
	_comprobar(jugador.pasos_dados == antes, "Sin poder moverse no suenan pasos")
	jugador.puede_mover = true

	await create_timer(0.5).timeout
	print("[Pasos TEST] completado; fallos=", _fallos)
	quit(_fallos)
