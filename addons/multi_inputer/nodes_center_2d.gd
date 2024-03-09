#@tool
class_name NodesCenter2D
extends Node2D

@export var nodes: Array[Node2D] = []


func _process(delta: float) -> void:
	var min := Vector2(+INF, +INF)
	var max := Vector2(-INF, -INF)
	var num := 0
	for node in nodes:
		if node is Camera2D:
			continue
		var pos := (node as Node2D).position
		if pos.x < min.x:
			min.x = pos.x
		if max.x < pos.x:
			max.x = pos.x
		if pos.y < min.y:
			min.y = pos.y
		if max.y < pos.y:
			max.y = pos.y
		num += 1
	if num == 0:
		return
	self.position.x = (min.x + max.x) / num
	self.position.y = (min.y + max.y) / num
