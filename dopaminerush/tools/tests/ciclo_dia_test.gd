extends SceneTree

# Godot --headless --path . --script res://tools/tests/ciclo_dia_test.gd
var _fallos: int = 0


func _initialize() -> void:
	call_deferred("_probar")


func _comprobar(condicion: bool, mensaje: String) -> void:
	if not condicion:
		_fallos += 1
		push_error("[CicloDia TEST] " + mensaje)


func _hora(escritorio: Node, hora: float) -> void:
	escritorio._minutos = hora * 60.0
	escritorio._actualizar_reloj()


func _probar() -> void:
	Engine.time_scale = 4.0
	create_timer(40.0).timeout.connect(func(): quit(2))
	var gm = root.get_node("GameManager")
	gm.reiniciar()
	var escena = load("res://escenas/01_habitacion/habitacion.tscn")
	# La instancia de referencia se libera sin entrar en el arbol.
	var referencia = escena.instantiate()
	var original: Environment = referencia.get_node("WorldEnvironment").environment
	referencia.free()
	var habitacion = escena.instantiate()
	root.add_child(habitacion)
	current_scene = habitacion
	var escritorio = habitacion.escritorio
	escritorio.set_process(false)
	var ciclo = habitacion.get_node("CicloDia")
	_comprobar(escritorio.reloj.text == "08:00", "Reloj y pieza arrancan en la manana")
	_comprobar(ciclo.luz_ventana.light_energy > 4.0 and ciclo._entorno.ambient_light_energy > 0.7, "La manana tiene luz natural clara")
	_comprobar(ciclo._entorno != original and is_equal_approx(original.ambient_light_energy, 0.4), "Los cambios no alteran el recurso original")
	_comprobar(habitacion.get_node("HabitacionVisual/Ventana/Vidrio").cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "El vidrio deja entrar la luz")
	var energia_manana: float = ciclo.luz_ventana.light_energy
	escritorio._process(1.0)
	_comprobar(escritorio.reloj.text == "08:12" and ciclo.luz_ventana.light_energy > energia_manana, "Avance del reloj actualiza la luz en el mismo paso")
	_hora(escritorio, 12.0)
	var energia_mediodia: float = ciclo.luz_ventana.light_energy
	_comprobar(escritorio.reloj.text == "12:00" and energia_mediodia > energia_manana, "Mediodia mas luminoso que manana")
	_hora(escritorio, 18.0)
	var energia_tarde: float = ciclo.luz_ventana.light_energy
	var color_tarde: Color = ciclo.luz_ventana.light_color
	_comprobar(escritorio.reloj.text == "18:00" and color_tarde.r > color_tarde.g * 1.5, "Atardecer calido coincide con el reloj")
	_hora(escritorio, 18.001)
	_comprobar(absf(ciclo.luz_ventana.light_energy - energia_tarde) < 0.01, "Las etapas se unen sin saltos")
	_hora(escritorio, 22.0)
	_comprobar(escritorio.reloj.text == "22:00" and ciclo.luz_ventana.light_energy < energia_manana * 0.1, "La noche tiene poca luz por la ventana")
	_comprobar(ciclo._sol.light_energy == 0.0 and ciclo._cielo.sky_top_color.v < 0.15, "Sol apagado y cielo nocturno")
	escritorio._process(600.0)
	_comprobar(escritorio.reloj.text == "23:59" and escritorio.obtener_minutos_del_dia() == escritorio.FIN_DEL_DIA, "Una partida larga no vuelve de golpe a la manana")
	await create_timer(5.2).timeout
	habitacion._apagar_despertador()
	habitacion._al_usar_interruptor()
	await create_timer(0.4).timeout
	_hora(escritorio, 12.0)
	_comprobar(habitacion._luz_general.light_energy == 0.0 and ciclo.luz_ventana.light_energy > 4.0, "El interruptor no apaga el sol ni el ciclo prende el plafon")
	habitacion._al_usar_interruptor()
	await create_timer(0.4).timeout
	_comprobar(is_equal_approx(habitacion._luz_general.light_energy, habitacion._energia_luz_base), "El plafon conserva su control manual")
	habitacion.queue_free()
	await process_frame
	gm.reiniciar()
	habitacion = escena.instantiate()
	root.add_child(habitacion)
	current_scene = habitacion
	escritorio = habitacion.escritorio
	escritorio.set_process(false)
	ciclo = habitacion.get_node("CicloDia")
	_comprobar(escritorio.reloj.text == "08:00" and is_equal_approx(ciclo.luz_ventana.light_energy, energia_manana), "Un dia nuevo restaura la manana")
	await create_timer(5.2).timeout
	print("[CicloDia TEST] completado; fallos=", _fallos)
	habitacion.queue_free()
	await process_frame
	await process_frame
	Engine.time_scale = 1.0
	await create_timer(0.25).timeout
	quit(0 if _fallos == 0 else 1)
