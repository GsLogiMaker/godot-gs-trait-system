
@tool
extends Node

var _default_trait_properties:Dictionary = {}

var _state_names_map:= {}
var _state:SceneState

var _defaults_scene_hold:PackedScene = null
var _defaults_scene_hold_path:= ""
## Records the last time a default value was gotten in msec.
var _last_got_default:= 0

var _notify_property_list_changed_queue:= []

func _ready():
	if not Engine.is_editor_hint():
		set_process(false)


func _process(_delta):
	for subject in _notify_property_list_changed_queue:
		if is_instance_valid(subject):
			subject.notify_property_list_changed()
	_notify_property_list_changed_queue = []

func get_default_value(subject:Subject, property:StringName) -> Variant:
	var trait_name:= &""
	var index:= 0
	var trait_property:= &""
	match property.split("/") as Array:
		[var _trait_name, var _trait_property]:
			trait_name = _trait_name
			index = 0
			trait_property = _trait_property
		[var _trait_name, var _index, var _trait_property]:
			trait_name = _trait_name
			index = _index as int
			trait_property = _trait_property
		["gs_trait", var _trait_name, var _index, var _trait_property]:
			trait_name = _trait_name
			index = _index as int
			trait_property = _trait_property
		_:
			assert(
				false,
				"Invalid subject-trait property syntax: '%s'" % property
			)
	
	var default_value = null
	if subject.owner == null:
		default_value = _default_value_from_trait(subject, trait_name, trait_property)
	else:
		default_value =  _default_value_from_scene(
			subject,
			property,
			trait_name,
			index,
			trait_property,
		)
		_defaults_scene_hold_path = subject.scene_file_path
	
	_last_got_default = Time.get_ticks_msec()
	return default_value


func queue_notify_property_list_changed(subject:Subject):
	if not subject in _notify_property_list_changed_queue:
		_notify_property_list_changed_queue.append(subject)


func _default_value_from_scene(
	subject:Subject,
	property:StringName,
	trait_name:String,
	index:int,
	trait_property:String,
) -> Variant:
	var storage_name:= StringName(
		"gs_trait/%s/%s/%s"%[trait_name, index, trait_property]
	)
	
	if not storage_name in _state_names_map:
		# Fallback to trait default if scene does not have default
		return _default_value_from_trait(subject, trait_name, trait_property)
	
	# get default from scene state
	var default = _state.get_node_property_value(0, _state_names_map[storage_name])
	return default


func _default_value_from_trait(
	subject:Subject,
	trait_name:String,
	trait_property:String,
) -> Variant:
	# Get default value from trait script
	var trait_script:= subject.trait_script_from_file_name(trait_name)
	_default_trait_properties[trait_script.resource_path] \
		= _default_trait_properties.get(trait_script.resource_path, trait_script.new())
	
	# Get default value
	var default_value = _default_trait_properties \
		[trait_script.resource_path].get(trait_property)
	
	# Duplicate if is object
	if (
		default_value and default_value is Object
		and &"duplicate" in default_value and not default_value is Resource
	):
		default_value = default_value.duplicate()
		
	return default_value


func _on_subject_handled(subject:Subject) -> void:
	if subject.scene_file_path != _defaults_scene_hold_path:
		_defaults_scene_hold = load(subject.scene_file_path)
		_defaults_scene_hold_path = subject.scene_file_path
	if not _defaults_scene_hold:
		_state = null
		_state_names_map = {}
		return
		
	_state = _defaults_scene_hold.get_state()
	_state_names_map = {}
	for i in range(_state.get_node_property_count(0)):
		_state_names_map[_state.get_node_property_name(0, i)] = i
	
