## 计算并跟随若干节点的中心位置

extends Node


## 存储中心位置的目标节点
@export var target_node: Node = self
## 追踪中心位置的插值系数
@export var follow_lerp := 0.1
## 追踪中心位置的距离阈值
@export var follow_threshold := 128

## 根据名称自动匹配子节点
@export var match_children := "":
	get:
		return match_children
	set(value):
		match_children = value
		_check_watching()

@export var only_authority := true:
	get:
		return only_authority
	set(value):
		only_authority = value
		_check_watching()


## 纳入坐标计算的节点列表
@export var include_nodes: Array[Node] = []:
	get:
		return include_nodes
	set(value):
		include_nodes = value.filter(_is_valid_node)


## 将节点添加到计算节点列表
func include_node(node: Node, force := false) -> void:
	if not force:
		if only_authority and not node.is_multiplayer_authority():
			return
		if not node.name.match(match_children):
			return
	if not _is_valid_node(node):
		return
	if not node in include_nodes:
		include_nodes.append(node)

## 将节点从计算节点列表移除
func exclude_node(node: Node) -> bool:
	#include_nodes.erase(node)
	var num := include_nodes.size()
	for i in num:
		if node != include_nodes[i]:
			continue
		include_nodes[i] = include_nodes[num - 1]
		include_nodes.pop_back()
		return true
	return false

func _is_valid_node(node: Node) -> bool:
	if node is Camera2D or node is Camera3D:
		return false
	return "position" in node


@onready var _position: Variant = target_node.position

func _physics_process(delta: float) -> void:
	var num := include_nodes.size()
	if num == 0:
		target_node.position = _position
		return
	elif num == 1:
		var node := include_nodes[0]
		_follow(delta, 0, node.position.x)
		_follow(delta, 1, node.position.y)
		if target_node.position is Vector3 and node.position is Vector3:
			_follow(delta, 2, node.position.z)
		return

	var min := Vector3(+INF, +INF, +INF)
	var max := Vector3(-INF, -INF, -INF)
	for node in include_nodes:
		var pos = node.position
		if pos.x < min.x:
			min.x = pos.x
		if max.x < pos.x:
			max.x = pos.x
		if pos.y < min.y:
			min.y = pos.y
		if max.y < pos.y:
			max.y = pos.y
		if pos is Vector3 and max.z < pos.z:
			max.z = pos.z
	_follow(delta, 0, (min.x + max.x) / num)
	_follow(delta, 1, (min.y + max.y) / num)
	if target_node.position is Vector3:
		_follow(delta, 2, (min.z + max.z) / num)

var _buffer_pos := Vector3.ZERO
var _catching := 0

func _follow(delta: float, index: int, target: float):
	var current: float = target_node.position[index]
	var result := target
	var diff := target - current
	var over := absf(diff) / follow_threshold
	var flag := 1 << index

	if over >= 1:
		_catching |= flag
	elif over < 0.01 and (flag & _catching):
		_catching -= flag

	if (flag & _catching):
		result = current + target - _buffer_pos[index]
		# 由于误差，偏移距离可能仍然会加大，超过阈值两倍开始时强制修正
		if over >=2:
			result += diff * delta
	else:
		result = lerpf(current, target, follow_lerp)
	_buffer_pos[index] = target
	target_node.position[index] = result


func _ready() -> void:
	_check_watching()


var _watching := false

func _check_watching() -> void:
	if _watching:
		_clear_watching()
	if not match_children:
		_watching = false
		return
	# start watching
	child_entered_tree.connect(include_node)
	child_exiting_tree.connect(exclude_node)
	_watching = true
	for node in get_children():
		include_node(node)


func _clear_watching() -> void:
	child_entered_tree.disconnect(include_node)
	child_exiting_tree.disconnect(exclude_node)
	var num := include_nodes.size()
	var i := 0
	while i < num:
		var node := include_nodes[i]
		i += 1
		if node.get_parent() != self:
			continue
		num -= 1
		include_nodes[i] = include_nodes[num]
		i -= 1
		include_nodes.pop_back()
