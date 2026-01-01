@tool
extends EditorPlugin

## Godot Google Sign-In Plugin
## Provides native Android Google authentication using Credential Manager API

func _enter_tree():
	print("GodotGoogleSignIn plugin activated")

func _exit_tree():
	print("GodotGoogleSignIn plugin deactivated")

func _get_plugin_name():
	return "GodotGoogleSignIn"

func _get_plugin_icon():
	return null

