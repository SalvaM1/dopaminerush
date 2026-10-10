extends Node3D

# ============================================================
#  Parque
# ============================================================
#
# Es la resolucion de la obra. Todo el juego existe para que este
# momento contraste.
#
# REGLA QUE NO SE ROMPE: aca no hay nada que HACER. Sin objetivos, sin
# coleccionables, sin nada que apretar. La unica accion posible es
# sentarse en el banco, y despues de un rato, respirar.
#
# LA BARRA DE DOPAMINA SI ESTA, Y ES LA MISMA DEL ESCRITORIO.
# Llegas con ella en CERO y sube sola, lentisima, mientras caminas sin
# hacer nada. Es el unico lugar del juego donde sube sin que toques
# nada: ninguna app, ningun gesto, ninguna recompensa variable. Solo
# estar afuera.
#
# Que sea la MISMA barra es lo importante. Durante toda la partida fue
# el medidor de cuanto te queda antes de caerte; aca, sin cambiar de
# forma ni de color, pasa a medir cuanto te vas recuperando. El juego no
# necesita decirlo: lo dice la barra que ya aprendiste a leer.
#
# FLUJO:
#   1. Llegas con la barra en 0. El jugador camina libre y la barra sube
#      de a RECUPERACION_LENTA por segundo, hasta TOPE_CAMINANDO.
#   2. El banco dice "Descansar". Al usarlo, la camara viaja ahi.
#   3. Despues de ESPERA_RESPIRAR segundos aparece el cartel de respirar.
#      No antes: hay que quedarse sentado un rato primero.
#   4. Al respirar, la barra sube hasta 100 en DURACION_RESPIRO.
#   5. Llena, se queda ESPERA_FINAL segundos en silencio.
#   6. Recien ahi funde a negro y arrancan los creditos.

const DURACION_SENTARSE: float = 2.2      # mas lento que en la habitacion
const ESPERA_RESPIRAR: float = 8.0        # cuanto tarda en aparecer el cartel
const DURACION_SUSPIRO: float = 2.5       # el fundido final
const LIMITE_GIRO_BANCO: float = 90.0     # se puede mirar mas que en la silla

# ---- LA RECUPERACION ----
# Lentisima a proposito. Despues de una partida entera donde la barra
# subia de a 20 por click, verla moverse asi cuesta: es justamente la
# diferencia de escala entre lo que te daban las apps y lo que da estar
# afuera. Y el punto es que lo de afuera no se agota.
const RECUPERACION_LENTA: float = 0.7     # por segundo, caminando

# El mundo solo te devuelve una parte. El resto lo pone la respiracion,
# que es lo unico que el jugador elige hacer. Sin este tope, alguien que
# se quedara diez minutos dando vueltas llegaria al banco con la barra
# llena y el gesto final no tendria nada que completar.
const TOPE_CAMINANDO: float = 45.0

const DURACION_RESPIRO: float = 4.5       # lo que tarda en llegar a 100
const ESPERA_FINAL: float = 6.0           # el silencio con la barra llena

@onready var jugador: CharacterBody3D = $Jugador
@onready var banco: Interactuable = $Banco
@onready var punto_banco: Marker3D = $Banco/PuntoBanco
@onready var cartel_respirar: Label = $UI/CartelRespirar

# Opcional: si no existe el nodo, funciona igual en silencio.
@onready var sonido_suspiro: AudioStreamPlayer = get_node_or_null("SonidoSuspiro")

var _sentado: bool = false
var _puede_respirar: bool = false
var _terminando: bool = false
var _dopamina: float = 0.0
var _respirando: bool = false


func _ready() -> void:
	cartel_respirar.hide()

	# Llega vacia. GameManager.activo quedo en false despues del colapso,
	# asi que nada la drena: desde aca la manejamos nosotros.
	_dopamina = 0.0
	_empujar_dopamina()

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


func _process(delta: float) -> void:
	# Sube sola mientras no estes respirando. No hace falta caminar ni
	# mirar nada: sube por estar.
	if not _respirando and _dopamina < TOPE_CAMINANDO:
		_dopamina = min(TOPE_CAMINANDO, _dopamina + RECUPERACION_LENTA * delta)
		_empujar_dopamina()

	if _puede_respirar and not _terminando and Input.is_action_just_pressed("interactuar"):
		_respirar()


# La barra del escritorio escucha a GameManager, asi que no hay que
# tocarla: alcanza con mover el numero y avisar.
func _empujar_dopamina() -> void:
	GameManager.dopamina = _dopamina
	GameManager.dopamina_cambio.emit(_dopamina, GameManager.DOPAMINA_MAX)


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
	_respirando = true
	_puede_respirar = false
	jugador.puede_mirar = false

	var t := create_tween()
	t.tween_property(cartel_respirar, "modulate:a", 0.0, 0.4)

	if sonido_suspiro and sonido_suspiro.stream:
		sonido_suspiro.play()

	# La barra termina de llenarse. Mas rapido que caminando, pero
	# todavia lento: es una respiracion, no un premio.
	var llenado := create_tween()
	llenado.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	llenado.tween_method(
		func(v: float) -> void:
			_dopamina = v
			_empujar_dopamina(),
		_dopamina, GameManager.DOPAMINA_MAX, DURACION_RESPIRO
	)
	await llenado.finished

	# Y recien ahi, el silencio. Seis segundos con la barra llena y nada
	# que hacer: es la primera vez en toda la partida que el jugador
	# tiene la barra al tope y ninguna app pidiendole algo. Ese vacio es
	# el final de la obra, no el fundido.
	await get_tree().create_timer(ESPERA_FINAL).timeout

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
