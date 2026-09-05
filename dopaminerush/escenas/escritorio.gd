extends CanvasLayer

@onready var reloj: Label = $Reloj

# Cuántos minutos del juego pasan por cada segundo real
const VELOCIDAD_RELOJ: float = 2

var _minutos: float = 8 * 60.0   # arranca a las 08:00


func _ready() -> void:
	GameManager.iniciar_sesion_pc()


func _process(delta: float) -> void:
	_minutos += delta * VELOCIDAD_RELOJ
	var h := int(_minutos / 60.0) % 24
	var m := int(_minutos) % 60
	reloj.text = "%02d:%02d" % [h, m]
