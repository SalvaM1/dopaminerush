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

@onready var camara: Camera3D = $Camera3D
@onready var rayo: RayCast3D = $Camera3D/RayCast3D
@onready var cartel: Label = $UI/CartelInteraccion

var rotacion_vertical: float = 0.0
var rotacion_horizontal_sentado: float = 0.0

var _mira: Panel = null
var _estilo_mira: StyleBoxFlat = null


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# El rayo sale desde adentro de la cápsula del propio jugador,
	# así que le decimos que se ignore a sí mismo.
	rayo.add_exception(self)

	cartel.hide()
	_crear_mira()


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


func _process(_delta: float) -> void:
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
