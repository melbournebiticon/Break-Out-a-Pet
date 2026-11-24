--!strict
-- EnemyData.luau
-- All enemy balance numbers and shared AI tuning constants live here.

export type EnemyType = "Warden" | "Dog"

export type EnemyStats = {
	DisplayName: string,
	WalkSpeed: number,
	ChaseSpeed: number,
	BoostAfterSeconds: number,
	BoostMultiplier: number,
	SightRange: number,
	LoseSightSeconds: number,
	CatchDistance: number,
	StunSeconds: number,
	ReChaseCooldownSeconds: number,
	Scale: number,
	BodyColor: Color3,
}

local Enemies: { [string]: EnemyStats } = {
	Warden = {
		DisplayName = "WARDEN",
		WalkSpeed = 13,
		ChaseSpeed = 15,
		BoostAfterSeconds = 4,
		BoostMultiplier = 1.35,
		SightRange = 110,
		LoseSightSeconds = 8,
		CatchDistance = 4.5,
		StunSeconds = 2,
		ReChaseCooldownSeconds = 3,
		Scale = 1.3,
		BodyColor = Color3.fromRGB(25, 45, 110),
	},
	Dog = {
		DisplayName = "GUARD DOG",
		WalkSpeed = 16,
		ChaseSpeed = 22,
		BoostAfterSeconds = 0,
		BoostMultiplier = 1,
		SightRange = 90,
		LoseSightSeconds = 6,
		CatchDistance = 3.5,
		StunSeconds = 2,
		ReChaseCooldownSeconds = 3,
		Scale = 0.6,
		BodyColor = Color3.fromRGB(130, 80, 45),
	},
}

local EnemyData = {
	Enemies = Enemies,

	-- Shared AI / pathfinding tuning
	PathRecomputeSeconds = 0.25,
	WaypointReachDistance = 3,
	PatrolWaitSeconds = 1.0,
	DetectionIntervalSeconds = 0.1,
	TargetMoveThreshold = 4,
	FallResetY = -50,

	-- Pathfinding agent parameters
	AgentRadius = 2,
	AgentHeight = 5,
	AgentCanJump = true,
}

function EnemyData.Get(enemyType: string): EnemyStats?
	return Enemies[enemyType]
end

return EnemyData
