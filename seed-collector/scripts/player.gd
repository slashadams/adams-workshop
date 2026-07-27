extends CharacterBody2D

signal interact_pressed

const SPEED: float = 60.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var step_sound: AudioStreamPlayer = $StepSound

var anim_timer: float = 0.0
var step_timer: float = 0.0
var is_moving: bool = false
var facing_direction: Vector2 = Vector2.DOWN

func _ready() -> void:
	if sprite:
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _physics_process(delta: float) -> void:
	var input_vector: Vector2 = Vector2.ZERO
	
	# WASD / Arrow keys - 4 directional (no diagonals)
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_vector = Vector2.LEFT
	elif Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_vector = Vector2.RIGHT
	elif Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_vector = Vector2.UP
	elif Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_vector = Vector2.DOWN
	
	if input_vector != Vector2.ZERO:
		facing_direction = input_vector
		velocity = input_vector * SPEED
		is_moving = true
	else:
		velocity = Vector2.ZERO
		is_moving = false
	
	move_and_slide()
	_update_animation(delta)
	_play_step_sound(delta)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo():
		if event is InputEventKey:
			var key_event = event as InputEventKey
			if key_event.keycode == KEY_E or key_event.keycode == KEY_SPACE:
				interact_pressed.emit()

func _update_animation(delta: float) -> void:
	if not sprite:
		return
	
	if is_moving:
		anim_timer += delta * 6.0
		if fmod(anim_timer, 2.0) >= 1.0:
			sprite.frame = 1
		else:
			sprite.frame = 0
		
		if facing_direction == Vector2.LEFT:
			sprite.flip_h = true
		elif facing_direction == Vector2.RIGHT:
			sprite.flip_h = false
	else:
		anim_timer = 0.0
		sprite.frame = 0

func _play_step_sound(delta: float) -> void:
	if is_moving:
		step_timer += delta
		if step_timer >= 0.35:
			step_timer = 0.0
			if step_sound and step_sound.stream and not step_sound.playing:
				step_sound.play()
	else:
		step_timer = 0.0
