extends SceneTree

# Godot --headless --path . --script res://tools/tests/cuerpo_test.gd
#
# Prueba el cuerpo del jugador (el que solo hace sombra):
#   - tiene esqueleto, piel y solo hace sombra (la camara no lo ve)
#   - quieto: parado sobre el piso, con los brazos al costado
#   - caminando: las piernas van y vienen, el brazo va al reves que la
#     pierna, y cada paso (medio ciclo) dura lo mismo que un sonido de paso
#   - para atras el paso se invierte; de costado gira la cadera
#   - mide 1,80; la camara queda mas arriba que los ojos (donde estaba)
#   - rapido (5 m/s, la pieza) trota, con el paso al ritmo de los sonidos
#   - sentado: cuando la camara baja se sienta solo, sin meter los pies
#     en el piso
#   - la cabeza mira para donde mira la camara
var _fallos: int = 0
var _j: CharacterBody3D
var _cuerpo: Node3D
var _esq: Skeleton3D


func _initialize() -> void:
	call_deferred("_probar")


func _comprobar(condicion: bool, mensaje: String) -> void:
	if not condicion:
		_fallos += 1
		push_error("[Cuerpo TEST] " + mensaje)


# En el espacio del jugador: el piso esta a 0,1 y la camara a 2,25.
func _hueso(nombre: String) -> Transform3D:
	return _j.global_transform.affine_inverse() * _esq.global_transform * _esq.get_bone_global_pose(_esq.find_bone(nombre))


func _muslo(lado: String) -> float:
	return _esq.get_bone_pose_rotation(_esq.find_bone("Muslo" + lado)).get_euler().x


# Mueve al jugador como lo haria un tween (la fisica apagada) y devuelve
# lo que hicieron los muslos.
func _caminar(direccion_local: Vector3, segundos: float, rapidez: float) -> Dictionary:
	var datos := {"min": INF, "max": -INF, "contrafase": 0, "muestras": 0}
	var dir := (_j.global_basis * direccion_local).normalized()
	var t := 0.0
	while t < segundos:
		await process_frame
		var dt := root.get_process_delta_time()
		t += dt
		_j.global_position += dir * rapidez * dt
		var m := _muslo(".D")
		datos["min"] = minf(datos["min"], m)
		datos["max"] = maxf(datos["max"], m)
		# El brazo derecho va al reves que la pierna derecha
		var brazo := _esq.get_bone_pose_rotation(_esq.find_bone("Brazo.D")).get_euler(EULER_ORDER_XYZ).x
		if absf(m) > deg_to_rad(8.0):
			datos["muestras"] += 1
			if signf(brazo) != signf(m):
				datos["contrafase"] += 1
	return datos


func _quieto(frames: int) -> void:
	for i in frames:
		await process_frame


func _probar() -> void:
	create_timer(60.0).timeout.connect(func(): quit(2))
	# Sin pantalla los frames corren lo mas rapido posible: la velocidad
	# medida (distancia / tiempo del frame) tiene que ser la real.
	Engine.max_fps = 60
	var piso := StaticBody3D.new()
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(80, 1, 80)
	forma.shape = caja
	forma.position.y = -0.5
	piso.add_child(forma)
	root.add_child(piso)

	_j = load("res://escenas/01_habitacion/jugador.tscn").instantiate()
	root.add_child(_j)
	_j.position = Vector3(0, -0.1, 0)
	_j.set_physics_process(false)
	_cuerpo = _j.get_node("Cuerpo")
	_esq = _cuerpo.get_node("Esqueleto")
	var malla: MeshInstance3D = _esq.get_node("Malla")
	await _quieto(5)

	# ---- lo basico ----
	_comprobar(_esq.get_bone_count() == 17, "Tiene esqueleto (%d huesos)" % _esq.get_bone_count())
	_comprobar(malla.skin != null and malla.skin.get_bind_count() == 17, "La malla esta pegada al esqueleto")
	_comprobar(malla.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY,
		"Solo hace sombra: la camara nunca lo ve")
	_comprobar(absf(malla.get_aabb().size.y - 1.8) < 0.05, "Mide 1,80 m (%.2f)" % malla.get_aabb().size.y)

	# ---- quieto ----
	await _quieto(30)
	var pie := _hueso("Pie.D").origin
	_comprobar(absf(pie.y - 0.215) < 0.03, "Quieto, el tobillo esta a la altura del tobillo (%.3f)" % pie.y)
	var mano := _hueso("Mano.D").origin
	var hombro := _hueso("Brazo.D").origin
	_comprobar(mano.y < hombro.y - 0.35, "Quieto, los brazos cuelgan (mano %.2f, hombro %.2f)" % [mano.y, hombro.y])
	_comprobar(absf(mano.x) - absf(hombro.x) > 0.05 and absf(mano.x - hombro.x) < 0.25,
		"Separados del cuerpo pero no en cruz (%.2f)" % (absf(mano.x) - absf(hombro.x)))
	var ojos := _hueso("Cabeza").origin.y + 0.09
	_comprobar(absf(ojos - 1.78) < 0.05, "Los ojos de una persona de 1,80 (%.2f)" % ojos)
	_comprobar(is_equal_approx(_j.camara.position.y, 2.2480912), "La camara sigue donde estaba")

	# ---- caminar ----
	_j.velocidad = 2.4
	var adelante: Dictionary = await _caminar(Vector3(0, 0, -1), 2.0, 2.4)
	_comprobar(adelante["max"] > deg_to_rad(15.0) and adelante["min"] < deg_to_rad(-15.0),
		"Caminando, la pierna va y viene (%.0f a %.0f grados)" % [rad_to_deg(adelante["min"]), rad_to_deg(adelante["max"])])
	_comprobar(adelante["max"] < deg_to_rad(30.0), "Sin hacer la vertical: el paso no pasa de 30 grados")
	_comprobar(_cuerpo._trote < 0.1, "A 2,4 m/s camina, no trota")
	_comprobar(adelante["contrafase"] > adelante["muestras"] * 0.8,
		"El brazo va al reves que la pierna (%d de %d)" % [adelante["contrafase"], adelante["muestras"]])
	# Medio ciclo por paso, igual que el sonido de pasos
	_comprobar(_cuerpo._marcha > 0.9, "Esta caminando (%.2f)" % _cuerpo._marcha)

	# A 5 m/s (la pieza) trota
	_j.velocidad = 5.0
	var rapido: Dictionary = await _caminar(Vector3(0, 0, -1), 1.5, 5.0)
	_comprobar(_cuerpo._trote > 0.9, "A 5 m/s trota (%.2f)" % _cuerpo._trote)
	_comprobar(rapido["max"] < deg_to_rad(40.0), "Sin abrirse de mas (%.0f)" % rad_to_deg(rapido["max"]))
	var codo := _esq.get_bone_pose_rotation(_esq.find_bone("Antebrazo.D")).get_euler().y
	_comprobar(codo > deg_to_rad(50.0), "Trotando, los codos doblados (%.0f)" % rad_to_deg(codo))
	# Trotando, medio ciclo por paso, igual que el sonido de pasos
	var f_antes: float = _cuerpo._fase
	await _caminar(Vector3(0, 0, -1), _j._tranco() / 5.0, 5.0)
	var avance := fposmod(_cuerpo._fase - f_antes, TAU)
	_comprobar(absf(avance - PI) < 0.35, "Un tranco es medio ciclo del paso (%.2f, esperado %.2f)" % [avance, PI])

	# ---- para atras ----
	_j.velocidad = 2.4
	var f0: float = _cuerpo._fase
	await _caminar(Vector3(0, 0, 1), 0.5, 2.4)
	f0 = _cuerpo._fase
	await _caminar(Vector3(0, 0, 1), 0.3, 2.4)
	var f1: float = _cuerpo._fase
	_comprobar(wrapf(f1 - f0, -PI, PI) < 0.0, "Para atras, el paso va al reves")

	# ---- de costado ----
	await _caminar(Vector3(1, 0, 0), 1.0, 2.4)
	_comprobar(absf(_cuerpo._giro_cadera) > deg_to_rad(30.0),
		"De costado, la cadera gira hacia donde va (%.0f)" % rad_to_deg(_cuerpo._giro_cadera))

	# ---- frenar ----
	await _quieto(60)
	_comprobar(_cuerpo._marcha < 0.05, "Al frenar vuelve a quieto")
	_comprobar(absf(_muslo(".D")) < deg_to_rad(5.0), "Con las piernas juntas")

	# ---- sentarse ----
	# La silla baja la camara a 1,52; el banco del parque a 0,83.
	for caso in [[1.52, "la silla"], [0.83, "el banco"]]:
		var t := create_tween()
		t.tween_property(_j.camara, "position:y", caso[0], 0.6)
		await t.finished
		await _quieto(40)
		_comprobar(_cuerpo._sentado > 0.95, "En %s se sienta solo (%.2f)" % [caso[1], _cuerpo._sentado])
		_comprobar(_muslo(".D") > deg_to_rad(70.0), "Con los muslos para adelante")
		var cadera := _hueso("Cadera").origin
		_comprobar(cadera.y < 1.0 and cadera.y > 0.45, "La cadera baja al asiento (%.2f)" % cadera.y)
		_comprobar(_hueso("Pie.D").origin.y > 0.15, "Los pies no se meten en el piso (%.2f)" % _hueso("Pie.D").origin.y)
	# en la silla
	var subir := create_tween()
	subir.tween_property(_j.camara, "position:y", 1.52, 0.3)
	await subir.finished
	await _quieto(40)
	var cabeza := _hueso("Cabeza").origin
	_comprobar(cabeza.y < _j.camara.position.y and cabeza.y > _j.camara.position.y - 0.7,
		"Sentado en la silla, la cabeza queda debajo de la camara (%.2f / %.2f)" % [cabeza.y, _j.camara.position.y])

	# ---- mirar ----
	_j.camara.rotation = Vector3(0, deg_to_rad(60.0), 0)
	await _quieto(5)
	var frente := -_hueso("Cabeza").basis.z
	var giro := rad_to_deg(atan2(-frente.x, -frente.z))
	_comprobar(absf(giro - 60.0) < 8.0, "Sentado, la cabeza gira con la camara (%.0f grados)" % giro)

	var bajar := create_tween()
	bajar.tween_property(_j.camara, "position:y", 2.248, 0.6)
	await bajar.finished
	await _quieto(40)
	_comprobar(_cuerpo._sentado < 0.05, "Al levantarse vuelve a quedar parado")
	_j.camara.rotation = Vector3(deg_to_rad(-50.0), 0, 0)
	await _quieto(5)
	frente = -_hueso("Cabeza").basis.z
	var abajo := rad_to_deg(asin(frente.y))
	_comprobar(abajo < -35.0, "Mirando para abajo, la cabeza baja (%.0f grados)" % abajo)

	print("[Cuerpo TEST] completado; fallos=", _fallos)
	quit(_fallos)
