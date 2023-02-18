
extends EditorInspectorPlugin

const ADD_TRAIT_WIDGET = preload("../scenes/add_trait_widget.tscn")
const DELETE_BUTTON = preload("../scenes/delete_trait_button.tscn")

var last_group:= ""
var undo_redo:EditorUndoRedoManager

var target_subject:Subject = null
var target_trait_script:Script = null
var target_trait_index:= -1
var target_trait:Trait = null

func _can_handle(object:Variant):
	return object is Subject


func _parse_category(object, category):
	object = object as Subject
	
	if category != &"subject.gd":
		return
		
	var sc:= EditorResourcePicker.new()
	sc.base_type = "Trait"
	sc.size_flags_horizontal |= Control.SIZE_EXPAND
	sc.resource_changed.connect(_on_add_trait.bind(object, sc))
	
	var add_widget:= ADD_TRAIT_WIDGET.instantiate()
	add_widget.get_node(^"%Container").add_child(sc)
	
	add_custom_control(add_widget)
	

func _parse_group(object:Object, group:String):
	var segments:= group.split("/")
	var index:int = 0 if segments.size() < 2 else int(segments[1])
	for key in object._traits:
		if not key:
			continue
			
		var trait_name = FileTool.name_from_path(key.resource_path)
		
		if segments[0] == trait_name:
			var delete_button_depth:= 2
			if object._traits[key].size() == 1:
				delete_button_depth = 1
			else:
				if segments[1] == "0" and group != last_group:
					continue
			if segments.size() != delete_button_depth:
				continue
			var delete_button:= DELETE_BUTTON.instantiate()
			delete_button.get_node(^"%Button").pressed.connect(
				_on_remove_trait_pressed.bind(
					object,
					object.trait_script_from_file_name(trait_name),
					index,
				)
			)
			add_custom_control(delete_button)
		
	last_group = group

func _parse_property(
	object:Object,
	type,
	name:String,
	hint_type,
	hint_string:String,
	usage_flags,
	wide:bool,
):
	# Remove inspector editor for property
	return name == "_"


func _do_add_trait():
	target_subject.add_trait(target_trait)


func _do_remove_trait():
	target_subject.remove_trait_at(target_trait_script, target_trait_index)


func _undo_add_trait():
	target_subject.remove_trait(target_trait)


func _undo_remove_trait():
	target_subject.add_trait(target_trait)


# NOTE: The order of the parameters of this function is important
func _on_add_trait(
	trait_object:Trait, subject:Subject, rp:EditorResourcePicker,
):
	rp.edited_resource = null
	
	undo_redo.create_action("Add Trait", 0, subject)
	
	if (Trait as Script).get_instance_base_type() != &"Resource":
		undo_redo.add_do_reference(trait_object)
	undo_redo.add_do_property(self, &"target_subject", subject)
	undo_redo.add_do_property(self, &"target_trait", trait_object)
	undo_redo.add_do_method(self, &"_do_add_trait")
	
	undo_redo.add_undo_property(self, &"target_subject", subject)
	undo_redo.add_undo_property(self, &"target_trait", trait_object)
	undo_redo.add_undo_method(self, &"_undo_add_trait")
	undo_redo.commit_action()


func _on_remove_trait_pressed(subject:Subject, trait_script:Script, index:int):
	undo_redo.create_action("Remove Trait", 0, subject)
	
	undo_redo.add_do_property(self, &"target_subject", subject)
	undo_redo.add_do_property(self, &"target_trait_script", trait_script)
	undo_redo.add_do_property(self, &"target_trait_index", index)
	undo_redo.add_do_method(self, &"_do_remove_trait")
	
	var removed_trait:Trait = subject.secure_trait(trait_script, index)
	undo_redo.add_undo_reference(removed_trait)
	undo_redo.add_undo_property(self, &"target_subject", subject)
	undo_redo.add_undo_property(self, &"target_trait", removed_trait)
	undo_redo.add_undo_method(self, &"_undo_remove_trait")

	undo_redo.commit_action()
	
