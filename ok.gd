extends RigidBody3D

# Sensitivity for mouse/touch movement
@export var sensitivity: float = 0.05  # Adjust based on preference

# Movement speed and friction
@export var move_speed: float = 1200.0
@export var friction: float = 10.0  # Friction applied when no input

# Jump strength
@export var jump_strength: float = 25.0  # Jump velocity
@export var gravity: float = -30.0  # Gravity applied to the character

# Y-axis limits for the camera (up/down)
@export var max_look_angle: float = 90.0
@export var min_look_angle: float = -90.0

# The pivot nodes
@export var pitch_pivot: Node3D
@export var twist_pivot: Node3D

# Mouse look angles
var look_angle_vertical: float = 0.0
var look_angle_horizontal: float = 0.0

var is_mouse_captured: bool = true
var is_grounded: bool = true  # Tracks whether the character is on the ground

# Raycast for ground detection (optional if you want more control)
@export var ground_check_ray_length: float = 1.5  # Length of ray for ground detection
@export var raycast_offset: Vector3 = Vector3(0, -1, 0)  # Offset for ground ray

func _ready() -> void:
	# Capture the mouse when the game starts
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Ensure the pivots are assigned or retrieve them
	if twist_pivot == null:
		twist_pivot = get_node("TwistPivot")  # Adjust the node path if necessary
	if twist_pivot and pitch_pivot == null:
		pitch_pivot = twist_pivot.get_node("PitchPivot")  # Child of TwistPivot
	
	# Check if the pivots exist in the scene
	if pitch_pivot == null:
		print("Error: PitchPivot not found!")
	if twist_pivot == null:
		print("Error: TwistPivot not found!")

func _input(event: InputEvent) -> void:
	# Handle mouse motion for looking around
	if event is InputEventMouseMotion and is_mouse_captured and twist_pivot and pitch_pivot:
		# Horizontal (left/right) movement rotates the TwistPivot (yaw)
		look_angle_horizontal -= event.relative.x * sensitivity
		twist_pivot.rotation_degrees.y = look_angle_horizontal
		
		# Vertical (up/down) movement rotates the PitchPivot (pitch)
		look_angle_vertical = clamp(look_angle_vertical - event.relative.y * sensitivity, min_look_angle, max_look_angle)
		pitch_pivot.rotation_degrees.x = look_angle_vertical
	
	# Handle freeing and capturing the mouse with the ESC key (mapped to 'ui_cancel')
	if Input.is_action_just_pressed("ui_cancel"):
		is_mouse_captured = not is_mouse_captured
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if is_mouse_captured else Input.MOUSE_MODE_VISIBLE)

# Movement logic using _physics_process for more consistent frame rate
func _physics_process(delta: float) -> void:
	var input: Vector3 = Vector3.ZERO
	input.x = Input.get_axis("left", "right")
	input.z = Input.get_axis("forward", "back")
	
	check_if_grounded()  # Check if the player is grounded

	if input != Vector3.ZERO:
		# Calculate movement direction relative to the current yaw of TwistPivot
		var local_direction: Vector3 = Vector3(input.x, 0, input.z)
		
		# Transform the input direction using the twist_pivot's transform to account for its current rotation
		var movement_direction: Vector3 = twist_pivot.transform.basis * local_direction
		movement_direction = movement_direction.normalized() * move_speed
		
		# Apply movement force
		apply_central_force(movement_direction * delta)
	else:
		# Apply friction when no input is detected
		apply_friction(delta)
	
	# Apply gravity
	apply_gravity()

	# Handle jump input
	if Input.is_action_just_pressed("jump") and is_grounded:
		jump()

# Friction reduces velocity over time
func apply_friction(delta: float) -> void:
	# Reduce the linear velocity gradually, based on the friction factor
	var current_velocity: Vector3 = linear_velocity
	var friction_force: Vector3 = -current_velocity * friction * delta
	
	# Apply friction as a force in the opposite direction to the current velocity
	apply_central_force(friction_force)

# Apply gravity to the character
func apply_gravity() -> void:
	if not is_grounded:
		# Apply downward gravity to the character
		apply_central_force(Vector3(0, gravity, 0))

# Jump function
func jump() -> void:
	# Set the vertical velocity directly for the jump
	var vel: Vector3 = linear_velocity
	vel.y = jump_strength  # Set a positive Y velocity for jumping
	linear_velocity = vel  # Assign the new velocity to the character

# Check if the player is on the ground
func check_if_grounded() -> void:
	# Cast a ray downward to check if the player is on the ground
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(global_transform.origin, global_transform.origin + raycast_offset * ground_check_ray_length)
	
	var result = space_state.intersect_ray(query)
	
	is_grounded = result.size() > 0  # True if the ray hits something (ground)
