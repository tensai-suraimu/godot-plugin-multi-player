#@tool
class_name NodesCenter3D
extends Node3D

@export var nodes: Array[Node3D] = []


func _process(delta: float) -> void:
	var min := Vector3(+INF, +INF, +INF)
	var max := Vector3(-INF, -INF, -INF)
	var num := 0
	for node in nodes:
		if node is Camera3D:
			continue
		var pos := (node as Node3D).position
		if pos.x < min.x:
			min.x = pos.x
		if max.x < pos.x:
			max.x = pos.x
		if pos.y < min.y:
			min.y = pos.y
		if max.y < pos.y:
			max.y = pos.y
		if pos.z < min.z:
			min.z = pos.z
		if max.z < pos.z:
			max.z = pos.z
		num += 1
	if num == 0:
		return
	self.position.x = (min.x + max.x) / num
	self.position.y = (min.y + max.y) / num
	self.position.z = (min.z + max.z) / num
