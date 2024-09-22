extends BehaviorClass
class_name LockBehaviorClass

@export var unlock : bool = true
@export var lock : int = 0

func do(interactor,sender):
	interactor.set_meta('lock_int',lock)
	if !unlock:
		interactor.interact_icon = "🔒"
