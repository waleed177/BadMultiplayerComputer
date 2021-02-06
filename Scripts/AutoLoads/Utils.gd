extends Node

const TWO_PI = 2*PI

func angle_difference(from: float, to: float) -> float:
	from = fmod(from, TWO_PI)
	to = fmod(to, TWO_PI)
	var difference = to-from
	if difference > PI: difference -= TWO_PI
	if difference < -PI: difference += TWO_PI
	return difference
