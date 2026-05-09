## Cycles through a list of [Camera2D] nodes, activating one at a time.
## [br][br]
## Assign all cameras you want to switch between to [member cameras].
## The first entry is activated on [method Node._ready]. Call [method next],
## [method previous], or [method switch_to] from code, or use
## [member trigger_next] for a quick in-editor or runtime test.
@tool
extends Node

## The [Camera2D] nodes to cycle through, in order.
## The first entry in the array is activated automatically on ready.
@export var cameras: Array[Camera2D] = []
var current_index: int = 0

## Check this to immediately advance to the next camera. Resets itself to
## [code]false[/code] after firing so it behaves like a button.
## Works both in-editor ([code]@tool[/code]) and at runtime.
@export var trigger_next: bool = false:
	set(v):
		if v:
			trigger_next = false
			next()

func _ready() -> void:
	if cameras.is_empty():
		return
	cameras[current_index].make_current()

## Activates the [Camera2D] at [param index] in [member cameras].
## Out-of-range indices are silently ignored.
func switch_to(index: int) -> void:
	if index < 0 or index >= cameras.size():
		return
	current_index = index
	cameras[current_index].make_current()

## Advances to the next camera in [member cameras], wrapping back to the
## first after the last.
func next() -> void:
	if cameras.is_empty():
		return
	switch_to((current_index + 1) % cameras.size())

## Steps back to the previous camera in [member cameras], wrapping to the
## last after the first.
func previous() -> void:
	if cameras.is_empty():
		return
	switch_to((current_index - 1 + cameras.size()) % cameras.size())
