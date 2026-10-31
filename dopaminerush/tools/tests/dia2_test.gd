extends SceneTree

# Godot --headless --path . --script res://tools/tests/dia2_test.gd
#
# Prueba la noche y el dia siguiente:
#   - el despertar arranca con el cartel "Lunes 08:00" sobre el negro, y
#     el despertador suena recien con el cartel ya escrito
#   - al levantarse despues del apagon es de noche: la puerta no deja
#     salir y la cama dice [E] Dormir
#   - dormir apaga la luz, acuesta la camara y funde a negro
#   - el martes: cartel "Martes 11:00", sol de mañana, sin zumbido, el
#     jugador donde se desperto ayer y el despertador otra vez
#   - la compu no prende (y no te sienta) y la puerta lleva al parque
var _fallos: int = 0
var _h: Node3D


func _initialize() -> void:
	call_deferred("_probar")


func _comprobar(condicion: bool, mensaje: String) -> void:
	if not condicion:
		_fallos += 1
		push_error("[Dia2 TEST] " + mensaje)


func _esperar(segundos: float) -> void:
	await create_timer(segundos).timeout


# Lo que piensa el personaje en este momento ("" si no hay dialogo)
func _pensamiento() -> String:
	var dialogo = _h.dialogo
	return dialogo._completo if dialogo.esta_abierto() else ""


func _cerrar_dialogo() -> void:
	if _h.dialogo.esta_abierto():
		_h.dialogo._cerrar()
	await _esperar(0.4)


func _probar() -> void:
	create_timer(120.0).timeout.connect(func(): quit(2))
	var gm = root.get_node("GameManager")
	gm.reiniciar()

	_h = load("res://escenas/01_habitacion/habitacion.tscn").instantiate()
	root.add_child(_h)
	await process_frame
	var cartel = _h._cartel_dia
	var despertador: AudioStreamPlayer3D = _h.sonido_despertador

	# ---- el lunes ----
	_comprobar(not cartel.esta_visible(), "Al principio solo hay negro")
	await _esperar(1.3)
	_comprobar(cartel.esta_visible() and cartel.texto() == "Lunes 08:00",
		"Sobre el negro aparece el cartel del lunes ('%s')" % cartel.texto())
	_comprobar(despertador == null or not despertador.playing, "El despertador todavia no suena: primero el cartel")
	await _esperar(2.0)
	_comprobar(despertador == null or despertador.playing, "Con el cartel escrito, suena el despertador")
	_comprobar(not _h.jugador.puede_mirar, "Todavia es negro: no se puede mirar")
	await _esperar(5.0)
	_comprobar(not cartel.esta_visible(), "Con la pieza a la vista, el cartel ya se fue")
	_comprobar(_h.jugador.puede_mirar, "Y se puede buscar el despertador con la vista")
	_h._apagar_despertador()

	# ---- la noche ----
	# Como si viniera del apagon: sentado, y se levanta.
	_h._sentado = true
	_h._transform_local_original = _h.jugador.camara.transform
	await _h._levantarse()
	_comprobar(_h._de_noche and not _h._puede_salir, "Al levantarse es de noche y no se puede salir")
	_comprobar(_h.cama.texto_interaccion == "Dormir" and _h.cama.activo, "La cama dice [E] Dormir")
	_comprobar(_h.puerta.activo, "La puerta responde")
	_comprobar(_h.escritorio.obtener_minutos_del_dia() >= 23 * 60.0, "Y afuera es de noche")
	_h._salir_al_parque()
	_comprobar(_pensamiento().contains("tarde"), "La puerta dice que ya es tarde ('%s')" % _pensamiento())
	await _cerrar_dialogo()

	# ---- dormir ----
	Engine.time_scale = 3.0
	_h._luz_prendida = true
	_h.cama.usado.emit()
	await _esperar(1.0 * 3.0)
	_comprobar(not _h._luz_prendida, "Al dormir se apaga la luz")
	_comprobar(not _h.jugador.get_node("Cuerpo").visible, "El cuerpo se esconde mientras se acuesta")
	var t := 0.0
	while _h._dia < 2 and t < 40.0:
		await _esperar(0.25)
		t += 0.25
	_comprobar(_h._dia == 2, "Pasa la noche")
	Engine.time_scale = 1.0

	# ---- el martes ----
	_comprobar(is_equal_approx(_h.escritorio.obtener_minutos_del_dia(), 11 * 60.0), "Es martes a las 11")
	var donde: Vector3 = _h.jugador.global_transform.origin - _h._jugador_inicio.origin
	_comprobar(Vector2(donde.x, donde.z).length() < 0.01,
		"Se despierta donde se desperto ayer")
	_comprobar(_h.jugador.get_node("Cuerpo").visible, "El cuerpo vuelve")
	_comprobar(_h.despertador.activo and not _h._desperto, "Hay que apagar el despertador otra vez")
	_comprobar(_h._zumbido == null or not _h._zumbido.playing, "Sin el zumbido de la compu")
	var luz_ventana: SpotLight3D = _h.get_node("CicloDia/LuzVentana")
	_comprobar(luz_ventana.light_energy > 3.0, "Entra sol de mañana por la ventana (%.1f)" % luz_ventana.light_energy)
	await _esperar(1.5)
	_comprobar(cartel.esta_visible() and cartel.texto() == "Martes 11:00",
		"El cartel del martes ('%s')" % cartel.texto())
	await _esperar(7.0)
	_comprobar(not cartel.esta_visible() and _h.jugador.puede_mirar, "Aparece la pieza")
	_h._apagar_despertador()
	_comprobar(_h.jugador.puede_mover, "Apagado el despertador, se puede caminar")

	# ---- la compu no prende ----
	_comprobar(_h.monitor.activo and _h.monitor.texto_interaccion == "Prender la compu", "El monitor se puede tocar")
	await _h._sentarse()
	_comprobar(not _h._sentado, "Pero no te sienta")
	_comprobar(_pensamiento().contains("desenchufada"), "Quedo desenchufada ('%s')" % _pensamiento())
	_comprobar(not gm.activo, "Y la partida no arranca")
	await _cerrar_dialogo()

	# ---- la salida ----
	_comprobar(_h._puede_salir and _h.puerta.activo, "La puerta, ahora si, lleva afuera")
	_comprobar(_h.cama.texto_interaccion != "Dormir", "La cama vuelve a ser una cama")
	_h.cama.usado.emit()
	_comprobar(_pensamiento() != "" and not _h._durmiendo, "Y no te vuelve a dormir ('%s')" % _pensamiento())

	print("[Dia2 TEST] completado; fallos=", _fallos)
	quit(_fallos)
