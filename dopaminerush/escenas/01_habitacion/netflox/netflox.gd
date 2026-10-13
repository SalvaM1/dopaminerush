extends Node3D

# Television fisica, fuera del catalogo de apps. La habitacion solo aporta
# el acceso a la camara y bloquea sus otros gestos mientras se mira la TV.
# El alivio tiene su propio multiplicador para no pisar LinkedOut ni el vape.
@export_group("Balance")
@export var apps_para_desbloquear: int = 4
@export_range(0.0, 1.0) var factor_drenaje: float = 0.9
@export var dopamina_por_mirada: float = 15.0
@export var cooldown: float = 25.0
@export var duracion_mirada: float = 3.0
@export var duracion_giro: float = 0.55

@export_group("Encuadre")
@export_range(10.0, 80.0) var fov_television: float = 22.0

@export_group("Pelicula")
# Imagen y sonido separados: el audio del VideoStreamPlayer es 2D.
# La pista aparte se reproduce desde la TV con AudioStreamPlayer3D.
@export_file("*.ogv") var ruta_video: String = "res://assets/video/netflox/pelicula.ogv"
@export_file("*.ogg", "*.wav", "*.mp3") var ruta_audio: String = "res://assets/audio/netflox/pelicula.ogg"

@onready var viewport_tv: SubViewport = $PantallaViewport
@onready var pelicula: VideoStreamPlayer = $PantallaViewport/Pantalla/Pelicula
@onready var portada: Control = $PantallaViewport/Pantalla/Portada
@onready var sonido: AudioStreamPlayer3D = $SonidoPelicula

var _habitacion: Node3D
var _pantalla: CSGBox3D
var _superficie: MeshInstance3D
var _indicador: Control
var _contador: Label
var _efecto: Label
var _camara: Camera3D
var _camara_base: Transform3D
var _fov_base: float
var _tween_mirada: Tween
var _desbloqueada: bool = false
var _encendida: bool = false
var _mirando: bool = false
var _cooldown_restante: float = 0.0


func _ready() -> void:
	GameManager.app_desbloqueada.connect(_al_desbloquear_app)
	GameManager.fallo_temprano.connect(_cancelar_mirada)
	GameManager.dia_arruinado.connect(apagar)
	GameManager.colapso.connect(apagar)
	sonido.finished.connect(_repetir_audio)
	pelicula.volume_db = -80.0
	_cargar_pelicula()
	viewport_tv.render_target_update_mode = SubViewport.UPDATE_DISABLED


func configurar(habitacion: Node3D) -> void:
	_habitacion = habitacion
	_pantalla = habitacion.get_node("HabitacionVisual/Televisor/Cuerpo/Pantalla")
	_indicador = habitacion.get_node("UI/IndicadorNetflox")
	_contador = _indicador.get_node("Contador")
	_efecto = _indicador.get_node("Efecto")
	_indicador.hide()

	# El modelo existente queda en su lugar. Un quad sobre la cara que
	# mira al jugador recibe la imagen del viewport sin estirar los bordes.
	var vidrio := StandardMaterial3D.new()
	vidrio.albedo_color = Color(0.008, 0.008, 0.012)
	vidrio.roughness = 0.25
	_pantalla.material = vidrio
	var quad := QuadMesh.new()
	quad.size = Vector2(_pantalla.size.z, _pantalla.size.y)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = viewport_tv.get_texture()
	_superficie = MeshInstance3D.new()
	_superficie.name = "ImagenNetflox"
	_superficie.mesh = quad
	_superficie.material_override = material
	_superficie.position.x = -_pantalla.size.x * 0.5 - 0.002
	_superficie.rotation.y = -PI * 0.5
	_superficie.hide()
	_pantalla.add_child(_superficie)
	sonido.global_position = _pantalla.global_position
	_al_desbloquear_app(-1)


func _process(delta: float) -> void:
	if not is_instance_valid(_habitacion):
		return
	if GameManager.activo:
		_cooldown_restante = maxf(0.0, _cooldown_restante - delta)

	var disponible: bool = _desbloqueada and _habitacion.puede_usar_television()
	_indicador.visible = disponible or (_mirando and GameManager.activo)
	_actualizar_indicador()
	if not disponible or _mirando:
		return
	if Input.is_action_just_pressed("mirar_television"):
		if not _encendida:
			encender()
		else:
			mirar()


func _al_desbloquear_app(_indice: int) -> void:
	if GameManager.apps_desbloqueadas >= apps_para_desbloquear:
		_desbloqueada = true


func esta_mirando() -> bool:
	return _mirando


func encender() -> void:
	if _encendida or not _puede_usar():
		return
	_encendida = true
	GameManager.mult_drenaje_netflox = factor_drenaje
	_superficie.show()
	viewport_tv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if pelicula.stream:
		pelicula.play()
	if sonido.stream:
		sonido.play()
	_actualizar_indicador()


func mirar() -> void:
	if not _encendida or _mirando or _cooldown_restante > 0.0 or not _puede_usar():
		return
	_mirando = true
	_habitacion.soltar_mouse_del_monitor()
	_camara = _habitacion.jugador.camara
	_camara_base = _camara.transform
	_fov_base = _camara.fov

	# Girar desde la silla y acercar el encuadre para leer la pantalla.
	# El zoom acompana el giro y se restaura al volver al monitor.
	var global_destino := _camara.global_transform.looking_at(_pantalla.global_position, Vector3.UP)
	var destino: Transform3D = _camara.get_parent().global_transform.affine_inverse() * global_destino
	var giro: float = minf(duracion_giro, duracion_mirada * 0.5)
	_tween_mirada = create_tween()
	_tween_mirada.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween_mirada.tween_property(_camara, "transform", destino, giro)
	_tween_mirada.parallel().tween_property(_camara, "fov", minf(_fov_base, fov_television), giro)
	_tween_mirada.tween_interval(maxf(0.0, duracion_mirada - giro * 2.0))
	_tween_mirada.tween_property(_camara, "transform", _camara_base, giro)
	_tween_mirada.parallel().tween_property(_camara, "fov", _fov_base, giro)
	_tween_mirada.finished.connect(_terminar_mirada)
	_actualizar_indicador()


func _terminar_mirada() -> void:
	_mirando = false
	# El drenaje sigue corriendo mientras se mira. Si hubo una caida, no
	# se entrega una recompensa tardia ni se mueve la camara del colapso.
	if not _encendida or not GameManager.activo:
		return
	_cooldown_restante = cooldown
	GameManager.sumar_dopamina(dopamina_por_mirada, "netflox")
	Juice.numero_flotante(_indicador, "+%d" % int(dopamina_por_mirada),
		Color(0.45, 1.0, 0.6), Vector2(80, 10), 24)
	_actualizar_indicador()


func _cancelar_mirada() -> void:
	if _tween_mirada and _tween_mirada.is_valid():
		_tween_mirada.kill()
	if _mirando and is_instance_valid(_camara):
		_camara.transform = _camara_base
		_camara.fov = _fov_base
	_mirando = false


func apagar() -> void:
	_cancelar_mirada()
	_encendida = false
	GameManager.mult_drenaje_netflox = 1.0
	pelicula.stop()
	sonido.stop()
	viewport_tv.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if is_instance_valid(_superficie):
		_superficie.hide()
	if is_instance_valid(_indicador):
		_indicador.hide()


func _exit_tree() -> void:
	# Al recargar la habitacion no queda ni el alivio ni un giro pendiente.
	_cancelar_mirada()
	GameManager.mult_drenaje_netflox = 1.0


func _puede_usar() -> bool:
	return _desbloqueada and is_instance_valid(_habitacion) and _habitacion.puede_usar_television()


func _actualizar_indicador() -> void:
	if _mirando:
		_contador.text = "Mirando..."
	elif not _encendida:
		_contador.text = "[T] Encender"
	elif _cooldown_restante > 0.0:
		_contador.text = "%.0f s" % ceilf(_cooldown_restante)
	else:
		_contador.text = "[T] Mirar"
	_efecto.text = "-%.0f%% drenaje" % ((1.0 - factor_drenaje) * 100.0) if _encendida else "la tele de fondo"
	_indicador.modulate = Color(0.65, 0.65, 0.7) if _cooldown_restante > 0.0 else Color.WHITE


func _cargar_pelicula() -> void:
	if ruta_video != "" and ResourceLoader.exists(ruta_video):
		pelicula.stream = load(ruta_video)
	if ruta_audio != "" and ResourceLoader.exists(ruta_audio):
		sonido.stream = load(ruta_audio)
	# Sin archivos se conserva la portada; las mecanicas se pueden probar
	# ahora y la pelicula se agrega despues sin cambiar codigo.
	pelicula.visible = pelicula.stream != null
	portada.visible = pelicula.stream == null


func _repetir_audio() -> void:
	if _encendida and sonido.stream:
		sonido.play()
