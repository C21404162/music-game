extends Control

func _ready():
	# Hide the pause menu when the scene starts
	hide()
	# Ensure pause mode is set to process so the menu can work when game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS

func _unhandled_input(event):
	# Toggle pause when Escape is pressed
	if Input.is_action_pressed("esc"):
		toggle_pause()

func toggle_pause():
	# Toggle visibility and pause state
	visible = !visible
	
	if visible:
		# Pause the game
		get_tree().paused = true
		# Capture mouse
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		# Unpause the game
		get_tree().paused = false
		# Return to captured mouse mode
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# Resume button handler
func _on_resume_button_pressed():
	toggle_pause()

# Quit to main menu
func _on_quit_button_pressed():
	# Change to main menu scene (adjust path as needed)
	get_tree().change_scene_to_file("res://menu.tscn")
