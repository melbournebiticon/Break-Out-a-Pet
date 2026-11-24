--!strict
-- AbilityData.luau
-- All ability balance numbers live here.

local AbilityData = {
	high_jump = {
		JumpMultiplier = 1.6,
	},
	sprint_boost = {
		SpeedMultiplier = 1.5,
	},
	silent = {
		SightMultiplier = 0.5,
	},
	fast_carry = {
		SlowdownReduction = 0.5,
	},
	invisible = {
		SightMultiplier = 0,
	},
	scare_dogs = {
		IgnoreDogs = true,
	},
	revive = {
		CooldownSeconds = 60,
	},
	freeze_guards = {
		Radius = 40,
	},
	blink = {
		Distance = 18,
	},
	coin_siphon = {
		IntervalSeconds = 20,
		VictimFraction = 0.02,
		MaxIncomeMultiple = 5,
	},
}

return AbilityData
