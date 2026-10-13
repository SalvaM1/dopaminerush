extends Node3D

# La hora pertenece al escritorio. Este modulo solo representa esa hora:
# cielo, sol exterior, luz que entra por la ventana y su rebote en la pieza.
@export_range(0.0, 3.0) var intensidad_ventana: float = 1.0
@export_range(0.0, 3.0) var intensidad_rebote: float = 1.0

const ETAPAS: Array[Dictionary] = [
	{"hora": 0.0, "cielo": Color(0.015, 0.025, 0.07), "horizonte": Color(0.045, 0.07, 0.14),
		"color": Color(0.35, 0.46, 0.7), "ambiente": 0.14, "ventana": 0.12, "rebote": 0.05, "sol": 0.0,
		"destino": Vector3(-1.0, 1.1, 1.0)},
	{"hora": 6.0, "cielo": Color(0.3, 0.45, 0.7), "horizonte": Color(1.0, 0.72, 0.5),
		"color": Color(1.0, 0.78, 0.58), "ambiente": 0.55, "ventana": 3.0, "rebote": 0.7, "sol": 0.7,
		"destino": Vector3(-1.0, 1.1, 2.0)},
	{"hora": 8.0, "cielo": Color(0.36, 0.65, 0.95), "horizonte": Color(0.87, 0.93, 1.0),
		"color": Color(1.0, 0.94, 0.82), "ambiente": 0.85, "ventana": 5.0, "rebote": 1.4, "sol": 1.5,
		"destino": Vector3(-1.8, 1.1, 0.5)},
	{"hora": 12.0, "cielo": Color(0.24, 0.55, 0.95), "horizonte": Color(0.79, 0.9, 1.0),
		"color": Color(1.0, 0.98, 0.93), "ambiente": 1.0, "ventana": 6.0, "rebote": 1.8, "sol": 2.0,
		"destino": Vector3(-4.2, 1.1, -3.2)},
	{"hora": 16.0, "cielo": Color(0.35, 0.55, 0.8), "horizonte": Color(1.0, 0.8, 0.57),
		"color": Color(1.0, 0.84, 0.62), "ambiente": 0.75, "ventana": 4.5, "rebote": 1.1, "sol": 1.3,
		"destino": Vector3(0.8, 1.1, -1.0)},
	{"hora": 18.0, "cielo": Color(0.3, 0.3, 0.5), "horizonte": Color(1.0, 0.43, 0.19),
		"color": Color(1.0, 0.52, 0.25), "ambiente": 0.48, "ventana": 2.5, "rebote": 0.6, "sol": 0.6,
		"destino": Vector3(2.5, 1.1, 2.0)},
	{"hora": 20.0, "cielo": Color(0.035, 0.05, 0.14), "horizonte": Color(0.16, 0.12, 0.25),
		"color": Color(0.42, 0.48, 0.72), "ambiente": 0.2, "ventana": 0.25, "rebote": 0.1, "sol": 0.0,
		"destino": Vector3(1.0, 1.1, 1.0)},
	{"hora": 24.0, "cielo": Color(0.015, 0.025, 0.07), "horizonte": Color(0.045, 0.07, 0.14),
		"color": Color(0.35, 0.46, 0.7), "ambiente": 0.14, "ventana": 0.12, "rebote": 0.05, "sol": 0.0,
		"destino": Vector3(-1.0, 1.1, 1.0)},
]

@onready var luz_ventana: SpotLight3D = $LuzVentana
@onready var rebote: OmniLight3D = $ReboteVentana

var _entorno: Environment
var _cielo: ProceduralSkyMaterial
var _sol: DirectionalLight3D
var _vidrio: StandardMaterial3D


func configurar(habitacion: Node3D) -> void:
	# Copias locales: las curvas no modifican recursos de otras escenas.
	var world: WorldEnvironment = habitacion.get_node("WorldEnvironment")
	_entorno = world.environment.duplicate()
	_entorno.sky = world.environment.sky.duplicate()
	_cielo = world.environment.sky.sky_material.duplicate()
	_entorno.sky.sky_material = _cielo
	world.environment = _entorno
	_entorno.ambient_light_sky_contribution = 0.2
	_entorno.tonemap_exposure = 1.0
	_sol = habitacion.get_node("Sol")
	# El antiguo sol azul fijo competia con la luz natural del reloj.
	habitacion.get_node("HabitacionVisual/Iluminacion/LuzDireccionalSuave").light_energy = 0.0
	# El plafon sigue bajo el interruptor; ahora tiene un blanco neutro.
	habitacion.get_node("HabitacionVisual/Iluminacion/LuzGeneralFria").light_color = Color(1.0, 0.94, 0.85)
	var vidrio: CSGBox3D = habitacion.get_node("HabitacionVisual/Ventana/Vidrio")
	_vidrio = vidrio.material.duplicate()
	vidrio.material = _vidrio
	# El cristal deja pasar el sol. Marcos y paredes conservan sus sombras.
	vidrio.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	luz_ventana.global_position = vidrio.global_position + Vector3(0.0, 0.12, -0.4)
	rebote.global_position = vidrio.global_position + Vector3(1.0, 0.2, 3.2)
	habitacion.escritorio.hora_cambio.connect(_actualizar_hora)
	_actualizar_hora(habitacion.escritorio.obtener_minutos_del_dia())


func _actualizar_hora(minutos: float) -> void:
	var hora: float = clampf(minutos / 60.0, 0.0, 24.0)
	var estado := _estado_para_hora(hora)
	var color: Color = estado["color"]
	_cielo.sky_top_color = estado["cielo"]
	_cielo.sky_horizon_color = estado["horizonte"]
	_cielo.ground_horizon_color = color.darkened(0.4)
	_cielo.ground_bottom_color = color.darkened(0.8)
	_cielo.sky_curve = 0.18
	_cielo.sun_angle_max = 8.0
	_entorno.ambient_light_color = color.lerp(Color.WHITE, 0.3)
	_entorno.ambient_light_energy = estado["ambiente"]
	luz_ventana.light_color = color
	luz_ventana.light_energy = float(estado["ventana"]) * intensidad_ventana
	luz_ventana.look_at(estado["destino"], Vector3.UP)
	rebote.light_color = color
	rebote.light_energy = float(estado["rebote"]) * intensidad_rebote
	_sol.light_color = color
	_sol.light_energy = estado["sol"]
	var recorrido: float = clampf((hora - 6.0) / 14.0, 0.0, 1.0) * PI
	var direccion := Vector3(cos(recorrido) * 0.7, -maxf(0.08, sin(recorrido)), 0.8)
	_sol.look_at(_sol.global_position + direccion, Vector3.UP)
	_vidrio.albedo_color = Color(color.r, color.g, color.b, 0.18)


func _estado_para_hora(hora: float) -> Dictionary:
	for i in range(ETAPAS.size() - 1):
		var desde: Dictionary = ETAPAS[i]
		var hasta: Dictionary = ETAPAS[i + 1]
		if hora > float(hasta["hora"]):
			continue
		var peso: float = smoothstep(float(desde["hora"]), float(hasta["hora"]), hora)
		var estado: Dictionary = {}
		for clave in ["cielo", "horizonte", "color"]:
			var color_desde: Color = desde[clave]
			estado[clave] = color_desde.lerp(hasta[clave], peso)
		for clave in ["ambiente", "ventana", "rebote", "sol"]:
			estado[clave] = lerpf(float(desde[clave]), float(hasta[clave]), peso)
		var destino: Vector3 = desde["destino"]
		estado["destino"] = destino.lerp(hasta["destino"], peso)
		return estado
	return ETAPAS[-1].duplicate()
