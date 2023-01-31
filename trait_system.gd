@tool
extends EditorPlugin

const INSPECTOR_PLUGIN:Script = preload("src/inspector_plugin.gd")
const TRAIT_METADATA:Script = preload("src/trait_metadata_singleton.gd")

var inspector_plugin:EditorInspectorPlugin = null

func _init():
	inspector_plugin = INSPECTOR_PLUGIN.new()

func _enter_tree():
	inspector_plugin.undo_redo = get_undo_redo()
	add_inspector_plugin(inspector_plugin)
	add_autoload_singleton("_GsTraitMetadata", TRAIT_METADATA.resource_path)


func _exit_tree():
	remove_inspector_plugin(inspector_plugin)
	remove_autoload_singleton("_GsTraitMetadata")


func _handles(object):
	if object is Subject:
		get_node(^"/root/_GsTraitMetadata")._on_subject_handled(object)
