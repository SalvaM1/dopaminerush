extends Control

# Barra de dopamina. Es la unica pieza de interfaz visible durante toda
# la parte de la computadora.
#
# No sabe nada de las apps ni del resto del juego: solo escucha al GameManager.

@onready var barra: ProgressBar = $ProgressBar

# A partir de que proporcion cambia de color
const UMBRAL_PELIGRO: float = 0.25
const UMBRAL_ALERTA: float = 0.50


func _ready() -> void:
	# Nos suscribimos a las señales. A partir de aca, cada vez que la dopamina
	# cambie, se llama _al_cambiar_dopamina automaticamente.
	GameManager.dopamina_cambio.connect(_al_cambiar_dopamina)
	GameManager.app_desbloqueada.connect(_al_desbloquear_app)

	# Estado inicial
	barra.max_value = GameManager.DOPAMINA_MAX
	barra.value = GameManager.dopamina


func _al_cambiar_dopamina(valor: float, maximo: float) -> void:
	barra.max_value = maximo
	barra.value = valor

	# Feedback visual: cuanto mas baja, mas roja
	var proporcion := valor / maximo
	if proporcion < UMBRAL_PELIGRO:
		barra.modulate = Color(1.0, 0.2, 0.2)      # rojo
	elif proporcion < UMBRAL_ALERTA:
		barra.modulate = Color(1.0, 0.6, 0.1)      # naranja
	else:
		barra.modulate = Color(1.0, 1.0, 1.0)      # normal


func _al_desbloquear_app(_indice: int) -> void:
	# Un golpe visual cuando se desbloquea una app nueva.
	var tween := create_tween()
	tween.tween_property(barra, "scale", Vector2(1.05, 1.3), 0.15)
	tween.tween_property(barra, "scale", Vector2(1.0, 1.0), 0.25)
