extends Node


signal regist_joypad(id: int)
signal remove_joypad(id: int)

const MAX_JOYPAD_ID = 15

var _reg_flag: int = 0


## Get the next usable joypad id
func usable() -> int:
	var flag := 1
	for id in MAX_JOYPAD_ID + 1:
		if _reg_flag & flag == 0:
			return id
		flag <<= 1
	return -1


## Get the standalone action name of 'joypad_id'.
## It will returns 'action_name' directly if 'joypad_id' has not been registered.
func action(joypad_id: int, action_name: String) -> String:
	if joypad_id < 0 or joypad_id > MAX_JOYPAD_ID:
		return action_name
	var flag := 1 << joypad_id
	if _reg_flag & flag == 0:
		return action_name
	return _action(joypad_id, action_name)


## Register a joypad as a standalone device.
## ‘joypad_id' should between [0, 7]
## Returns false if register failed.
func regist(joypad_id: int) -> bool:
	if joypad_id < 0 or joypad_id > MAX_JOYPAD_ID:
		return false
	var flag := 1 << joypad_id
	if _reg_flag & flag != 0:
		return false
	if _reg_flag == 0:
		_prepare()
	_reg_flag |= flag
	_regist(joypad_id)
	return true


## Remove the registered joypad.
## ‘joypad_id' should between [0, 7]
## Returns false if remove failed.
func remove(joypad_id: int) -> bool:
	if joypad_id < 0 or joypad_id > MAX_JOYPAD_ID:
		return false
	var flag := 1 << joypad_id
	if _reg_flag & flag == 0:
		return false
	_remove(joypad_id)
	_reg_flag -= flag
	if _reg_flag == 0:
		_restore()
	return true


## Remmove all registered joypads.
func remove_all() -> void:
	for id in MAX_JOYPAD_ID + 1:
		if _reg_flag & 0b1 != 0:
			_remove(id)
		_reg_flag >>= 1
	_reg_flag = 0
	_restore()


#region implements

func _action(id: int, name: String) -> String:
	return "m_%s_%02d" % [name, id]


var _action_names: Array[StringName] = []

func _prepare() -> void:
	var action_names: = InputMap.get_actions()
	for name in action_names:
		if name.begins_with("ui_"): # ignore ui actions
			continue
		var events := InputMap.action_get_events(name)
		for event in events:
			if _is_joypad_event(event):
				event.device = (2 << MAX_JOYPAD_ID) - 1
		_action_names.append(name)

func _restore() -> void:
	for name in _action_names:
		var events := InputMap.action_get_events(name)
		for event in events:
			if _is_joypad_event(event):
				event.device = -1
	_action_names = []


func _regist(id: int) -> void:
	for name in _action_names:
		var new_name := _action(id, name)
		InputMap.add_action(new_name)
		var events := InputMap.action_get_events(name)
		for event in events:
			if _is_joypad_event(event):
				var new_event := event.duplicate()
				new_event.device = id
				InputMap.action_add_event(new_name, new_event)
	regist_joypad.emit(id)

func _remove(id: int) -> void:
	for name in _action_names:
		var new_name := _action(id, name)
		InputMap.erase_action(new_name)
	remove_joypad.emit(id)


func _is_joypad_event(event: InputEvent) -> bool:
	return event is InputEventJoypadButton or event is InputEventJoypadMotion

#endregion
