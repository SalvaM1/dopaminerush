extends CharacterBody3D

# Script del jugador en primera persona.
# No necesita ningún mesh visible: no se ve el cuerpo.

@export var velocidad: float = 5.0
@export var sensibilidad_mouse: float = 0.003
@export var gravedad: float = 9.8
@export var puede_mover: bool = true
@export var puede_mirar: bool = true

@onready var camara: Camera3D = $Camera3D
@onready var rayo: RayCast3D = $Camera3D/RayCast3D
@onready var cartel: Label = $UI/CartelInteraccion

var rotacion_vertical: float = 0.0


func _ready() -> void:
	# Capturamos el mouse para poder "mirar alrededor" como en un juego en primera persona
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# El rayo sale desde adentro de la cápsula del propio jugador,
	# así que le decimos que se ignore a sí mismo.
	rayo.add_exception(self)

	cartel.hide()


func _unhandled_input(event: InputEvent) -> void:
	if not puede_mirar:
		return
	# Mouse look: rotamos el cuerpo en Y (izquierda/derecha) y la cámara en X (arriba/abajo)
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * sensibilidad_mouse)
		rotacion_vertical -= event.relative.y * sensibilidad_mouse
		rotacion_vertical = clamp(rotacion_vertical, deg_to_rad(-80), deg_to_rad(80))
		camara.rotation.x = rotacion_vertical


func _process(_delta: float) -> void:
	if puede_mirar:
		_revisar_interaccion()
	else:
		cartel.hide()


func _revisar_interaccion() -> void:
	var objetivo := rayo.get_collider()

	# ¿Estoy mirando algo que sea interactuable?
	if objetivo is Interactuable:
		cartel.text = "[E] " + objetivo.texto_interaccion
		cartel.show()

		if Input.is_action_just_pressed("interactuar"):
			objetivo.interactuar()
	else:
		cartel.hide()


func _physics_process(delta: float) -> void:
	
	# Gravedad
	if not is_on_floor():
		velocity.y -= gravedad * delta

	# Movimiento WASD relativo hacia dónde estás mirando
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
