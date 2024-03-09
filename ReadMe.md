# Multi Player

## Usage:

``` gdscript

var joypad_id: int


func _ready() -> void:
	MInput.regist(joypad_id)


# multi-inputer action name
func _ma(name: String) -> String:
	return MInput.action(joypad_id, name)


func handle():
	var direction := Input.get_axis(_ma("move_left"), _ma("move_right"))
  ...

```

## Preview, Examples & Api:
[issue#1](https://github.com/tensai-suraimu/godot-plugin-multi-player/issues/1)
