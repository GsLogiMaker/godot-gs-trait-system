
## Extends functionality of a [Subject].

@tool
@icon("../assets/trait.svg")
class_name Trait extends Node

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

func _enter_tree():
	if not Engine.is_editor_hint():
		if not get_parent() is Subject:
			process_mode = Node.PROCESS_MODE_DISABLED


func _get_configuration_warnings() -> PackedStringArray:
	var warnings:= PackedStringArray()
	
	# Assure parent is a subject
	if not get_parent() is Subject:
		return ["Trait's parent must be a Subject."]
	
	# Check traits have all their expected siblings
	if not _assert_has_trait():
		for missing in _missing_required_traits():
			warnings.append(
				_assert_message_missing_trait(missing),
			)
	
	if not _is_subject_expected_type():
		warnings.append(
			_message_subject_expected_type()
		)
	
	return warnings


## Override this method to customize how what node this trait must be aplied to
## (eg. [CanvasItem] or [Node3D]).
func _get_subject_type():
	return null


## Override this method to customize what [Trait]s are required for a this
## [Trait].
func _get_required_traits() -> Array[Script]:
	return []


# A private function that runs before [method _ready].
func _super_ready() -> void:
	_flags |= TraitFlags.READY
	assert(
		_assert_has_trait()
			or Engine.is_editor_hint(),
		_assert_message_missing_trait(_missing_required_trait()),
	)
	_ready()


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


func _is_subject_expected_type(parent:Node=null) -> bool:
	if parent == null:
		parent = get_parent()
	if _get_subject_type() != null:
		return parent is _get_subject_type()

	return true


func _message_subject_expected_type(parent:Node=null) -> String:
	if not parent:
		parent = get_parent()
	
	var message:String = ""
	if get_script().is_tool() and _get_subject_type() != null:
		var subject_type_node = _get_subject_type().new()
		message += " Expected subject's type to be %s, but is %s." % [
			subject_type_node.get_class(),
			parent.get_class(),
		]
		subject_type_node.free()
	return message


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
