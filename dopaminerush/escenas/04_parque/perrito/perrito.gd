extends CharacterBody3D

# Companero del paseo. Sigue las huellas del jugador para respetar las curvas
# del camino; no depende del catalogo de apps ni otorga premios de dopamina.
@export_group("Paseo")
@export var velocidad_paseo: float = 3.1
@export var separacion_lateral: float = 0.85
@export_range(0.5, 4.0) var distancia_seguimiento: float = 2.0
@export var duracion_caricia: float = 2.0

@onready var modelo: Node3D = $Modelo
@onready var cabeza: Node3D = $Modelo/Cabeza
@onready var cola: Node3D = $Modelo/Cola
@onready var mano: Node3D = $Modelo/ManoCaricia
@onready var interaccion: Interactuable = $Interaccion
@onready var patas: Array[Node] = $Modelo/Patas.get_children()

var _jugador: CharacterBody3D
var _huellas: Array[Vector3] = []
var _ultima_muestra: Vector3
var _tiempo: float = 0.0
var _paso: float = 0.0
var _acariciando: bool = false
var _descansando: bool = false
var _punto_descanso: Vector3
var _tween_caricia: Tween
var _camara: Camera3D
var _camara_base: Transform3D
var _fov_base: float
var _controles_base: Array[bool] = []


func _ready() -> void:
	interaccion.usado.connect(acariciar)
	add_collision_exception_with(interaccion)
	mano.hide()


func configurar(jugador: CharacterBody3D) -> void:
	_jugador = jugador
	# El jugador puede pasar a su lado sin que el perro cierre el camino.
	jugador.add_collision_exception_with(interaccion)
	add_collision_exception_with(jugador)
	_ultima_muestra = jugador.global_position
	var derecha: Vector3 = jugador.global_basis.x.normalized()
	var adelante: Vector3 = -jugador.global_basis.z.normalized()
	# Espera visible al costado del primer tramo hasta que empiece el paseo.
	global_position = jugador.global_position + derecha * 1.1 + adelante * 3.3
	_orientar(jugador.global_position - global_position, 1.0)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_jugador):
		return
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	var direccion := Vector3.ZERO
	var velocidad_actual: float = velocidad_paseo
	if not _acariciando:
		if _descansando:
			direccion = _plano(_punto_descanso - global_position)
		else:
			_registrar_huellas()
			while not _huellas.is_empty() and _plano(_huellas[0] - global_position).length() < 0.3:
				_huellas.pop_front()
			if not _huellas.is_empty():
				direccion = _plano(_huellas[0] - global_position)
			# Conserva un margen detras del jugador y frena suavemente al
			# alcanzarlo. Si el jugador se acerca para acariciarlo, espera.
			var distancia: float = _plano(_jugador.global_position - global_position).length()
			velocidad_actual = minf(velocidad_paseo, maxf(0.0, distancia - distancia_seguimiento) * 4.0)
			if distancia < distancia_seguimiento + 0.05:
				direccion = Vector3.ZERO
		if direccion.length() > 0.3:
			direccion = _evitar_obstaculos(direccion.normalized())
		else:
			direccion = Vector3.ZERO
	velocity.x = direccion.x * velocidad_actual
	velocity.z = direccion.z * velocidad_actual
	move_and_slide()
	var rumbo: Vector3 = direccion if direccion.length_squared() > 0.01 else _jugador.global_position - global_position
	_orientar(rumbo, 1.0 - exp(-delta * 7.0))


func _registrar_huellas() -> void:
	var avance := _plano(_jugador.global_position - _ultima_muestra)
	if avance.length() < 0.45:
		return
	var derecha := Vector3(-avance.z, 0.0, avance.x).normalized()
	_huellas.append(_jugador.global_position + derecha * separacion_lateral)
	_ultima_muestra = _jugador.global_position
	# Una caminata larga no acumula puntos indefinidamente.
	if _huellas.size() > 96:
		_huellas.pop_front()


func _evitar_obstaculos(direccion: Vector3) -> Vector3:
	# Sondeos a la altura del cuerpo, excluyendo al jugador y al propio
	# interactuable. El suelo se resuelve con move_and_slide y gravedad.
	var espacio := get_world_3d().direct_space_state
	var origen := global_position + Vector3(0.0, 0.45, 0.0)
	for angulo in [0.0, 45.0, -45.0, 85.0, -85.0]:
		var candidato := direccion.rotated(Vector3.UP, deg_to_rad(angulo))
		var consulta := PhysicsRayQueryParameters3D.create(origen, origen + candidato * 0.9, 1)
		consulta.exclude = [get_rid(), interaccion.get_rid(), _jugador.get_rid()]
		if espacio.intersect_ray(consulta).is_empty():
			return candidato
	return Vector3.ZERO


func _orientar(direccion: Vector3, peso: float) -> void:
	direccion = _plano(direccion)
	if direccion.length_squared() > 0.001:
		rotation.y = lerp_angle(rotation.y, atan2(-direccion.x, -direccion.z), peso)


func _plano(vector: Vector3) -> Vector3:
	return Vector3(vector.x, 0.0, vector.z)


func _process(delta: float) -> void:
	_tiempo += delta
	var caminando := Vector2(velocity.x, velocity.z).length() > 0.2
	if caminando:
		_paso += delta * 11.0
	for i in patas.size():
		var fase: float = 0.0 if i == 0 or i == 3 else PI
		patas[i].rotation.x = sin(_paso + fase) * 0.38 if caminando else 0.0
	modelo.position.y = absf(sin(_paso)) * 0.035 if caminando else sin(_tiempo * 2.2) * 0.008
	cola.rotation.z = sin(_tiempo * (15.0 if _acariciando else 6.0)) * (0.65 if _acariciando else 0.28)
	cabeza.rotation.x = sin(_tiempo * 8.0) * 0.06 if _acariciando else 0.0
	if _acariciando:
		mano.position = Vector3(sin(_tiempo * 8.0) * 0.045, 1.03 + sin(_tiempo * 8.0) * 0.035, -0.37)


func acariciar() -> void:
	if _acariciando or _descansando or not is_instance_valid(_jugador):
		return
	if not _jugador.puede_interactuar or _plano(_jugador.global_position - global_position).length() > 2.6:
		return
	_acariciando = true
	interaccion.activo = false
	_camara = _jugador.camara
	_camara_base = _camara.transform
	_fov_base = _camara.fov
	_controles_base = [_jugador.puede_mover, _jugador.puede_mirar, _jugador.puede_interactuar]
	_jugador.puede_mover = false
	_jugador.puede_mirar = false
	_jugador.puede_interactuar = false
	velocity.x = 0.0
	velocity.z = 0.0
	_orientar(_jugador.global_position - global_position, 1.0)
	mano.show()
	mano.scale = Vector3.ZERO
	var encuadre := _camara.global_transform.looking_at(cabeza.global_position - Vector3(0.0, 0.15, 0.0), Vector3.UP)
	var destino: Transform3D = _camara.get_parent().global_transform.affine_inverse() * encuadre
	var giro: float = minf(0.3, duracion_caricia * 0.5)
	_tween_caricia = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween_caricia.tween_property(_camara, "transform", destino, giro)
	_tween_caricia.parallel().tween_property(_camara, "fov", minf(_fov_base, 55.0), giro)
	_tween_caricia.parallel().tween_property(mano, "scale", Vector3.ONE, giro)
	_tween_caricia.tween_interval(maxf(0.0, duracion_caricia - giro * 2.0))
	_tween_caricia.tween_property(_camara, "transform", _camara_base, giro)
	_tween_caricia.parallel().tween_property(_camara, "fov", _fov_base, giro)
	_tween_caricia.parallel().tween_property(mano, "scale", Vector3.ZERO, giro)
	_tween_caricia.finished.connect(_terminar_caricia)


func _terminar_caricia() -> void:
	if not _acariciando:
		return
	if is_instance_valid(_camara):
		_camara.transform = _camara_base
		_camara.fov = _fov_base
	if is_instance_valid(_jugador):
		_jugador.puede_mover = _controles_base[0]
		_jugador.puede_mirar = _controles_base[1]
		_jugador.puede_interactuar = _controles_base[2]
		# El controlador conserva los angulos de la mirada anterior.
	_acariciando = false
	mano.hide()
	interaccion.activo = not _descansando


func descansar(punto: Vector3) -> void:
	if _tween_caricia and _tween_caricia.is_valid():
		_tween_caricia.kill()
	_terminar_caricia()
	_descansando = true
	interaccion.activo = false
	_punto_descanso = punto
	_huellas.clear()


func _exit_tree() -> void:
	if _tween_caricia and _tween_caricia.is_valid():
		_tween_caricia.kill()
	_terminar_caricia()
