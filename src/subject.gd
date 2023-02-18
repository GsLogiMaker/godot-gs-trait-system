
@tool
@icon("../assets/entity.svg")
class_name Subject extends Node

var _traits:Dictionary = {}
var _warning_check_timer:= 0.0

func _init():
	child_entered_tree.connect(_on_child_entered_tree)
	child_exiting_tree.connect(_on_child_exiting_tree)


func _process(delta):
	_warning_check_timer += delta
	if _warning_check_timer > 3.0:
		_warning_check_timer = 0
		update_configuration_warnings()
		for trait_slice in _traits.values():
			for trait_object in trait_slice:
				trait_object.update_configuration_warnings()


func _get(property:StringName):
	var trait_get:= func(trait_name:String, index:int, t_property:String):
		var trait_script:= trait_script_from_file_name(trait_name)
		if not trait_script:
			return null
		return _traits[trait_script][index].get(t_property)

	match property.split("/") as Array:
		[&"__add_trait__"]:
			return null
			
		# --- Get for storage ---
		[&"gs_trait", var file_name, var _index]:
			# Save trait
			var trait_script:= trait_script_from_file_name(file_name)
			return trait_script

		[&"gs_trait", var file_name, var index, var property_name]:
			# Save trait property
			return trait_get.call(file_name, index as int, property_name)

		# --- Get for inspector ---

		[var file_name, var index, var property_name]:
			return trait_get.call(file_name, index as int, property_name)

		[var file_name, var property_name]:
			return trait_get.call(file_name, 0, property_name)


func _set(property:StringName, value):
	var file_name:= ""
	var index:= 0
	var property_name:= ""
	match property.split("/") as Array:
		[&"__add_trait__"]:
			if value == null:
				return false
			var new_trait:Trait = (value as Script).new()
			add_trait(new_trait)
		
		# --- Set from storage ---
		[&"gs_trait", var _file_name, var _index]:
			# Load trait
			index = int(_index)
			var trait_script:= value as Script
			if trait_script in _traits and index < _traits[trait_script].size():
				return true
			add_trait(trait_script.new())
			return true
		[&"gs_trait", var _file_name, var _index, var _property_name]:
			# Load trait property
			file_name = _file_name
			index = int(_index)
			property_name = _property_name

		# --- Set from inspector ---
		[var _file_name, var _index, var _property_name]:
			file_name = _file_name
			index = int(_index)
			property_name = _property_name
		[var _file_name, var _property_name]:
			file_name = _file_name
			property_name = _property_name
			
		# --- Other ---
		_:
			return false
	
	# Set trait property
	var trait_script:= trait_script_from_file_name(file_name)
	if not trait_script:
		return false
	_traits[trait_script][index].set(property_name, value)
	return true


func _property_can_revert(property:StringName):
	var trait_name:= ""
	var index:= 0
	var t_property:= ""
	match property.split("/") as Array:
		[var _trait_name, var _t_property]:
			trait_name = _trait_name
			t_property = _t_property
		[var _trait_name, var _index, var _t_property]:
			trait_name = _trait_name
			index = int(_index)
			t_property = _t_property
		_:
			return false

	var trait_script:= trait_script_from_file_name(trait_name)
	if not trait_script:
		return false
		
	var value = _traits[trait_script][0].get(t_property)
	var default = _GsTraitMetadata.get_default_value(self, property)
	return value != default


func _property_get_revert(property:StringName):
	match property.split("/").size():
		2, 3:
			return _GsTraitMetadata.get_default_value(self, property)
		_:
			return null


func _get_property_list() -> Array[Dictionary]:
	var props:Array[Dictionary] = []
	
	props.append({
		name = &"__add_trait__",
		type = TYPE_OBJECT,
		hint = PROPERTY_HINT_RESOURCE_TYPE,
		hint_string = "Script",
		usage = PROPERTY_USAGE_EDITOR,
	})

	# Properties for traits
	for trait_script in _traits:
		if trait_script == null:
			continue

		var trait_name:= FileTool.name_from_path(trait_script.resource_path)
		var i:= 0
		for trait_object in _traits[trait_script]:
#			# Storage for adding a trait to the subject
#			var trait_definition_prop:= {
#				name = &"gs_trait/%s/%s" % [trait_name, i],
#				type = TYPE_OBJECT,
#				hint = PROPERTY_HINT_RESOURCE_TYPE,
#				hint_string = "Script",
#				usage = PROPERTY_USAGE_STORAGE,
#			}
#			props.append(trait_definition_prop)

			var taking_property:= false
			for property in trait_object.get_property_list():
				if property.name == &"Resource":
					taking_property = false
					continue
				if property.name == &"RefCounted":
					taking_property = false
					continue
				if property.name.find(".") != -1:
					taking_property = true
					continue
				if property.name == &"script":
					taking_property = true
				if not taking_property:
					continue

				var base_property_name:= &"%s/%s/%s" % [
					trait_name,
					i,
					property[&"name"],
				]
#				# Create and add storage property
#				var storage_property:= {
#					name = &"gs_trait/%s" % base_property_name,
#					type = property.type,
#					hint = property.hint,
#					hint_string = property.hint_string,
#					usage = PROPERTY_USAGE_STORAGE \
#						if property.usage & PROPERTY_USAGE_STORAGE \
#						else 0,
#				}
#				if _property_can_revert(base_property_name):
#					props.append(storage_property)
				
				# Create and add inspector property
				var inspector_property:= {
					name = &"%s/%s" % [trait_name, property.name] \
						if _traits[trait_script].size() == 1 \
						else &"%s/%s/%s" % [trait_name, i, property.name],
					type = property.type,
					hint = property.hint,
					hint_string = property.hint_string,
					usage = PROPERTY_USAGE_EDITOR \
						if  property.usage & PROPERTY_USAGE_EDITOR \
						else 0,
				}
				if inspector_property.usage != 0:
					props.append(inspector_property)

			i += 1

	return props


func _get_configuration_warnings() -> PackedStringArray:
	var warnings:PackedStringArray = []

	for t in _traits:
		if not t:
			continue

		if not t.is_tool():
			warnings.append(
				"The Trait ```%s``` is not a tool script." % t.resource_path
					+ " Some editor functionality may not work. Consider"
					+ " making the Trait a tool script."

			)
#		else:
#			for trait_object in _traits[t]:
#				# Check traits have all their expected siblings
#				if not trait_object._assert_has_trait():
#					for missing in trait_object._missing_required_traits():
#						warnings.append(
#							trait_object._assert_message_missing_trait(missing),
#						)
#				if not trait_object.has_method(&"_get_configuration_warnings"):
#					continue
#
#				# Check trait specific warnings
#				warnings.append_array(
#					trait_object._get_configuration_warnings()
#				)

	return warnings


## Adds a [Trait] to this subject.
func add_trait(trait_object:Trait) -> void:
	assert(
		trait_object._is_subject_expected_type(self),
		trait_object._message_subject_expected_type(self)
	)

	trait_object.name = StringHelper \
		.name_from_path(trait_object.script.resource_path) \
		.capitalize() \
		.replace(" ", "")
	add_child(trait_object, true, Node.INTERNAL_MODE_BACK)
	if owner:
		trait_object.owner = owner
	else:
		trait_object.owner = self


## Constructs an [Array] of all [Trait]s in this subject.
func all_traits() -> Array[Trait]:
	var all_traits_list:Array[Trait] = []
	for traits_slice in _traits.values():
		all_traits_list.append_array(traits_slice)

	all_traits_list.make_read_only()
	return all_traits_list


func get_trait(trait_script:Script, index:=0) -> Trait:
	var slice = _traits.get(trait_script, [])
	if index >= slice.size():
		return null
	return slice[index]


func trait_script_from_file_name(file_name:String) -> Script:
	for key in _traits:
		if key == null:
			continue
		if FileTool.name_from_path(key.resource_path) == file_name:
			return key

	return null


func remove_trait(trait_object:Trait) -> void:
	assert(trait_object.script in _traits)
	assert(trait_object in _traits[trait_object.script])
	var index:int = _traits[trait_object.script].find(trait_object)
	assert(index != -1)
	remove_trait_at(trait_object.script, index)


## Removes [Trait] with [code]sciprt[/code] at [code]index[/code] from this
## subject.
func remove_trait_at(script:Script, index:=0) -> void:
	var trait_object:Trait = _traits[script].pop_at(index)
	trait_object.get_parent().remove_child(trait_object)
	trait_object.queue_free()


## Like [method get_trait], but errors if a trait with
## [code]trait_script[/code] at [code]index[/code] could not be found.
func secure_trait(trait_script:Script, index:=0) -> Trait:
	assert(
		trait_script in _traits,
		"Subject has no trait with script `%s`. At subject '%s'."
			% [trait_script.resource_path, get_path()]
	)
	assert(
		_traits[trait_script].size() > index,
		"Index out of bounds for subject with trait `%s`. Subject has %s of that trait, but attempted to index at %s."
			% [trait_script.resource_path, _traits[trait_script].size(), index]
	)
	return _traits[trait_script][index]


## Returns an [Array] of [Trait]s with [code]script[/code].
func traits(script:Script) -> Array:
	assert(script in _traits)
	return _traits[script]


# Called when [code]trait_object[/code] is being added to this [Subject].
func _adding_trait(trait_object:Trait):
	if Engine.is_editor_hint():
		_GsTraitMetadata.queue_notify_property_list_changed(self)
	
	if not trait_object.script in _traits:
		# Create a typed array for _traits with this specific script
		_traits[trait_object.script] = Array(
			[],
			TYPE_OBJECT,
			&"Object",
			Trait
		)

	_traits[trait_object.script].append(trait_object)

	trait_object._subject = self
	if not trait_object.script_changed.is_connected(_on_trait_script_changed):
		trait_object.script_changed.connect(_on_trait_script_changed, CONNECT_DEFERRED)


# Called when [code]trait_object[/code] is being removed from this [Subject].
func _removing_trait(trait_object:Trait):
	if Engine.is_editor_hint():
		_GsTraitMetadata.queue_notify_property_list_changed(self)

	_traits[trait_object.script].erase(trait_object)
	if _traits[trait_object.script].size() == 0:
		_traits.erase(trait_object.script)

	assert(trait_object._subject == self or trait_object._subject == null)

	trait_object._subject = null


func _on_child_entered_tree(child:Node):
	if not child is Trait:
		return
	_adding_trait(child)


func _on_child_exiting_tree(child:Node):
	if not child is Trait:
		return
	_removing_trait(child)


func _on_trait_script_changed():
	var all_t:= all_traits()
	_traits = {}

	for trait_object in all_t:
		_removing_trait(trait_object)
	for trait_object in all_t:
		add_trait(trait_object)
