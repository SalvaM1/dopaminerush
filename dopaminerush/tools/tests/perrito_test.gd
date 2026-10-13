extends SceneTree

# Godot --headless --path . --script res://tools/tests/perrito_test.gd
var _fallos: int = 0


func _initialize() -> void:
	call_deferred("_probar")


func _comprobar(condicion: bool, mensaje: String) -> void:
	if not condicion:
		_fallos += 1
		push_error("[Perrito TEST] " + mensaje)


func _probar() -> void:
	Engine.time_scale = 4.0
	create_timer(150.0).timeout.connect(func(): quit(2))
	var gm = root.get_node("GameManager")
	gm.reiniciar()
	gm.activo = false
	var parque = load("res://escenas/04_parque/parque.tscn").instantiate()
	root.add_child(parque)
	current_scene = parque
	var jugador = parque.jugador
	var perro = parque.perrito
	var posicion_inicial: Vector3 = perro.global_position
	_comprobar(jugador.to_local(posicion_inicial).x > 0.0, "Aparece al costado al entrar al parque")
	await create_timer(3.0).timeout
	_comprobar(perro.is_on_floor(), "Se apoya sobre el terreno")
	_comprobar(jugador.puede_mover and perro.interaccion.activo, "Caminar y acariciar son opcionales")
	# Acercarse lo pone al alcance de la interaccion de tres metros.
	jugador.global_position -= jugador.global_basis.z.normalized() * 0.7
	await create_timer(1.2).timeout
	# Apuntar al perro usa el mismo rayo y E del resto del mundo.
	jugador.camara.look_at(perro.cabeza.global_position)
	jugador.rayo.force_raycast_update()
	_comprobar(jugador.rayo.get_collider() == perro.interaccion, "El rayo detecta al perro")
	var camara_base: Transform3D = jugador.camara.transform
	var fov_base: float = jugador.camara.fov
	var recuperacion_base: float = parque._dopamina
	Input.action_press("interactuar")
	jugador._revisar_interaccion()
	Input.action_release("interactuar")
	_comprobar(perro._acariciando and perro.mano.visible, "E inicia una caricia visible")
	perro.acariciar()
	_comprobar(not jugador.puede_mover and not jugador.puede_interactuar, "Evita superponer gestos durante la caricia")
	await create_timer(2.3).timeout
	_comprobar(not perro._acariciando and not perro.mano.visible, "La caricia termina sola")
	_comprobar(jugador.puede_mover and jugador.puede_mirar and jugador.puede_interactuar, "Recupera todos los controles")
	_comprobar(jugador.camara.transform.is_equal_approx(camara_base) and is_equal_approx(jugador.camara.fov, fov_base), "Recupera mirada y encuadre")
	_comprobar(parque._dopamina - recuperacion_base < 2.0, "La caricia no otorga premios; solo continua la recuperacion pasiva")

	# Recorrer las curvas reales del camino, sin simular una ruta recta.
	jugador.set_physics_process(false)
	var distancia_maxima: float = 0.0
	for tramo in parque.get_node("Camino").get_children():
		var destino: Vector3 = tramo.global_position + Vector3(0.0, 0.1, 0.0)
		while jugador.global_position.distance_to(destino) > 0.08:
			await physics_frame
			jugador.global_position = jugador.global_position.move_toward(destino, 2.4 * jugador.get_physics_process_delta_time())
			distancia_maxima = maxf(distancia_maxima, perro._plano(perro.global_position - jugador.global_position).length())
	await create_timer(3.0).timeout
	_comprobar(distancia_maxima < 6.0, "Acompana todas las curvas sin quedarse atras: %.2f m" % distancia_maxima)
	_comprobar(perro.global_position.distance_to(posicion_inicial) > 60.0, "Llega al final del paseo")
	_comprobar(perro._huellas.size() < 10, "No acumula huellas pendientes al parar")
	_comprobar(perro.is_on_floor(), "Conserva contacto con el piso al final")
	_comprobar(perro._plano(perro.global_position - jugador.global_position).length() >= perro.distancia_seguimiento - 0.1, "Al parar conserva espacio con el jugador")

	# Sentarse durante una caricia tambien libera la camara antes del banco.
	perro.acariciar()
	_comprobar(perro._acariciando, "Se puede repetir una caricia")
	parque._sentarse()
	_comprobar(perro._descansando and not perro._acariciando and not perro.interaccion.activo, "El banco cancela la caricia y pasa al descanso")
	_comprobar(not jugador.puede_mover and not jugador.puede_interactuar, "El perro no reactiva controles del banco")
	await create_timer(11.0).timeout
	_comprobar(parque._puede_respirar, "La secuencia final conserva el gesto de respirar")
	_comprobar(perro._plano(perro.global_position - perro._punto_descanso).length() < 0.35, "Espera junto al banco")
	_comprobar(Vector2(perro.velocity.x, perro.velocity.z).length() < 0.1, "Al descansar deja de caminar")
	_comprobar(is_equal_approx(jugador.camara.fov, fov_base), "El banco conserva el FOV original")
	perro.acariciar()
	_comprobar(not perro._acariciando, "No interfiere con la respiracion final")
	var perro_debil: WeakRef = weakref(perro)
	parque._respirar()
	await create_timer(24.5).timeout
	_comprobar(current_scene.scene_file_path == "res://escenas/05_creditos/creditos.tscn", "Respirar conserva la transicion a creditos")
	_comprobar(perro_debil.get_ref() == null, "El cambio de escena libera al companero")
	print("[Perrito TEST] completado; fallos=", _fallos, "; distancia maxima=", distancia_maxima)
	current_scene.queue_free()
	await process_frame
	await process_frame
	quit(0 if _fallos == 0 else 1)
