extends SceneTree

# Ejecutar desde la carpeta del proyecto:
# Godot --headless --path . --script res://tools/tests/netflox_test.gd
# No agrega assets: para probar la reproduccion usa recursos ya existentes.
var _fallos: int = 0


func _initialize() -> void:
	call_deferred("_probar")


func _comprobar(condicion: bool, mensaje: String) -> void:
	if not condicion:
		_fallos += 1
		push_error("[Netflox TEST] " + mensaje)


func _pulsar_t(tv: Node3D) -> void:
	Input.action_press("mirar_television")
	tv._process(0.0)
	Input.action_release("mirar_television")


func _probar() -> void:
	Engine.time_scale = 8.0
	create_timer(120.0).timeout.connect(func(): quit(2))
	var gm = root.get_node("GameManager")
	gm.reiniciar()
	# Medir recompensas exactamente, sin interferencia del drenaje real.
	gm.set_process(false)
	var escena = load("res://escenas/01_habitacion/habitacion.tscn")
	var habitacion = escena.instantiate()
	root.add_child(habitacion)
	current_scene = habitacion
	await process_frame
	var tv = habitacion.netflox
	_comprobar(tv.apps_para_desbloquear == 5, "La TV llega con la quinta app")
	_comprobar(is_equal_approx(tv.demora_aviso, 15.0), "El cartel tarda 15 s en salir")
	# Para el resto del test no interesa esperar los 15 s reales.
	tv.demora_aviso = 0.4

	gm.apps_desbloqueadas = 3
	gm.app_desbloqueada.emit(2)
	tv.encender()
	_comprobar(habitacion._vape_desbloqueado, "El vape sigue habilitado con la tercera app")
	_comprobar(not tv._desbloqueada and not tv._encendida, "Netflox no se habilita con el vape")

	gm.apps_desbloqueadas = 4
	gm.app_desbloqueada.emit(3)
	tv.encender()
	_comprobar(not tv._desbloqueada, "La cuarta app todavia NO habilita la TV")

	# Las apps se desbloquean con el jugador en la PC, asi que la sesion
	# esta activa cuando llega el cartel.
	gm.activo = true
	gm.apps_desbloqueadas = 5
	gm.app_desbloqueada.emit(4)
	_comprobar(not tv._desbloqueada, "La quinta tampoco la habilita en el acto: espera el cartel")
	await create_timer(1.0).timeout
	tv.encender()
	_comprobar(tv._desbloqueada and not tv._encendida, "Tras la espera queda habilitada, pero no fuera de la PC")
	_comprobar(tv._cartel_visible, "Al habilitarse aparece el cartel")
	await create_timer(5.2).timeout
	habitacion._apagar_despertador()
	await habitacion._sentarse()
	habitacion.escritorio._hay_linkedout = false
	var drenaje_base: float = gm.drenaje_actual()
	_pulsar_t(tv)
	# Ahora la primera T enciende Y mira: si solo encendiera, nadie veria
	# la animacion de encendido.
	_comprobar(tv._encendida and tv.esta_mirando(), "Primera T enciende y ademas mira")
	_comprobar(not tv._cartel_visible, "Apretar T cierra el cartel")
	_comprobar(tv.marco.scale.y < 0.5, "El tubo arranca cerrado: hay animacion de encendido")
	_comprobar(is_equal_approx(gm.drenaje_actual(), drenaje_base * 0.9), "TV reduce el drenaje un 10%")

	# Dejar que termine esa primera mirada antes de seguir.
	await create_timer(5.0).timeout
	_comprobar(not tv.esta_mirando(), "La primera mirada termina sola")
	_comprobar(tv.marco.scale.is_equal_approx(Vector2.ONE), "El tubo queda abierto del todo")
	tv._cooldown_restante = 0.0
	_comprobar(tv.portada.visible and tv.pelicula.stream == null, "Sin pelicula se muestra la portada")
	_comprobar(tv.sonido.global_position.is_equal_approx(tv._pantalla.global_position), "Audio ubicado en la TV")
	var audio_local: Vector3 = habitacion.jugador.camara.to_local(tv.sonido.global_position)
	_comprobar(audio_local.x > 0.0, "La fuente de sonido esta a la derecha del jugador sentado")

	# LinkedOut y vape se combinan; cerrar LinkedOut conserva Netflox.
	habitacion.escritorio._abrir_linkedout()
	await process_frame
	await process_frame
	gm.aplicar_buff_vape()
	_comprobar(is_equal_approx(gm.drenaje_actual(), drenaje_base * 0.9 * 0.75 * 0.9), "Los tres alivios se combinan")
	habitacion.escritorio._ventanas[-1].cerrar()
	await create_timer(2.0).timeout
	_comprobar(is_equal_approx(gm.mult_drenaje_netflox, 0.9) and is_equal_approx(gm.mult_drenaje_externo, 1.0), "Cerrar LinkedOut no pisa la TV")

	# Dos gestos fisicos no pueden mover la camara al mismo tiempo.
	habitacion._vapeando = true
	tv.mirar()
	_comprobar(not tv.esta_mirando(), "No permite mirar TV durante el vape")
	habitacion._vapeando = false
	habitacion._mirando_telefono = true
	tv.mirar()
	_comprobar(not tv.esta_mirando(), "No permite mirar TV durante el celular")
	habitacion._mirando_telefono = false
	gm.dopamina = 20.0
	var camara_base: Transform3D = habitacion.jugador.camara.transform
	var fov_base: float = habitacion.jugador.camara.fov
	Input.action_press("mirar_television")
	tv._process(0.0)
	_comprobar(tv.esta_mirando(), "La siguiente T vuelve a mirar")
	_comprobar(not gm.drenaje_pausado and not gm.dopamina_congelada, "TV no congela la barra")
	Input.action_press("vapear")
	habitacion._actualizar_vape(0.0)
	Input.action_release("vapear")
	habitacion._telefono_activo = true
	Input.action_press("mirar_celular")
	habitacion._actualizar_telefono(0.0)
	Input.action_release("mirar_celular")
	habitacion._telefono_activo = false
	_comprobar(not habitacion._vapeando and not habitacion._mirando_telefono, "TV bloquea vape y celular durante la mirada")
	await create_timer(1.15).timeout
	var camara: Camera3D = habitacion.jugador.camara
	var hacia_tv: Vector3 = (tv._pantalla.global_position - camara.global_position).normalized()
	_comprobar((-camara.global_basis.z).dot(hacia_tv) > 0.999, "Camara mira la television desde la silla")
	_comprobar(is_equal_approx(camara.fov, tv.fov_television), "Zoom acerca el encuadre de la TV")
	await create_timer(3.45).timeout
	_comprobar(not tv.esta_mirando() and camara.transform.is_equal_approx(camara_base), "Camara vuelve al monitor")
	_comprobar(is_equal_approx(camara.fov, fov_base), "Al volver se restaura el encuadre de la PC")
	_comprobar(is_equal_approx(gm.dopamina, 90.0), "Mirada completa entrega exactamente 70")
	_comprobar(tv._cooldown_restante > 28.0, "Cooldown de 30 segundos empieza al terminar")
	tv.mirar()
	_comprobar(not tv.esta_mirando(), "Cooldown impide repetir")
	await create_timer(32.0).timeout
	_comprobar(not tv.esta_mirando() and is_equal_approx(gm.dopamina, 90.0), "Mantener T no repite tras el cooldown")
	Input.action_release("mirar_television")
	await process_frame

	# Un tropiezo durante el giro cancela el premio y restaura la camara.
	tv.mirar()
	await create_timer(0.8).timeout
	gm.activo = false
	gm.fallo_temprano.emit()
	_comprobar(not tv.esta_mirando() and camara.transform.is_equal_approx(camara_base), "Tropiezo cancela el giro")
	_comprobar(is_equal_approx(camara.fov, fov_base), "Tropiezo tambien cancela el zoom")
	await create_timer(3.5).timeout
	_comprobar(is_equal_approx(gm.dopamina, 30.0) and tv._encendida, "Tropiezo revive sin premio tardio y conserva TV")
	tv.mirar()
	gm.activo = false
	gm.dia_arruinado.emit()
	_comprobar(not tv.esta_mirando() and not tv._encendida and is_equal_approx(gm.mult_drenaje_netflox, 1.0), "Fin del dia apaga y limpia el alivio")
	habitacion.queue_free()
	await process_frame
	gm.reiniciar()
	_comprobar(is_equal_approx(gm.mult_drenaje_netflox, 1.0), "Nueva partida restaura el drenaje")

	# Se cargan imagen y sonido reales sin tocar sus archivos ni el modelo.
	habitacion = escena.instantiate()
	tv = habitacion.get_node("Netflox")
	tv.ruta_video = "res://assets/video/subway/subway.ogv"
	tv.ruta_audio = "res://assets/audio/ambiente/zumbido.ogg"
	tv.demora_aviso = 0.4
	root.add_child(habitacion)
	current_scene = habitacion
	await create_timer(5.2).timeout
	habitacion._apagar_despertador()
	await habitacion._sentarse()
	gm.apps_desbloqueadas = 5
	gm.app_desbloqueada.emit(4)
	await create_timer(1.0).timeout
	_comprobar(not tv._encendida and tv._cooldown_restante == 0.0, "Habitacion nueva arranca con TV apagada")
	tv.encender()
	await process_frame
	_comprobar(tv.pelicula.is_playing() and tv.sonido.playing and not tv.portada.visible, "Reproduce video y audio 3D cuando hay recursos")
	tv.mirar()
	gm.activo = false
	gm.colapso.emit()
	_comprobar(not tv.esta_mirando() and not tv.pelicula.is_playing() and not tv.sonido.playing, "Colapso corta imagen, audio y giro")
	_comprobar(is_equal_approx(habitacion.jugador.camara.fov, tv._fov_base), "Colapso restaura el encuadre")
	_comprobar(is_equal_approx(gm.mult_drenaje_netflox, 1.0), "Colapso restaura el multiplicador")
	# Dejar terminar el apagon y el anuncio del vape antes de liberar la
	# habitacion, para no dejar corutinas del juego pendientes en el test.
	await create_timer(10.0).timeout
	print("[Netflox TEST] completado; fallos=", _fallos)
	habitacion.queue_free()
	await process_frame
	await process_frame
	# Dar un ciclo real al mezclador para liberar el sonido del apagon.
	Engine.time_scale = 1.0
	await create_timer(0.25).timeout
	quit(0 if _fallos == 0 else 1)
