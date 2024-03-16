## 2D 横板 Act 控制器。
## 设计目标：
## 提供移动、跳跃、连跳、滑铲、跃下平台、加速砸落、浮空滑翔、攀墙跳跃、攀墙滑落等基础操作。
## 通过调节具体参数、调用预置方法，也能支持诸如加速、飞行、冲刺、闪避等操作。
## 另外提供机器人输入模拟功能，用于动作组合的测试、展示，或 NPC 托管操作。

class_name ActController2D
extends Resource


## 更新浮空变更，参数 'status' 为新状态
signal jumping_update(status: JumpStatus)


## 浮空、飞行、跳跃等竖直方向状态
enum JumpStatus {
	NONE, ## 非浮空状态
	JUMP, ## 升空
	FALL, ## 坠落
	DIVE, ## 砸落、滑铲
	STAY, ## 浮空、滑翔
}
## 冲刺时的控制模式
enum DashMode {
	EMPTY,
	INERT, ## 惰性，允许通过运动抵抗
	STEER, ## 驾驶，允许自由改变方向
	FORCE, ## 强制，固定方向无法抵抗
}


## 手柄序号，-1 则读取键盘（以及未绑定的手柄）输入，0~7 则读取对应序号的输入
@export_range(-1, 7) var joypad_id: int = -1:
	get:
		return joypad_id
	set(id):
		MInput.remove(joypad_id)
		joypad_id = id
		MInput.regist(joypad_id)


## 移动速度，<0 则反向移动
@export var move_speed := 300.0:
	get:
		return move_speed
	set(value):
		move_speed = value
		_calc_auxiliaries()

## 移动后滑动距离，>= 0
@export var move_slide := 0.0:
	get:
		return move_slide
	set(value):
		move_slide = value
		_calc_slide_fric()

## 重力加速度，默认读取项目设置（980）
@export var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

## 跳跃初速度，数组容量对应跳跃次数，各索引的值则为对应次数时的起跳速度
@export var jump_speeds: Array[float] = [400.0, 300.0]
## 冲刺砸落速度，<0 则向上冲刺
@export var dive_speed := 0.0
## 滑翔下坠速度，<0 则升空
@export var glide_speed := 0.0

## 攀墙下坠速度，<0 则爬升
@export var wall_glide := 0.0
## 攀墙跳跃速度，<=0 则向下弹出
@export var wall_speed := 0.0
## 攀墙反弹距离，==0 则不反弹，<=0 则吸附墙壁
@export var wall_repel := 0.0

## 下蹲冲刺距离，==0 则不冲刺，<0 则反方向冲刺
@export var squat_dash := 0.0
## 下蹲冲刺速度，==0 则不冲刺，<0 则反方向冲刺
@export var squat_speed := 0.0

## 当前浮空状态
@export var jumping := JumpStatus.NONE:
	get:
		return _jumping
## 当前冲刺模式
@export var dash_mode: DashMode:
	get:
		return _dash_mode
## 当前方向，!= 0
@export var direction := 1.0:
	get:
		return _direction


#region input map

## 按键映射
@export_subgroup("input map")
## 向上运动
@export var move_up := "ui_up":
	get:
		return _ma(move_up)
## 向下运动
@export var move_down := "ui_down":
	get:
		return _ma(move_down)
## 向左运动
@export var move_left := "ui_left":
	get:
		return _ma(move_left)
## 向右运动
@export var move_right := "ui_right":
	get:
		return _ma(move_right)
## 低速运动
## 将移动速度强制将为 0.5 倍。
## 为键盘操作提供更灵活的控制粒度，
## 若无需此功能，可以设为空字符串。
@export var move_slow := "":
	get:
		return _ma(move_slow)
## 跳跃动作
@export var act_jump := "ui_accept":
	get:
		return _ma(act_jump)

#endregion


# 当前浮空状态
var _jumping := JumpStatus.NONE:
	get:
		return _jumping
	set(value):
		if _jumping == value:
			return
		jumping_update.emit(value)
		_jumping = value

# 当前朝向
var _direction := 1.0

# 当前连续跳跃次数
var _jump_combo := 0

# 冲刺、击飞、反弹等效果计时
var _dash_time := 0.0
# 冲刺、击飞、反弹等效果速度
var _dash_speed := 0.0
# 冲刺控制类型
var _dash_mode := DashMode.EMPTY

# 模拟输入机器人
var _robot: Node # Robot


#region 冲刺、击飞、反弹等效果效果

## 令角色以 'speed' 的速度冲刺 'distance' 的距离。
func dash(distance: float, speed := 0.0, mode := DashMode.INERT):
	if not mode:
		return
	_dash_speed = speed if speed else move_speed * (
		-1 if _direction < 0 else 1
	)
	if not _dash_speed:
		_dash_time = 0
		_dash_mode = DashMode.EMPTY
		return
	if distance < 0:
		_dash_speed = -_dash_speed
	_dash_time = absf(distance / _dash_speed) # s = vt, t = s / v
	_dash_mode = mode

#endregion


#region 机器人模拟输入

## 创建机器人。
## 若 commands 不为空则启动模拟输入，若已创建则将 commands 加入执行队列。
## 需要由调用者自行把返回的节点加入到场景中。
func create_robot(character: CharacterBody2D, commands: Array[String] = []) -> Node: # Robot
	if _robot:
		_robot.start()
		_robot.queue(commands)
		return _robot
	# 延迟加载，避免用不到机器人的场景产生额外开销
	var Robot := load("res://addons/multi_inputer/controller/robot.gd")
	_robot = Robot.new(character)
	_robot.start()
	_robot.queue(commands)
	character.add_child(_robot)
	return _robot

## 关闭机器人，停止模拟输入并释放机器人。
func close_robot():
	if not _robot:
		return
	_robot.close()
	_robot.queue_free()
	_robot = null

## 机器人预设指令
func robot_preset_cmds(target: Node2D) -> Dictionary:
	var x: float = target.position.x
	var y: float = target.position.y
	# 基础运动
	var base: Array[String] = [
		# 原地跳跃
		"t:%s,0.5" % act_jump,
		"t:0.5",
		# 左右移动
		"t:%s,0.5" % move_right,
		"t:%s,0.5" % move_left,
		"t:0.25",
		"t:%s,%s,0.5" % [move_left, move_slow],
		"t:%s,%s,0.5" % [move_right, move_slow],
		"t:0.25",
		# 滑铲移动
		"t:%s,%s,%s,0.2" % [move_right, move_down, act_jump],
		"t:%s,%s,%s,0.3" % [move_left, move_down, act_jump],
		"t:0.25",
		"t:%s,%s,%s,0.2" % [move_left, move_down, act_jump],
		"t:%s,%s,%s,0.3" % [move_right, move_down, act_jump],
		"t:0.5",
		# 二段跳跃
		"t:%s,%s,0.25" % [act_jump, move_left],
		"t:%s,0.25" % move_left,
		"t:%s,%s,0.25" % [act_jump, move_right],
		"t:%s,0.25" % move_right,
		"t:0.25",
	]
	# 高级跳跃
	var adv_jump: Array[String] = [
		# 攀上平台
		"t:%s,0.5" % act_jump,
		"t:0.5",
		# 普通对照
		"t:%s,0.5" % act_jump,
		"t:%s,0.5" % act_jump,
		"t:0.75",
		# 冲刺砸落
		"t:%s,0.5" % act_jump,
		"t:%s,0.5" % act_jump,
		"t:%s,%s,0.55" % [move_down, act_jump],
		# 低速滑翔
		"t:%s,0.5" % act_jump,
		"p:%s" % act_jump,
		"t:1.5",
		"r:%s" % act_jump,
		# 跃下平台
		"t:0.25",
		"t:%s,%s,0.25" % [act_jump,move_down],
		"t:0.5",
	]
	# 攀墙跳跃
	var wall_jump: Array[String] = [
		"t:%s,0.5" % move_right,
		"t:%s,0.5" % act_jump,
		"t:%s,%s,1.0" % [move_right, act_jump],
		"p:%s" % act_jump,
		"t:%s,0.05" % move_right,
		"p:%s" % move_left,
		"t:0.45",
		"r:%s" % act_jump,
		"t:0.25",
		"r:%s" % move_left,
		"t:%s,0.25" % move_right,
		"t:0.25",
		"m:%s,%s" % [x, y],
	]

	return {
		"base": base,
		"adv_jump": adv_jump,
		"wall_jump": wall_jump,
	}

#endregion


# 运动处理

## 处理角色运动
func handle_move(character: CharacterBody2D, delta: float) -> void:
	var direction := Input.get_axis(move_left, move_right)
	var move_slow := move_slow and Input.is_action_pressed(move_slow) # 低速移动
	if move_slow:
		direction /= 2

	# 跳跃处理
	_handle_jump(character, delta, direction)

	# 冲刺处理
	if _handle_dash(character, delta, direction):
		return # 冲刺效果结算中，跳过移动处理

	# 缓停滑行
	if not direction:
		character.velocity.x = move_toward(character.velocity.x, 0, _slide_fric_acc * delta)
		return
	# 移动处理
	var speed_x := direction * move_speed
	character.velocity.x = speed_x * character.scale.x


# 处理角色跳跃
func _handle_jump(character: CharacterBody2D, delta: float, direction: float) -> void:
	var on_floor := character.is_on_floor()

	# 松开跳跃按键
	if not Input.is_action_pressed(act_jump):
		# 接触地面
		if on_floor:
			_jump_combo = 0 # 重置连跳次数
			# 除滑铲以外的状态还原
			if not _dash_mode or _jumping != JumpStatus.DIVE:
				_jumping = JumpStatus.NONE
				if direction:
					_direction = direction
			return
		# 清除上升速度（所以按住按键跳的更高）
		if character.velocity.y < 0:
			character.velocity.y = 0
		# 坠落结算
		_apply_gravity(character, delta)
		if character.velocity.y > 0:
			_jumping = JumpStatus.FALL
		return

	# 按住跳跃键

	var just_jump := Input.is_action_just_pressed(act_jump)

	# 同时按住向下键
	if Input.is_action_pressed(move_down):
		# 浮在空中
		if not on_floor:
			# 加速砸落
			if dive_speed and just_jump:
				_jumping = JumpStatus.DIVE
				if character.velocity.y < dive_speed:
					character.velocity.y = dive_speed * character.scale.y
			_apply_gravity(character, delta)
			return
		_jump_combo = 0 # 重置连跳次数
		# 接触地面，尝试穿过单向平台
		if not direction and not _dash_mode:
			# 冲刺中禁止穿过平台
			if _dash_time > 0:
				return
			_jumping = JumpStatus.NONE
			if just_jump:
				character.position.y += 1
			return
		# 斜向下运动，判定滑铲
		if just_jump and squat_dash and squat_speed:
			_jumping = JumpStatus.DIVE
			_direction = (
				-1 if direction < 0 else 1
			) if direction else (
				-1 if _dash_speed < 0 else 1
			)
			dash(squat_dash, squat_speed * _direction, DashMode.STEER)
			return
		# 处理滑铲结束状态还原
		if not _dash_mode:
			_jumping = JumpStatus.NONE
		if direction:
			_direction = direction
		return

	var on_wall := character.is_on_wall()

	# 持续按着跳跃键
	if not just_jump:
		# 攀墙滑落
		if wall_glide and character.velocity.y >= wall_glide and on_wall:
			_jumping = JumpStatus.FALL
			character.velocity.y = wall_glide * character.scale.y
			return
		# 浮空滑翔
		if glide_speed and character.velocity.y >= glide_speed:
			_jumping = JumpStatus.STAY
			character.velocity.y = glide_speed * character.scale.y
			return

		if not on_floor:
			# 浮在空中
			_apply_gravity(character, delta)
			if character.velocity.y > 0:
				_jumping = JumpStatus.FALL
		elif _dash_mode:
			# 冲刺中接触地面，接触除砸落以外的状态
			if _jumping != JumpStatus.DIVE:
				_jumping = JumpStatus.NONE
		else:
			# 接触地面
			_jumping = JumpStatus.NONE
			# 持续按住跳跃键，或许应该保持朝向
			#if direction:
				#_direction = direction
		return

	# 刚刚按下跳跃按键

	# 接触地面跳跃
	if on_floor:
		_jumping = JumpStatus.JUMP
		_jump_combo = 0 # 重置连跳次数
		character.velocity.y = -jump_speeds[0] * character.scale.y
		if direction:
			_direction = direction
		return

	# 贴着墙壁跳跃
	if direction and on_wall and wall_speed:
		_jumping = JumpStatus.JUMP
		_jump_combo = 0 # 重置连跳次数
		var normal := character.get_wall_normal()
		if normal.x and (normal.x < 0) != (direction < 0):
			dash(wall_repel, move_speed * normal.x)
			character.velocity.y = -wall_speed * character.scale.y
			_direction = direction # 更新方向
			return

	# 空中连续跳跃
	_jump_combo += 1 # 累计连跳次数
	if _jump_combo < jump_speeds.size():
		_jumping = JumpStatus.JUMP
		character.velocity.y = -jump_speeds[_jump_combo] * character.scale.y
		if direction:
			_direction = direction
		return

	# 跳跃次数受限
	_jumping = JumpStatus.JUMP if character.velocity.y < 0 else JumpStatus.FALL

# 应用重力加速度
func _apply_gravity(character: CharacterBody2D, delta: float):
	character.velocity.y += gravity * delta * character.scale.y # v = g * t

# 处理冲刺效果
func _handle_dash(character: CharacterBody2D, delta: float, direction: float) -> bool:
	if _dash_time <= 0 or not _dash_mode:
		return false
	character.velocity.x = _dash_speed * character.scale.x
	_dash_time -= delta
	match _dash_mode:
		# 惰性模式：反方向运动缩短冲刺时长，从而抵消冲刺距离
		DashMode.INERT:
			if direction < 0:
				if (_dash_speed > 0):
					_dash_time += direction * delta
			elif direction > 0:
				if (_dash_speed < 0):
					_dash_time -= direction * delta
		# 驾驶模式：允许随时调转方向
		DashMode.STEER:
			if direction and (direction < 0) == (_dash_speed > 0):
				_dash_speed = -_dash_speed
				_direction = -_direction
		# 强制模式
		#DashMode.FORCE:

	if _dash_time < 0:
		_dash_speed = 0
		_dash_time = 0
		_dash_mode = DashMode.EMPTY
	return true

#endregion


#region 辅助工具

func _ready() -> void:
	_calc_auxiliaries()
	MInput.regist(joypad_id)


# multi-inputer action name
func _ma(action_name: String) -> String:
	if _robot:
		return _robot.action(action_name)
	else:
		return MInput.action(joypad_id, action_name)


# 摩擦制动的加速度
var _slide_fric_acc := 0.0

func _calc_auxiliaries():
	_calc_slide_fric()

func _calc_slide_fric():
	# v = at, s = 0.5at²
	# a = 2s/t² = 2s/(v²/a²) = 2sa²/v²
	# 1 = 2sa / v², a = v² / 2s
	if move_slide <= 0:
		_slide_fric_acc = 5_000_000 # 1000 * 1000 / 2 * 0.1
	else:
		_slide_fric_acc = move_speed * move_speed / (2 * move_slide)

#endregion
