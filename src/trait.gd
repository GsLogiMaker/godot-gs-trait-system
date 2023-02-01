
## Extends functionality of a [Subject].

@tool
@icon("../assets/trait.svg")
class_name Trait extends Resource

signal tree_entered

enum TraitFlags {
	PROCESS = 1 << 0,
	PROCESS_INTERNAL = 1 << 1,
	PHYSICS_PROCESS = 1 << 2,
	PHYSICS_PROCESS_INTERNAL = 1 << 3,
	
	INPUT = 1 << 4,
	SHORTCUT_INPUT = 1 << 5,
	UNHANDLED_INPUT = 1 << 6,
	UNHANDLED_KEY_INPUT = 1 << 7,
	
	ADDED = 1 << 8,
	IN_TREE = 1 << 9,
	READY = 1 << 10,
	
	NONE = 0,
}

var _subject:Node = null
var _flags:int = TraitFlags.NONE

## An virtual function that is called when the [Trait] is added to a
## [Subject].
func _enter_subject() -> void:
	pass


## An virtual function that is called when the [Trait] is removed from a
## [Subject].
func _exit_subject() -> void:
	pass


## Called when [method subject] enters the SceneTree or when the trait is
## added to [method subject] if [method subject] is already in tree
## (See [method Node._enter_tree]).
func _enter_tree() -> void:
	pass


## Called when [method subject] is about to leave the SceneTree
## (see [method Node._exit_tree])
func _exit_tree() -> void:
	pass


## Called when the [method subject] is "ready" (See [method Node._ready]).
func _ready() -> void:
	pass


## Called during the processing step of the main loop
## (See [method Node._process]).
func _process(delta:float) -> void:
	pass


## Called during the physics processing step of the main loop
## (See [method Node._process]).
func _physics_process(delta:float) -> void:
	pass


## Called when there is an input event (See [method Node._input]).
func _input(event:InputEvent) -> void:
	pass


## Called when an [InputEventKey] or [InputEventShortcut] hasn't been consumed
## by [method _input] or any GUI Control item
## (See [method Node._shortcut_input]).
func _shortcut_input(event:InputEvent) -> void:
	pass


## Called when an [InputEvent] hasn't been consumed by [member _input] or any
## GUI Control item (See [method Node._unhandled_input]).
func _unhandled_input(event:InputEvent) -> void:
	pass


## Called when an [InputEventKey] hasn't been consumed by [member _input] or
## any GUI Control item (See [method Node._unhandled_key_input]).
func _unhandled_key_input(event:InputEventKey):
	pass


## The elements in the array returned from this method are displayed as
## warnings in the Scene dock (See Node._get_configuration_warnings).
func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray([])


## Override this method to customize how what node this trait must be aplied to
## (eg. [CanvasItem] or [Node3D]).
func _get_subject_type():
	return Node


## Override this method to customize what [Trait]s are required for a this
## [Trait].
func _get_required_traits() -> Array[Script]:
	return []


# A private function that runs before [method _enter_subject].
func _super_enter_subject() -> void:
	_flags |= TraitFlags.ADDED
	_enter_subject()


# A private function that runs before [method _exit_subject].
func _super_exit_subject() -> void:
	_flags |= TraitFlags.ADDED
	_exit_subject()


# A private function that runs before [method _enter_tree].
func _super_enter_tree() -> void:
	_flags |= TraitFlags.IN_TREE
	_enter_tree()
	tree_entered.emit()


# A private function that runs before [method _exit_tree].
func _super_exit_tree() -> void:
	_flags = _flags & ~TraitFlags.ADDED
	_flags = _flags & ~TraitFlags.IN_TREE
	_exit_tree()


# A private function that runs before [method _ready].
func _super_ready() -> void:
	_flags |= TraitFlags.READY
	assert(
		_assert_has_trait()
			or Engine.is_editor_hint(),
		_assert_message_missing_trait(_missing_required_trait()),
	)
	_ready()


## Fetches a node relative to this trait's [Subject]
## 	[br] This is a wrapper around [method Node.get_node].
func get_node(path:NodePath) -> Node:
	return _subject.get_node(path)


## Returns [code]true[/code] if this trait's [Subject] is in the scene tree.
func is_inside_tree() -> bool:
	return (_flags & TraitFlags.IN_TREE) != 0


## Returns [code]true[/code] if processing is enabled
## (see [method set_process]).
func is_processing() -> bool:
	return (_flags & TraitFlags.PROCESS) as bool


## Returns [code]true[/code] if internal processing is enabled
## (see [method set_process_internal]).
func is_processing_internal() -> bool:
	return (_flags & TraitFlags.PROCESS_INTERNAL) as bool


## Returns [code]true[/code] if physics processing is enabled
## (see [method set_physics_process]).
func is_physics_processing() -> bool:
	return (_flags & TraitFlags.PHYSICS_PROCESS) as bool


## Returns [code]true[/code] if internal physics processing is enabled
## (see [method set_physics_process_internal]).
func is_physics_processing_internal() -> bool:
	return (_flags & TraitFlags.PHYSICS_PROCESS_INTERNAL) as bool


## Returns [code]true[/code] if input processing is enabled
## (see [method set_process_input]).
func is_processing_input() -> bool:
	return (_flags & TraitFlags.INPUT) as bool


## Returns [code]true[/code] if shortcut input processing is enabled
## (see [method set_process_shortcut_input]).
func is_processing_shortcut_input() -> bool:
	return (_flags & TraitFlags.SHORTCUT_INPUT) as bool


## Returns [code]true[/code] if unhandled input processing is enabled
## (see [method set_process_unhandled_input]).
func is_processing_unhandled_input() -> bool:
	return (_flags & TraitFlags.UNHANDLED_INPUT) as bool


## Returns [code]true[/code] if unhandled key input processing is enabled
## (see [method set_process_unhandled_key_input]).
func is_processing_unhandled_key_input() -> bool:
	return (_flags & TraitFlags.UNHANDLED_KEY_INPUT) as bool


## Enables or disables processing.
func set_process(enable:bool) -> void:
	if enable:
		_flags |= TraitFlags.PROCESS
		if _subject:
			_subject.set_process(_flags & TraitFlags.PROCESS)
	else:
		_flags = _flags & ~TraitFlags.PROCESS


## Enables or disabled internal processing for this trait.
func set_process_internal(enable:bool) -> void:
	if enable:
		_flags |= TraitFlags.PROCESS_INTERNAL
		if _subject:
			_subject.set_process_internal(_flags & TraitFlags.PROCESS_INTERNAL)
	else:
		_flags = _flags & ~TraitFlags.PROCESS_INTERNAL


## Enables or disables physics (i.e. fixed framerate) processing.
func set_physics_process(enable:bool) -> void:
	if enable:
		_flags |= TraitFlags.PHYSICS_PROCESS
		if _subject:
			_subject.set_physics_process(_flags & TraitFlags.PHYSICS_PROCESS)
	else:
		_flags = _flags & ~TraitFlags.PHYSICS_PROCESS


## Enables or disables internal physics for this trait.
func set_physics_process_internal(enable:bool) -> void:
	if enable:
		_flags |= TraitFlags.PHYSICS_PROCESS_INTERNAL
		if _subject:
			_subject.set_physics_process_internal(_flags & TraitFlags.PHYSICS_PROCESS_INTERNAL)
	else:
		_flags = _flags & ~TraitFlags.PHYSICS_PROCESS_INTERNAL


## Enables or disables input processing.
func set_process_input(enable:bool) -> void:
	if enable:
		_flags |= TraitFlags.INPUT
		if _subject:
			_subject.set_process_input(_flags & TraitFlags.INPUT)
	else:
		_flags = _flags & ~TraitFlags.INPUT


## Enables or disables shortcut processing.
func set_process_shortcut_input(enable:bool) -> void:
	if enable:
		_flags |= TraitFlags.SHORTCUT_INPUT
		if _subject:
			_subject.set_process_shortcut_input(_flags & TraitFlags.SHORTCUT_INPUT)
	else:
		_flags = _flags & ~TraitFlags.SHORTCUT_INPUT


## Enables or disables unhandled input processing.
func set_process_unhandled_input(enable:bool) -> void:
	if enable:
		_flags |= TraitFlags.UNHANDLED_INPUT
		if _subject:
			_subject.set_process_unhandled_input(_flags & TraitFlags.UNHANDLED_INPUT)
	else:
		_flags = _flags & ~TraitFlags.UNHANDLED_INPUT


## Enables unhandled key input processing.
func set_process_unhandled_key_input(enable:bool) -> void:
	if enable:
		_flags |= TraitFlags.UNHANDLED_KEY_INPUT
		if _subject:
			_subject.set_process_unhandled_key_input(_flags & TraitFlags.UNHANDLED_KEY_INPUT)
	else:
		_flags = _flags & ~TraitFlags.UNHANDLED_KEY_INPUT


## Returns the [Subject] that this [Trait] is applied to.
func subject():
	return _subject


func _assert_has_trait() -> bool:
	var trait_types = _get_required_traits()
	if trait_types == null:
		return true
		
	for t_type in trait_types:
		if _subject and not t_type in _subject._traits:
			return false
			
	return true


func _assert_message_missing_trait(missing:Script) -> String:
	if not missing:
		return ""
	return "The trait `%s` requires subject to have the trait `%s`." % [
		get_script().resource_path,
		missing.resource_path,
	]


func _missing_required_trait():
	var missing = _missing_required_traits()
	if missing.size() != 0:
		return missing[0]
	return null


func _missing_required_traits() -> Array[Script]:
	var trait_types = _get_required_traits()
	var missing:Array[Script] = []
	
	if trait_types == null:
		return []
	
	for t_type in trait_types:
		if _subject and not t_type in _subject._traits:
			missing.append(t_type)
			
	return missing
