extends Node3D

# ============================================================
#  Parque
# ============================================================
#
# Es la resolucion de la obra. Todo el juego existe para que este
# momento contraste.
#
# REGLA QUE NO SE ROMPE: aca no hay nada que hacer. Sin barra, sin
# objetivos, sin coleccionables. La unica accion posible es sentarse
# en el banco, y despues de un rato, respirar.
#
# FLUJO:
#   1. El jugador camina libre. El banco dice "Descansar".
#   2. Al usarlo, la camara viaja al banco. Se puede mirar alrededor,
#      pero no caminar. Nada mas responde.
#   3. Despues de ESPERA_RESPIRAR segundos, aparece el cartel de
#      respirar. No antes: hay que quedarse sentado un rato primero.
#   4. Al respirar: sonido de suspiro, fundido a negro, creditos.

const DURACION_SENTARSE: float = 2.2      # mas lento que en la habitacion
const ESPERA_RESPIRAR: float = 8.0        # cuanto tarda en aparecer el cartel
const DURACION_SUSPIRO: float = 2.5       # el fundido final
const LIMITE_GIRO_BANCO: float = 90.0     # se puede mirar mas que en la silla

@onready var jugador: CharacterBody3D = $Jugador
@onready var banco: Interactuable = $Banco
@onready var punto_banco: Marker3D = $Banco/PuntoBanco
@onready var cartel_respirar: Label = $UI/CartelRespirar

# Opcional: si no existe el nodo, funciona igual en silencio.
@onready var sonido_suspiro: AudioStreamPlayer = get_node_or_null("SonidoSuspiro")

var _sentado: bool = false
var _puede_respirar: bool = false
var _terminando: bool = false


func _ready() -> void:
	cartel_respirar.hide()

	# En el parque se camina mas lento. El cuerpo se siente distinto.
	# El camino mide ~82 m, asi que a 2.4 m/s la caminata dura ~35 s.
	# Para alargarla, bajar este numero (a 1.5 son ~55 s).
	jugador.velocidad = 2.4
	# Se puede girar la cabeza casi entera estando sentado
	jugador.set("LIMITE_GIRO_SENTADO", LIMITE_GIRO_BANCO)

	banco.usado.connect(_sentarse)
	_arrancar_ambiente()

	# Venimos de un fundido a blanco desde la habitacion
	await SceneLoader.fundir_desde(2.0)


func _process(_delta: float) -> void:
	if _puede_respirar and not _terminando and Input.is_action_just_pressed("interactuar"):
		_respirar()


# ============================================================
#  Sentarse en el banco
# ============================================================

func _sentarse() -> void:
	if _sentado:
		return
	_sentado = true
	banco.activo = false

	var camara: Camera3D = jugador.camara

	jugador.puede_mover = false
	jugador.puede_mirar = false
	jugador.puede_interactuar = false
	jugador.set_physics_process(false)

	# El cuerpo va al banco, la camara baja a la altura de ojos sentado
	var destino_cuerpo := punto_banco.global_transform
	destino_cuerpo.origin.y = jugador.global_position.y

	var altura: float = punto_banco.global_position.y - jugador.global_position.y
	var destino_camara := Transform3D(Basis(), Vector3(0, altura, 0))

	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(jugador, "global_transform", destino_cuerpo, DURACION_SENTARSE)
	tween.tween_property(camara, "transform", destino_camara, DURACION_SENTARSE)
	await tween.finished

	# Puede girar la cabeza, pero no hay nada que buscar
	jugador.rotacion_vertical = 0.0
	jugador.rotacion_horizontal_sentado = 0.0
	jugador.mirar_sentado = true
	jugador.puede_mirar = true

	# El cartel de respirar no aparece enseguida: primero hay que
	# quedarse un rato sin hacer nada. Ese rato es la obra.
	await get_tree().create_timer(ESPERA_RESPIRAR).timeout

	if _terminando:
		return

	_puede_respirar = true
	cartel_respirar.text = "[E] Tomar aire"
	cartel_respirar.modulate.a = 0.0
	cartel_respirar.show()

	var t := create_tween()
	t.tween_property(cartel_respirar, "modulate:a", 1.0, 1.5)


# ============================================================
#  Respirar y terminar
# ============================================================

func _respirar() -> void:
	_terminando = true
	_puede_respirar = false
	jugador.puede_mirar = false

	var t := create_tween()
	t.tween_property(cartel_respirar, "modulate:a", 0.0, 0.4)

	if sonido_suspiro and sonido_suspiro.stream:
		sonido_suspiro.play()

	await SceneLoader.cambiar_escena("res://escenas/05_creditos/creditos.tscn", Color.BLACK, DURACION_SUSPIRO)


# ============================================================
#  Ambiente sonoro
# ============================================================
#
# Tres capas. En un parque el sonido aporta tanto como la imagen, y es
# donde menos se nota que no hay un artista en el grupo.
# Los archivos van en assets/audio/ambiente/ y tienen que estar en LOOP
# (pestaña Import -> Loop -> Reimport).

const AMBIENTE := {
	"Pajaros": "res://assets/audio/ambiente/pajaros.ogg",
	"Viento":  "res://assets/audio/ambiente/viento.ogg",
	"Agua":    "res://assets/audio/ambiente/agua.ogg",
}

func _arrancar_ambiente() -> void:
	var raiz := get_node_or_null("Sonidos")
	if raiz == null:
		return

	for nombre in AMBIENTE:
		var reproductor = raiz.get_node_or_null(nombre)
		if reproductor == null:
			continue

		if reproductor.stream == null:
			var ruta: String = AMBIENTE[nombre]
			if not ResourceLoader.exists(ruta):
				print("[Parque] falta el ambiente: ", ruta)
				continue
			reproductor.stream = load(ruta)

		# Entran de a poco, no de golpe
		var volumen: float = reproductor.volume_db
		reproductor.volume_db = -60.0
		reproductor.play()
		AudioManager.fundir_entrada(reproductor, 3.5, volumen)
