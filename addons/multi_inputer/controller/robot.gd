extends Node


# 受控角色
var _target: Node

var _running := 0
var _commands: Array[String] = []
var _cmd_index := 0

var _action_names: Array[StringName] = []


## Get the simulated action name.
## It will returns 'action_name' directly if robot isn't running.
func action(action_name: String) -> String:
	if not _running:
		return action_name
	else:
		return _action(action_name)


## Start the robot
func start() -> void:
	if _running:
		return
	_commands = []
	_cmd_index = 0
	_running = randi()

	_action_names = []
	var action_names: = InputMap.get_actions()
	for name in action_names:
		if name.begins_with("ui_"): # ignore ui actions
			continue
		var new_name := _action(name)
		_action_names.append(new_name)
		InputMap.add_action(new_name)


## Close the robot
func close() -> void:
	for new_name in _action_names:
		InputMap.erase_action(new_name)
	_action_names = []

	_running = 0
	_cmd_index = 0
	_commands = []


## Add simulate commands into commands queue.
## Syntax:
##   m:X,Y,Z            -> move target to [x, y, z]
##   p:A,B,C,...        -> press A,B,C,...
##   r:A,B,C,...        -> release A,B,C,...
##   t:T                -> wait timer for T seconds.
##   t:A,B,C,...,T      -> press ..., wait for Ts, then release.
##   v:I,W,S,D          -> vibrate(i, w, s, d).
##   v:I,W,S            -> vibrate(i, w, s, forever).
##   v:I                -> stop vibrate.
##   clear              -> clear the commands queue.
##   close              -> close the robot.
func queue(commands: Array[String] = []) -> void:
	if _commands:
		_commands.append("clear")
	_commands.append_array(commands)


func _init(target: Node) -> void:
	_target = target

func _action(action_name: String) -> String:
	return "%s_robot%d" % [action_name, _running]


var _waiting := 0.0
var _release: Array[String]


#func _physics_process(delta: float) -> void:
func _process(delta: float) -> void:
	if not _running:
		return
	if _waiting > 0:
		_waiting -= delta
	if _waiting > 0:
		return
	if _release:
		_parse_release(_release)
		_release = []

	while _waiting <= 0 and _cmd_index < _commands.size():
		var cmd := _commands[_cmd_index]
		_cmd_index += 1

		match cmd:
			"clear":
				_parse_clear()
				continue
			"close":
				close()
				return

		if cmd.length() < 2 or cmd[1] != ':':
			continue
		var args := cmd.substr(2).split(",")
		match cmd[0]:
			"m":
				_parse_move(args)
			"p":
				_parse_press(args)
			"r":
				_parse_release(args)
			"t":
				_parse_timer(args)
			"v":
				_parse_vibrate(args)


func _parse_move(args: Array[String]) -> void:
	var x: float = str_to_var(args[0])
	var y: float = str_to_var(args[1])
	if _target is Node2D:
		_target.position = Vector2(x, y)
	elif _target is Node3D:
		var z: float = str_to_var(args[2])
		_target.position = Vector3(x, y, z)

func _parse_press(args: Array[String]) -> void:
	# p:A,B,C,...        -> press A,B,C,...
	for name in args:
		var new_name := _action(name)
		Input.action_press(new_name)

func _parse_release(args: Array[String]) -> void:
	# r:A,B,C,...        -> release A,B,C,...
	for name in args:
		var new_name := _action(name)
		Input.action_release(new_name)

func _parse_timer(args: Array[String]) -> void:
	# t:A,B,C,...,T      -> press ..., wait for Ts, then release.
	var time: float = str_to_var(args[-1])
	if not time:
		return
	_waiting += time
	#_release = args.slice(0, -1) # ???
	_release = []
	for i in args.size() - 1:
		_release.append(args[i])
	_parse_press(_release)

func _parse_vibrate(args: Array[String]) -> void:
	var i: int = str_to_var(args[0]) if args[0] else 0
	if args.size() < 2:
		Input.stop_joy_vibration(i)
		return
	var w: float = str_to_var(args[1]) if args[1] else 0
	var s: float = str_to_var(args[2]) if args[2] else 0
	var d: float = str_to_var(args[3]) if args.size() > 2 and args[3] else 0
	Input.start_joy_vibration(i, w, s, d)

func _parse_clear() -> void:
	# clear              -> clear the commands queue.
	_commands = _commands.slice(_cmd_index)
	_cmd_index = 0
