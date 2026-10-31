extends Node3D

# El cuerpo del jugador. No se ve nunca (la camara esta adentro de la
# cabeza), pero hace SOMBRA, y la sombra tiene que moverse como una persona.
#
# Las animaciones son procedurales: cada frame se calcula la pose a partir
# de lo que esta haciendo el jugador, sin clips.
#   - Quieto: respira, los brazos al costado.
#   - Caminando: piernas y brazos con el ritmo del paso, en cualquier
#     direccion. De costado la cadera gira hacia donde va, y para atras
#     el paso se invierte. Rapido (la pieza va a 5 m/s) trota: codos
#     doblados, mas rodilla y el cuerpo mas inclinado.
#   - Sentado: se sienta solo cuando la camara baja (la silla y el banco
#     ya bajan la camara con un tween). No hace falta avisarle nada.
#   - La cabeza mira para donde mira la camara.
#
# El esqueleto y los pesos los genera tools/hornear_personaje.gd.

# ---- caminar ----
const PASO_CAMINAR := deg_to_rad(28.0)   # cuanto se abre la pierna
const RODILLA_CAMINAR := deg_to_rad(45.0) # cuanto se dobla la que avanza
const BRAZOS_PASO := 0.8                 # el brazo acompana al reves, menos
const REBOTE_CAMINAR := 0.025            # sube y baja la cadera en cada paso
const GIRO_CADERA_MAX := deg_to_rad(55.0)

# ---- trotar ----
# Entre estas velocidades pasa de caminar a trotar.
const TROTE_DESDE := 3.0
const TROTE_HASTA := 4.5
const PASO_TROTE := deg_to_rad(36.0)
const RODILLA_TROTE := deg_to_rad(85.0)
const REBOTE_TROTE := 0.05
const CODO_TROTE := deg_to_rad(80.0)
const INCLINACION_TROTE := deg_to_rad(10.0)

# ---- quieto ----
# Cuanto bajan los brazos, medido desde la horizontal. No del todo:
# separados del cuerpo, asi en la sombra se leen como brazos y no se
# pierden contra el torso.
const BRAZOS_ABAJO := deg_to_rad(73.0)
const CODO_QUIETO := deg_to_rad(12.0)
const RESPIRACION := 0.28                # respiraciones por segundo

# ---- sentado ----
# La camara baja al sentarse: con esta caida ya esta sentado del todo.
const CAIDA_SENTADO := 0.6
const INCLINACION_SENTADO := deg_to_rad(12.0)
const CADERA_MINIMA := 0.6               # el asiento mas bajo (desde el origen)
const BRAZOS_SENTADO := deg_to_rad(26.0) # hacia adelante: la falda o el escritorio
const CODO_SENTADO := deg_to_rad(58.0)

# ---- mirar ----
const MIRAR_ABAJO_MAX := deg_to_rad(65.0)
const MIRAR_ARRIBA_MAX := deg_to_rad(45.0)

@onready var esqueleto: Skeleton3D = $Esqueleto

var _jugador: Node3D
var _camara: Camera3D
var _altura_camara_de_pie: float = 0.0

var _h := {}                # nombre -> indice de hueso
var _rest := {}             # nombre -> posicion de descanso
var _cadera_a_ojos: float = 0.0
var _ojos_a_camara: float = 0.0     # la camara esta mas arriba que los ojos
var _largo_pierna: float = 0.0
var _altura_tobillo: float = 0.0
var _caida_brazo: float = 0.0       # la T-pose del modelo ya baja los brazos

var _pos_anterior: Vector3
var _velocidad := Vector3.ZERO      # en el espacio del cuerpo, suavizada
var _fase: float = 0.0
var _marcha: float = 0.0            # 0 quieto, 1 caminando
var _trote: float = 0.0             # 0 caminando, 1 trotando
var _giro_cadera: float = 0.0
var _sentado: float = 0.0
var _tiempo: float = 0.0


func _ready() -> void:
	_jugador = get_parent() as Node3D
	_camara = _jugador.get_node_or_null("Camera3D") if _jugador else null
	if _camara:
		_altura_camara_de_pie = _camara.position.y
	for i in esqueleto.get_bone_count():
		var nombre := esqueleto.get_bone_name(i)
		_h[nombre] = i
		_rest[nombre] = esqueleto.get_bone_global_rest(i).origin
	var ojos: float = _rest["Cabeza"].y + (_rest["Cabeza"].y - _rest["Cuello"].y) * 1.3
	_cadera_a_ojos = ojos - _rest["Cadera"].y
	_ojos_a_camara = _altura_camara_de_pie - ojos
	_largo_pierna = _rest["Muslo.D"].y - _rest["Pie.D"].y
	_altura_tobillo = _rest["Pie.D"].y
	var brazo: Vector3 = _rest["Antebrazo.D"] - _rest["Brazo.D"]
	_caida_brazo = atan2(-brazo.y, brazo.x)
	_pos_anterior = global_position


func _process(delta: float) -> void:
	if delta <= 0.0 or _jugador == null:
		return
	_tiempo += delta
	_medir_movimiento(delta)
	_posar()


# ============================================================
#  Que esta haciendo el jugador
# ============================================================

func _medir_movimiento(delta: float) -> void:
	# La velocidad se mide por cuanto se movio el cuerpo, no por la del
	# CharacterBody: asi tambien camina si lo mueve un tween.
	var movido := global_position - _pos_anterior
	_pos_anterior = global_position
	var local := global_basis.inverse() * (movido / delta)
	local.y = 0.0
	if local.length() > 20.0:      # un teletransporte (cambio de escena)
		local = Vector3.ZERO
	_velocidad = _velocidad.lerp(local, 1.0 - exp(-12.0 * delta))
	var rapidez := _velocidad.length()

	# Cada paso es medio ciclo: la fase avanza con la DISTANCIA, asi los
	# pies no patinan.
	var paso := _largo_de_paso()
	var hacia_atras := _velocidad.z > 0.3 * rapidez
	_fase = fmod(_fase + (rapidez * delta / paso) * PI * (-1.0 if hacia_atras else 1.0), TAU)
	var objetivo_marcha := clampf(rapidez / 0.8, 0.0, 1.0)
	_marcha = move_toward(_marcha, objetivo_marcha, delta * 4.0)
	var objetivo_trote := smoothstep(TROTE_DESDE, TROTE_HASTA, rapidez)
	_trote = move_toward(_trote, objetivo_trote, delta * 3.0)

	# De costado la cadera gira hacia donde va (sin pasarse de un limite);
	# para atras mira para adelante y el paso va al reves.
	var giro_objetivo := 0.0
	if rapidez > 0.3:
		var d := Vector2(_velocidad.x, _velocidad.z).normalized()
		if hacia_atras:
			d = -d
		giro_objetivo = clampf(atan2(-d.x, -d.y), -GIRO_CADERA_MAX, GIRO_CADERA_MAX)
	_giro_cadera = lerp_angle(_giro_cadera, giro_objetivo, 1.0 - exp(-8.0 * delta))

	# Sentado: cuanto bajo la camara.
	var objetivo_sentado := 0.0
	if _camara:
		objetivo_sentado = clampf((_altura_camara_de_pie - _camara.position.y) / CAIDA_SENTADO, 0.0, 1.0)
	_sentado = lerpf(_sentado, objetivo_sentado, 1.0 - exp(-10.0 * delta))


# Cuanto avanza un paso. Caminando, lo que da la pierna abierta (si se usara
# el tranco de los sonidos, a 2,4 m/s los pies patinarian). Trotando, el
# tranco de los sonidos de pasos: en la pieza el paso y el sonido van juntos.
func _largo_de_paso() -> float:
	var natural := 2.0 * _largo_pierna * sin(PASO_CAMINAR) * 1.1
	var tranco := natural
	if _jugador.has_method("_tranco"):
		tranco = maxf(0.3, _jugador._tranco())
	return lerpf(minf(natural, tranco), tranco, _trote)


# ============================================================
#  La pose
# ============================================================

func _posar() -> void:
	var m := _marcha * (1.0 - _sentado)
	var r := _trote * m
	var paso := _largo_de_paso()
	var paso_maximo := lerpf(PASO_CAMINAR, PASO_TROTE, r)
	var apertura := asin(clampf(paso / (2.0 * _largo_pierna), 0.0, sin(paso_maximo))) * m
	var respiro := sin(_tiempo * TAU * RESPIRACION)

	# La mirada, relativa al cuerpo
	var mirada := Vector2.ZERO   # x: giro, y: arriba/abajo
	if _camara:
		var e := _camara.transform.basis.get_euler()
		mirada = Vector2(wrapf(e.y, -PI, PI), clampf(e.x, -MIRAR_ABAJO_MAX, MIRAR_ARRIBA_MAX))

	# ---- de pie / caminando ----
	var cadera_pie := Vector3(_rest["Cadera"])
	cadera_pie.y += lerpf(REBOTE_CAMINAR, REBOTE_TROTE, r) * m * (0.5 - pow(sin(_fase), 2.0))
	var rot_cadera_pie := Basis(Vector3.UP, _giro_cadera * m) * Basis(Vector3.BACK, sin(_fase) * deg_to_rad(3.0) * m)
	var inclinacion_pie := lerpf(deg_to_rad(4.0), INCLINACION_TROTE, r) * m + deg_to_rad(0.8) * respiro
	var piernas_pie := {}
	for lado in [[".D", 0.0], [".I", PI]]:
		var p: float = _fase + lado[1]
		var muslo := apertura * sin(p)
		var rodilla := -(deg_to_rad(4.0 + 12.0 * r) + lerpf(RODILLA_CAMINAR, RODILLA_TROTE, r) * m * maxf(0.0, cos(p)))
		piernas_pie[lado[0]] = [muslo, rodilla, -(muslo + rodilla)]

	# ---- sentado ----
	var cam_y: float = _camara.position.y if _camara else _altura_camara_de_pie
	var cam_z: float = _camara.position.z if _camara else 0.0
	# Los ojos bajan lo mismo que la camara (que esta mas arriba que ellos)
	var ojos_sentado := cam_y - _ojos_a_camara
	var cadera_sentado := Vector3(0,
		maxf(ojos_sentado - _cadera_a_ojos * cos(INCLINACION_SENTADO), CADERA_MINIMA),
		cam_z + _cadera_a_ojos * sin(INCLINACION_SENTADO))
	# Los muslos van derechos para adelante; las canillas bajan hasta el
	# piso, y si el asiento es bajo se inclinan para adelante.
	var muslo_sentado := deg_to_rad(88.0)
	var rodilla_sentado := _rodilla_hasta_el_piso(cadera_sentado, muslo_sentado)

	# ---- mezcla ----
	var s := _sentado
	esqueleto.set_bone_pose_position(_h["Cadera"], cadera_pie.lerp(cadera_sentado, s))
	_rotar("Cadera", rot_cadera_pie.slerp(Basis(), s))

	# El torso deshace el giro de la cadera: el pecho sigue la mirada
	var torso_giro := -_giro_cadera * m * 0.8
	var inclinacion := lerpf(inclinacion_pie, INCLINACION_SENTADO, s)
	_rotar("Columna", Basis(Vector3.UP, torso_giro) * Basis(Vector3.RIGHT, -inclinacion * 0.6))
	var pecho_giro := mirada.x * 0.25
	var pecho_abajo := minf(0.0, mirada.y) * 0.15
	_rotar("Pecho", Basis(Vector3.UP, pecho_giro) * Basis(Vector3.RIGHT, -inclinacion * 0.4 + pecho_abajo + deg_to_rad(1.2) * respiro))
	# La cabeza compensa la inclinacion del torso y sigue a la camara
	var cuello_giro := mirada.x * 0.3 - _giro_cadera * m * 0.2
	_rotar("Cuello", Basis(Vector3.UP, cuello_giro) * Basis(Vector3.RIGHT, mirada.y * 0.35 + inclinacion * 0.5))
	_rotar("Cabeza", Basis(Vector3.UP, mirada.x * 0.45) * Basis(Vector3.RIGHT, mirada.y * 0.5 + inclinacion * 0.5))

	for lado in [[".D", 1.0, 0.0], [".I", -1.0, PI]]:
		var nombre: String = lado[0]
		var signo: float = lado[1]
		var pp: Array = piernas_pie[nombre]
		_rotar("Muslo" + nombre, Basis(Vector3.RIGHT, lerpf(pp[0], muslo_sentado, s)))
		_rotar("Pierna" + nombre, Basis(Vector3.RIGHT, lerpf(pp[1], rodilla_sentado, s)))
		_rotar("Pie" + nombre, Basis(Vector3.RIGHT, lerpf(pp[2], -(muslo_sentado + rodilla_sentado), s)))

		# El brazo va al reves que la pierna del mismo lado
		var vaiven := -apertura * BRAZOS_PASO * sin(_fase + lado[2])
		var adelante := lerpf(vaiven, BRAZOS_SENTADO, s)
		var abajo := lerpf(BRAZOS_ABAJO + deg_to_rad(1.5) * respiro, BRAZOS_ABAJO - deg_to_rad(10.0), s) - _caida_brazo
		_rotar("Brazo" + nombre, Basis(Vector3.RIGHT, adelante) * Basis(Vector3.BACK, -signo * abajo))
		var codo_pie := lerpf(CODO_QUIETO + maxf(0.0, vaiven) * 0.9, CODO_TROTE, r)
		var codo := lerpf(codo_pie, CODO_SENTADO, s)
		_rotar("Antebrazo" + nombre, Basis(Vector3.UP, signo * codo))
		_rotar("Mano" + nombre, Basis())


# Cuanto se dobla la rodilla para que el tobillo apoye justo en el piso,
# con la cadera en ese lugar y el muslo en ese angulo. Sin canilla
# inclinada (asiento alto) el pie cuelga derecho.
func _rodilla_hasta_el_piso(cadera: Vector3, muslo: float) -> float:
	var rodilla: Vector3 = cadera + (_rest["Muslo.D"] - _rest["Cadera"]) 		+ Basis(Vector3.RIGHT, muslo) * (_rest["Pierna.D"] - _rest["Muslo.D"])
	var canilla: Vector3 = _rest["Pie.D"] - _rest["Pierna.D"]
	var objetivo: float = _altura_tobillo - rodilla.y
	# La canilla, girada "angulo" desde vertical, baja cada vez menos: se
	# busca el angulo que deja el tobillo a la altura de siempre.
	var bajo := 0.0
	var alto := PI * 0.5
	if (Basis(Vector3.RIGHT, bajo) * canilla).y >= objetivo:
		return bajo - muslo
	for i in 20:
		var medio := (bajo + alto) * 0.5
		if (Basis(Vector3.RIGHT, medio) * canilla).y < objetivo:
			bajo = medio
		else:
			alto = medio
	return bajo - muslo


func _rotar(hueso: String, base: Basis) -> void:
	esqueleto.set_bone_pose_rotation(_h[hueso], base.get_rotation_quaternion())
