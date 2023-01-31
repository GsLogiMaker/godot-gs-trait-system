
@tool
@icon("../assets/entity.svg")
class_name Subject extends Node

var _traits:Dictionary = {}
var _is_ready:= false
var _warning_check_timer:= 0.0

func _init():
	set_process(false)
	set_process_internal(false)
	set_physics_process(false)
	set_physics_process_internal(false)
	set_process_input(false)
	set_process_shortcut_input(false)
	set_process_unhandled_input(false)
	set_process_unhandled_key_input(false)


func _ready():
	_is_ready = true


func _process(delta:float) -> void:
	if Engine.is_editor_hint():
		_warning_check_timer += delta
		if _warning_check_timer > 3.0:
			_warning_check_timer = 0.0
			update_configuration_warnings()

		for slice in _traits.values():
			for trait_object in slice:
				if not trait_object:
					continue
				if not trait_object.script.is_tool():
					continue
				if not trait_object._flags & Trait.TraitFlags.PROCESS:
					continue
					trait_object._process(delta)

	else:
		for slice in _traits.values():
			for trait_object in slice:
				if not trait_object._flags & Trait.TraitFlags.PROCESS:
					continue
				trait_object._process(delta)


func _physics_process(delta:float) -> void:
	if Engine.is_editor_hint():
		for slice in _traits.values():
			for trait_object in slice:
				if not trait_object:
					continue
				if not trait_object.script.is_tool():
					continue
				if not trait_object._flags & Trait.TraitFlags.PHYSICS_PROCESS:
					continue
				trait_object._physics_process(delta)
	else:
		for slice in _traits.values():
			for trait_object in slice:
				if not trait_object._flags & Trait.TraitFlags.PHYSICS_PROCESS:
					continue
				trait_object._physics_process(delta)


func _input(event:InputEvent) -> void:
	for slice in _traits.values():
		for trait_object in slice:
			if trait_object._flags & Trait.TraitFlags.INPUT:
				trait_object._input(event)


func _unhandled_input(event:InputEvent):
	for slice in _traits.values():
		for trait_object in slice:
			if trait_object._flags & Trait.TraitFlags.UNHANDLED_INPUT:
				trait_object._unhandled_input(event)


func _unhandled_key_input(event:InputEvent):
	for slice in _traits.values():
		for trait_object in slice:
			if trait_object._flags & Trait.TraitFlags.UNHANDLED_KEY_INPUT:
				trait_object._unhandled_key_input(event)


func _notification(what:int):
	match what:
		NOTIFICATION_PREDELETE:
			for slice in _traits.values():
				for trait_object in slice:
					if trait_object is Resource:
						continue
					trait_object.free()


func _get(property:StringName):
	var trait_get:= func(trait_name:String, index:int, t_property:String):
		var trait_script:= trait_script_from_file_name(trait_name)
		if not trait_script:
			return null
		return _traits[trait_script][index].get(t_property)

	match property.split("/") as Array:
		# --- Get for storage ---

		[&"gs_trait", var file_name]:
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
	var trait_set:= func(file_name:String, index:int, property_name:String):
		var trait_script:= trait_script_from_file_name(file_name)
		if not trait_script:
			return false

		_traits[trait_script][index].set(property_name, value)
		return true

	match property.split("/") as Array:
		# --- Set from storage ---

		[&"gs_trait", var _file_name]:
			# Load trait
			var trait_script:= value as Script
			add_trait(trait_script.new())

		[&"gs_trait", var file_name, var index, var property_name]:
			# Load trait property
			return trait_set.call(file_name, index as int, property_name)

		# --- Set from inspector ---

		[var file_name, var index, var property_name]:
			return trait_set.call(file_name, index as int, property_name)

		[var file_name, var property_name]:
			return trait_set.call(file_name, 0, property_name)

	return false


func _property_can_revert(property:StringName):
	match property.split("/") as Array:
		[var trait_name, var t_property]:
			var trait_script:= trait_script_from_file_name(trait_name)
			if not trait_script:
				return false
			var value = _traits[trait_script][0].get(t_property)
			var default = _GsTraitMetadata.get_default_value(self, property)
			return value != default

		[var trait_name, var index, var t_property]:
			var trait_script:= trait_script_from_file_name(trait_name)
			if not trait_script:
				return false
			var value = _traits[trait_script][int(index)].get(t_property)
			var default = _GsTraitMetadata.get_default_value(self, property)
			return value != default

	return false


func _property_get_revert(property:StringName):
	match property.split("/") as Array:
		[var trait_name, var t_property]:
			return _GsTraitMetadata.get_default_value(self, property)

		[var trait_name, var index, var t_property]:
			return _GsTraitMetadata.get_default_value(self, property)


func _get_property_list() -> Array[Dictionary]:
	var props:Array[Dictionary] = [
		{
			name = "__add_trait__",
			type = TYPE_INT,
			usage = PROPERTY_USAGE_EDITOR,
		}
	]

	# Storage properters
	for trait_script in _traits:
		if trait_script == null:
			continue

		var trait_name:= FileTool.name_from_path(trait_script.resource_path)
		var i:= 0
		for trait_object in _traits[trait_script]:
			var trait_definition_prop:= {
				name = &"gs_trait/%s" % [trait_name],
				type = TYPE_OBJECT,
				hint = PROPERTY_HINT_RESOURCE_TYPE,
				hint_string = "Script",
				usage = PROPERTY_USAGE_STORAGE,
			}
			props.append(trait_definition_prop)

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
				if not taking_property:
					continue

				# Create and add storage property
				var base_property_name:= &"%s/%s/%s" % [
					trait_name,
					i,
					property[&"name"],
				]
				property.name = &"gs_trait/%s" % base_property_name
				property.usage = PROPERTY_USAGE_STORAGE \
					if property.usage & PROPERTY_USAGE_STORAGE \
					else 0
				if _property_can_revert(base_property_name) or owner == null:
					props.append(property)

			i += 1

	# Inspector properters
	for key in _traits:
		var i:= 0
		for trait_object in _traits[key]:
			if not trait_object:
				continue

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
					# Let 'script' bleed through
					taking_property = true
				if not taking_property:
					continue

				# Create and add inspector property
				var trait_name:= FileTool.name_from_path(
					trait_object.get_script().resource_path
				)
				property.name = "%s/%s" % [trait_name, property.name] \
					if _traits[key].size() == 1 \
					else "%s/%s/%s" % [trait_name, i, property.name]
				property.usage = PROPERTY_USAGE_EDITOR \
					if  property.usage & PROPERTY_USAGE_EDITOR \
					else 0
				if property.usage != 0:
					props.append(property)

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
		else:
			for trait_object in _traits[t]:
				# Check traits have all their expected siblings
				if not trait_object._assert_has_trait():
					for missing in trait_object._missing_required_traits():
						warnings.append(
							trait_object._assert_message_missing_trait(missing),
						)
				# Check trait specific warnings
				warnings.append_array(
					trait_object._get_configuration_warnings()
				)

	return warnings


## Adds a [Trait] to this subject.
func add_trait(trait_object:Trait) -> void:
	assert(
		_assert_matches_trait_type(trait_object),
		_assert_message_matches_trait_type(trait_object)
	)

	if not trait_object.script in _traits:
		# Create a typed array for _traits with this specific script
		_traits[trait_object.script] = Array(
			[],
			TYPE_OBJECT,
			&"Resource",
			Trait
		)

	_adding_trait(trait_object)

	if not trait_object in _traits[trait_object.script]:
		# Only add the trait if it's not already in the array.
		_traits[trait_object.script].append(trait_object)


## Constructs an [Array] of all [Trait]s in this subject.
func all_traits() -> Array[Trait]:
	var all_traits_list:Array[Trait] = []
	for traits_slice in _traits.values():
		all_traits_list.append_array(traits_slice)

	all_traits_list.set_read_only(true)
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
	_removing_trait(trait_object)


## Like [method get_trait], but errors if a trait with
## [code]trait_script[/code] at [code]index[/code] could not be found.
func secure_trait(trait_script:Script, index:=0) -> Trait:
	assert(
		trait_script in _traits,
		"Subject has no trait with script `%s`."
			% [trait_script.resource_path]
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

	if Engine.is_editor_hint() and not trait_object.get_script().is_tool():
		# Trait is not a tool script, bail now to prevent errors in editor
		return
	if trait_object._subject == self:
		# The trait was previously this subject's; no setup needed
		return

	trait_object._subject = self

	trait_object.script_changed.connect(_on_trait_script_changed, CONNECT_DEFERRED)
	tree_entered.connect(trait_object._super_enter_tree)
	ready.connect(trait_object._super_ready)
	tree_exiting.connect(trait_object._super_exit_tree)

	trait_object._super_enter_subject()
	if is_inside_tree():
		trait_object._super_enter_tree()
	if _is_ready:
		trait_object._super_ready()

	if trait_object._flags & Trait.TraitFlags.PROCESS:
		set_process(true)
	if trait_object._flags & Trait.TraitFlags.PHYSICS_PROCESS:
		set_physics_process(true)


# Called when [code]trait_object[/code] is being removed from this [Subject].
func _removing_trait(trait_object:Trait):
	if Engine.is_editor_hint():
		_GsTraitMetadata.queue_notify_property_list_changed(self)

	if Engine.is_editor_hint() and not trait_object.get_script().is_tool():
		# Trait is not a tool script, bail now to prevent errors in editor
		return
	assert(trait_object._subject == self or trait_object._subject == null)

	trait_object._subject = null

	trait_object.script_changed.disconnect(_on_trait_script_changed)
	tree_entered.disconnect(trait_object._super_enter_tree)
	ready.disconnect(trait_object._super_ready)
	tree_exiting.disconnect(trait_object._super_exit_tree)

	trait_object._super_exit_subject()
	if is_inside_tree():
		trait_object._super_exit_tree()


func _assert_matches_trait_type(trait_object:Trait) -> bool:
	if &"_get_subject_type" in trait_object:
		var type = trait_object._get_subject_type()
		if type:
			return self is type

	return true


func _assert_message_matches_trait_type(trait_object:Trait) -> String:
	var message:String = "Could not add trait `%s` to subject `%s`" % [
		trait_object.get_script().resource_path,
		name,
	]
	if trait_object.script.is_tool():
		var subject_type_node = trait_object._get_subject_type().new()
		message += " Expected subject's type to be %s, but is %s." % [
			subject_type_node.get_class(),
			get_class(),
		]
		subject_type_node.free()
	return message


func _on_trait_script_changed():
	var all_t:= all_traits()
	_traits = {}

	for trait_object in all_t:
		_removing_trait(trait_object)
	for trait_object in all_t:
		add_trait(trait_object)
