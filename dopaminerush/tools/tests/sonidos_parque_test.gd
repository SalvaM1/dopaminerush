extends SceneTree

# Godot --headless --path . --script res://tools/tests/sonidos_parque_test.gd
#
# Prueba los sonidos del parque y la pitada del vape:
#   - pajaros, viento y agua cargan, suenan y quedan en loop
#   - el viento va muy por debajo de los pajaros
#   - el agua se para en la orilla mas cercana al jugador: al lado del lago
#     se escucha, lejos (donde arranca el parque) no
#   - el vape tiene su pitada, y la pieza tiene los pajaros del martes
var _fallos: int = 0


func _initialize() -> void:
	call_deferred("_probar")


func _comprobar(condicion: bool, mensaje: String) -> void:
	if not condicion:
		_fallos += 1
		push_error("[SonidosParque TEST] " + mensaje)


# Cuanto llega el agua al jugador, en dB, con el modelo del nodo
# (inversa al cuadrado), como lo calcula Godot.
func _nivel_agua(agua: AudioStreamPlayer3D, oyente: Vector3) -> float:
	var d := maxf(agua.global_position.distance_to(oyente), 0.01)
	if d > agua.max_distance:
		return -80.0
	var atenuacion := 20.0 * log(pow(agua.unit_size / d, 2.0)) / log(10.0)
	return agua.volume_db + minf(atenuacion, agua.max_db)


func _probar() -> void:
	create_timer(60.0).timeout.connect(func(): quit(2))
	# Sin pantalla los frames corren lo mas rapido posible: el agua se
	# desliza hacia la orilla con el tiempo real, no por frame.
	Engine.max_fps = 60
	var parque = load("res://escenas/04_parque/parque.tscn").instantiate()
	root.add_child(parque)
	for i in 10:
		await process_frame

	var pajaros: AudioStreamPlayer = parque.get_node("Sonidos/Pajaros")
	var viento: AudioStreamPlayer = parque.get_node("Sonidos/Viento")
	var agua: AudioStreamPlayer3D = parque.get_node("Sonidos/Agua")
	for r in [pajaros, viento, agua]:
		_comprobar(r.stream != null, "%s tiene su sonido" % r.name)
		_comprobar(r.playing, "%s suena" % r.name)
		_comprobar(r.stream != null and r.stream.get("loop") == true, "%s esta en loop" % r.name)
		_comprobar(r.bus == &"Ambiente", "%s va por Ambiente" % r.name)
	_comprobar(pajaros.get_class() == "AudioStreamPlayer", "Los pajaros suenan en todo el parque (sin posicion)")
	# Los ambientes entran con un fundido de 3,5 s: se mide al final
	await create_timer(4.0).timeout
	_comprobar(viento.volume_db <= pajaros.volume_db - 12.0,
		"El viento va muy de fondo (%.0f contra %.0f)" % [viento.volume_db, pajaros.volume_db])

	# Donde arranca el parque, lejos del lago: no se escucha el agua
	var jugador: Node3D = parque.jugador
	var lejos := _nivel_agua(agua, jugador.global_position)
	_comprobar(lejos < -45.0, "Al llegar al parque el agua no se escucha (%.0f dB)" % lejos)

	# Al lado del lago: el sonido se va a la orilla de enfrente del jugador
	var orilla: Vector2 = parque._orilla[5]
	var siguiente: Vector2 = parque._orilla[6]
	var punto := (orilla + siguiente) * 0.5
	var centro := Vector2.ZERO
	for p in parque._orilla:
		centro += p
	centro /= parque._orilla.size()
	var afuera := (punto - centro).normalized()
	var cerca := punto + afuera * 2.5
	jugador.set_physics_process(false)
	jugador.global_position = Vector3(cerca.x, jugador.global_position.y, cerca.y)
	for i in 180:
		await process_frame
	var a_la_orilla := Vector2(agua.global_position.x, agua.global_position.z).distance_to(cerca)
	_comprobar(a_la_orilla < 4.0, "El agua suena desde la orilla de al lado (a %.1f m)" % a_la_orilla)
	var al_lado := _nivel_agua(agua, jugador.global_position)
	_comprobar(al_lado > -20.0, "Al lado del lago se escucha (%.0f dB)" % al_lado)

	# Un poco mas lejos baja rapido
	var alejado := punto + afuera * 16.0
	jugador.global_position = Vector3(alejado.x, jugador.global_position.y, alejado.y)
	for i in 180:
		await process_frame
	var a_16 := _nivel_agua(agua, jugador.global_position)
	_comprobar(a_16 < al_lado - 15.0, "A 16 m de la orilla ya casi no (%.0f dB)" % a_16)
	parque.queue_free()
	await process_frame

	# ---- la pieza ----
	var h = load("res://escenas/01_habitacion/habitacion.tscn").instantiate()
	root.add_child(h)
	await process_frame
	_comprobar(h.sonido_vape != null and h.sonido_vape.stream != null, "El vape tiene su pitada")
	_comprobar(h.sonido_vape != null and h.sonido_vape.stream.get_length() < 2.5,
		"La pitada es corta: no sigue con el vape ya en la mesa")
	_comprobar(h._pajaros != null and h._pajaros.stream != null, "La mañana del martes tiene pajaros")
	h.queue_free()

	print("[SonidosParque TEST] completado; fallos=", _fallos)
	quit(_fallos)
