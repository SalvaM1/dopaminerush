extends CharacterBody3D

# Script del jugador en primera persona.
# No necesita ningún mesh visible: no se ve el cuerpo.
#
# DOS MODOS DE MIRAR:
#   - De pie (mirar_sentado = false): el mouse gira el CUERPO. Asi el WASD
#     siempre avanza hacia donde estas mirando.
#   - Sentado (mirar_sentado = true): el cuerpo queda quieto y el mouse gira
#     solo la CAMARA, con un tope de giro, como alguien que gira la cabeza
#     en una silla. No se puede caminar en este modo.

@export var velocidad: float = 5.0
@export var sensibilidad_mouse: float = 0.003
@export var gravedad: float = 9.8

# Los controles se habilitan por separado, porque hay momentos donde se
# quiere uno si y otro no. Durante el colapso, por ejemplo, se puede mirar
# pero no caminar ni interactuar con nada.
@export var puede_mover: bool = true
@export var puede_mirar: bool = true
@export var puede_interactuar: bool = true

# Interruptor entre los dos modos de mirar
@export var mirar_sentado: bool = false

# Cuanto se puede girar la cabeza estando sentado, a cada lado
const LIMITE_GIRO_SENTADO: float = 75.0

# ---- PASOS ----
# Una carpeta con VARIANTES del mismo paso (.ogg, .wav o .mp3, sueltos, no
# un loop de caminata). Cada escena elige la suya: la pieza usa la de
# adentro y el parque la cambia por la de pasto (ver parque.gd). Si la
# carpeta esta vacia no suena nada y no se rompe nada.
@export_dir var carpeta_pasos: String = "res://assets/audio/pasos/pieza":
	set(valor):
		carpeta_pasos = valor
		_pasos = _buscar_pasos(valor)
@export_range(-30.0, 6.0) var volumen_pasos: float = -6.0

# La otra forma de sonar: una GRABACION de alguien caminando, en loop, que
# suena mientras el jugador camina y se pausa cuando para. Si esta puesta,
# reemplaza a los pasos sueltos. La usa el parque (ripio). Tiene que ser
# .ogg o .mp3: el loop de un .wav necesita marcas que no tiene.
@export_file("*.ogg", "*.mp3") var caminata_continua: String = "":
	set(valor):
		caminata_continua = valor
		_preparar_caminata()

const VARIACION_TONO_PASOS: float = 0.06
const FUNDIDO_ENTRADA_CAMINATA: float = 0.08   # arranca casi en seco
const FUNDIDO_SALIDA_CAMINATA: float = 0.25    # y al parar se apaga, no se corta

@onready var camara: Camera3D = $Camera3D
@onready var rayo: RayCast3D = $Camera3D/RayCast3D
@onready var cartel: Label = $UI/CartelInteraccion

var rotacion_vertical: float = 0.0
var rotacion_horizontal_sentado: float = 0.0

var _mira: Panel = null
var _estilo_mira: StyleBoxFlat = null

var _pasos: Array[AudioStream] = []
var _ultimo_paso: int = -1
var _recorrido: float = 0.0
var _reproductor_pasos: AudioStreamPlayer = null
var pasos_dados: int = 0      # para los tests y para depurar

var _reproductor_caminata: AudioStreamPlayer = null
var _caminata: AudioStream = null
var _ganancia_caminata: float = 0.0   # 0 a 1


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# El rayo sale desde adentro de la cápsula del propio jugador,
	# así que le decimos que se ignore a sí mismo.
	rayo.add_exception(self)

	cartel.hide()
	_crear_mira()

	# Dos voces: si un paso todavia suena cuando llega el siguiente, no
	# se corta en seco.
	_reproductor_pasos = AudioStreamPlayer.new()
	_reproductor_pasos.bus = "Ambiente"
	_reproductor_pasos.max_polyphony = 2
	add_child(_reproductor_pasos)
	if _pasos.is_empty():
		_pasos = _buscar_pasos(carpeta_pasos)

	_reproductor_caminata = AudioStreamPlayer.new()
	_reproductor_caminata.bus = "Ambiente"
	add_child(_reproductor_caminata)
	_preparar_caminata()


func _unhandled_input(event: InputEvent) -> void:
	if not puede_mirar:
		return

	if not (event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED):
		return

	# Arriba / abajo: siempre sobre la camara, en los dos modos
	rotacion_vertical -= event.relative.y * sensibilidad_mouse
	rotacion_vertical = clamp(rotacion_vertical, deg_to_rad(-80), deg_to_rad(80))
	camara.rotation.x = rotacion_vertical

	if mirar_sentado:
		# El cuerpo no se mueve: giramos la camara, con tope
		rotacion_horizontal_sentado -= event.relative.x * sensibilidad_mouse
		rotacion_horizontal_sentado = clamp(
			rotacion_horizontal_sentado,
			deg_to_rad(-LIMITE_GIRO_SENTADO),
			deg_to_rad(LIMITE_GIRO_SENTADO)
		)
		camara.rotation.y = rotacion_horizontal_sentado
	else:
		# De pie: giramos el cuerpo, asi el WASD sigue la mirada
		rotate_y(-event.relative.x * sensibilidad_mouse)


func _process(delta: float) -> void:
	_actualizar_caminata(delta)

	if puede_mirar and puede_interactuar:
		_revisar_interaccion()
	else:
		cartel.hide()
		_mostrar_mira(false)


func _revisar_interaccion() -> void:
	var objetivo := rayo.get_collider()

	# Solo cuenta si es interactuable Y esta activo
	if objetivo is Interactuable and objetivo.activo:
		cartel.text = "[E] " + objetivo.texto_interaccion
		cartel.show()
		_mostrar_mira(true, true)

		if Input.is_action_just_pressed("interactuar"):
			objetivo.interactuar()
	else:
		cartel.hide()
		_mostrar_mira(true, false)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravedad * delta

	var input_dir := Vector2.ZERO
	if puede_mover:
		input_dir = Input.get_vector(
			"mover_izquierda", "mover_derecha",
			"mover_adelante", "mover_atras"
		)

	var direccion := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direccion:
		velocity.x = direccion.x * velocidad
		velocity.z = direccion.z * velocidad
	else:
		velocity.x = move_toward(velocity.x, 0, velocidad)
		velocity.z = move_toward(velocity.z, 0, velocidad)

	move_and_slide()
	_avanzar_pasos(delta)


# ============================================================
#  Pasos
# ============================================================
#
# Suenan por DISTANCIA recorrida, no por tiempo: asi acompanan lo que se
# ve. Se mide la velocidad DESPUES de move_and_slide, que es la real:
# caminando contra una pared no se avanza, y no suenan pasos.
#
# Los movimientos con tween (sentarse en la silla o en el banco) no tocan
# la velocidad, asi que tampoco hacen ruido de pasos.

func _avanzar_pasos(delta: float) -> void:
	# Con una caminata continua no hay pasos sueltos: suena la grabacion.
	if _caminata != null:
		return

	var horizontal := Vector2(velocity.x, velocity.z).length()

	# Quieto, en el aire o sin poder caminar: no hay pasos. El proximo
	# arranca a medio tranco, para que el primero no tarde en sonar.
	if horizontal < 0.1 or not is_on_floor() or not puede_mover:
		_recorrido = _tranco() * 0.5
		return

	_recorrido += horizontal * delta
	if _recorrido >= _tranco():
		_recorrido -= _tranco()
		_dar_paso()


# Cuanto se avanza entre un paso y el siguiente. Como una persona: mas
# rapido es pasos mas largos Y mas seguidos. A 2.4 m/s (el parque) son
# unos 2 por segundo; a 5 m/s (la pieza) casi 3.
func _tranco() -> float:
	var cadencia := lerpf(2.0, 2.8, clampf((velocidad - 2.0) / 3.0, 0.0, 1.0))
	return maxf(0.3, velocidad / cadencia)


func _dar_paso() -> void:
	pasos_dados += 1
	if _pasos.is_empty() or _reproductor_pasos == null:
		return

	# Nunca la misma variante dos veces seguidas: es lo que hace que suene
	# a alguien caminando y no a una ametralladora.
	var i := randi() % _pasos.size()
	if _pasos.size() > 1 and i == _ultimo_paso:
		i = (i + 1) % _pasos.size()
	_ultimo_paso = i

	_reproductor_pasos.stream = _pasos[i]
	_reproductor_pasos.volume_db = volumen_pasos + randf_range(-1.5, 1.0)
	Juice.sonar(_reproductor_pasos, 0.0, VARIACION_TONO_PASOS)


# Esta caminando de verdad? Se mira la velocidad real (la de despues de
# move_and_slide) y si la fisica sigue andando: sentado en el banco el
# parque la apaga, y la ultima velocidad queda congelada.
func _esta_caminando() -> bool:
	if not is_physics_processing() or not puede_mover or not is_on_floor():
		return false
	return Vector2(velocity.x, velocity.z).length() >= 0.1


# Sube el volumen al caminar y lo baja al parar. Apagada del todo se PAUSA
# en vez de detenerse: al volver a caminar sigue desde donde quedo, y no
# arranca siempre con el mismo paso.
func _actualizar_caminata(delta: float) -> void:
	if _caminata == null or _reproductor_caminata == null:
		return

	var caminando := _esta_caminando()
	if caminando:
		_ganancia_caminata = minf(1.0, _ganancia_caminata + delta / FUNDIDO_ENTRADA_CAMINATA)
	else:
		_ganancia_caminata = maxf(0.0, _ganancia_caminata - delta / FUNDIDO_SALIDA_CAMINATA)

	if _ganancia_caminata > 0.0:
		# OJO: pausado, "playing" da false. Si se preguntara solo eso, el
		# play() lo reiniciaria desde cero y siempre sonaria el mismo paso.
		if _reproductor_caminata.stream_paused:
			_reproductor_caminata.stream_paused = false
		elif not _reproductor_caminata.playing:
			_reproductor_caminata.play()
		_reproductor_caminata.volume_db = volumen_pasos + linear_to_db(_ganancia_caminata)
	elif _reproductor_caminata.playing and not _reproductor_caminata.stream_paused:
		_reproductor_caminata.stream_paused = true


func _preparar_caminata() -> void:
	_caminata = null
	if caminata_continua != "":
		if ResourceLoader.exists(caminata_continua):
			var sonido = load(caminata_continua)
			if sonido is AudioStreamOggVorbis or sonido is AudioStreamMP3:
				sonido.loop = true
				_caminata = sonido
			else:
				print("[Jugador] la caminata tiene que ser .ogg o .mp3: ", caminata_continua)
		else:
			print("[Jugador] falta la caminata: ", caminata_continua)

	if _reproductor_caminata:
		_reproductor_caminata.stop()
		_reproductor_caminata.stream = _caminata
		_ganancia_caminata = 0.0


# Todos los sonidos de la carpeta. En el juego exportado los archivos
# aparecen como .import / .remap: se les saca el sufijo para encontrarlos.
func _buscar_pasos(carpeta: String) -> Array[AudioStream]:
	var lista: Array[AudioStream] = []
	if carpeta == "":
		return lista
	var dir := DirAccess.open(carpeta)
	if dir == null:
		print("[Jugador] no existe la carpeta de pasos: ", carpeta)
		return lista

	var vistos := {}
	var nombres := Array(dir.get_files())
	nombres.sort()
	for archivo in nombres:
		var nombre: String = archivo
		if nombre.ends_with(".import") or nombre.ends_with(".remap") or nombre.ends_with(".uid"):
			nombre = nombre.get_basename()
		if not nombre.get_extension().to_lower() in ["ogg", "wav", "mp3"]:
			continue
		if vistos.has(nombre):
			continue
		vistos[nombre] = true
		var ruta := carpeta.path_join(nombre)
		if ResourceLoader.exists(ruta):
			var sonido = load(ruta)
			if sonido is AudioStream:
				lista.append(sonido)

	if lista.is_empty():
		print("[Jugador] faltan los sonidos de pasos en ", carpeta)
	return lista


# ============================================================
#  Punto de mira
# ============================================================
#
# Un puntito en el centro para saber a que se esta apuntando. Se agranda
# y se pone blanco cuando hay algo interactuable enfrente, asi el jugador
# sabe que puede apretar E sin tener que leer el cartel.

const MIRA_TAMANO: float = 7.0

func _crear_mira() -> void:
	_estilo_mira = StyleBoxFlat.new()
	_estilo_mira.bg_color = Color(1, 1, 1, 0.45)
	_estilo_mira.corner_radius_top_left = 8
	_estilo_mira.corner_radius_top_right = 8
	_estilo_mira.corner_radius_bottom_right = 8
	_estilo_mira.corner_radius_bottom_left = 8
	_estilo_mira.border_width_left = 1
	_estilo_mira.border_width_top = 1
	_estilo_mira.border_width_right = 1
	_estilo_mira.border_width_bottom = 1
	_estilo_mira.border_color = Color(0, 0, 0, 0.5)

	_mira = Panel.new()
	_mira.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mira.add_theme_stylebox_override("panel", _estilo_mira)
	_mira.set_anchors_preset(Control.PRESET_CENTER)
	_mira.offset_left = -MIRA_TAMANO * 0.5
	_mira.offset_right = MIRA_TAMANO * 0.5
	_mira.offset_top = -MIRA_TAMANO * 0.5
	_mira.offset_bottom = MIRA_TAMANO * 0.5
	_mira.pivot_offset = Vector2(MIRA_TAMANO, MIRA_TAMANO) * 0.5
	$UI.add_child(_mira)


func _mostrar_mira(visible_: bool, sobre_objeto: bool = false) -> void:
	if _mira == null:
		return

	_mira.visible = visible_
	if not visible_:
		return

	if sobre_objeto:
		_estilo_mira.bg_color = Color(1, 1, 1, 0.95)
		_mira.scale = _mira.scale.lerp(Vector2.ONE * 1.6, 0.25)
	else:
		_estilo_mira.bg_color = Color(1, 1, 1, 0.45)
		_mira.scale = _mira.scale.lerp(Vector2.ONE, 0.25)
