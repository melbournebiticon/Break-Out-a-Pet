--!strict
-- Config.luau
-- Global tuning numbers. Change them here, not inside scripts.

local Config = {
	-- Movement & Carry
	BaseWalkSpeed = 16,
	BaseJumpHeight = 7.2,
	CagePromptHoldSeconds = 0.5,
	CarryHeight = 4.5,
	CageRespawnSeconds = 15,
	DroppedCageReturnSeconds = 3,

	-- Prison Safe Zone & Unlock Timers (seconds on plot before a cage can be opened)
	SafeZoneZ = -48,
	MaxPlotUnlockingCages = 8,
	CageMinSpacingStuds = 5.0,
	CageUnlockSeconds = {
		Common = 5,
		Rare = 8,
		Epic = 12,
		Legendary = 18,
		Mythic = 25,
		Secret = 35,
	} :: { [string]: number },

	-- Base & Economy
	StartingMoney = 0,
	StartingPetSlots = 3,
	MaxPetSlots = 12,
	ExtraPassPetSlots = 2,
	IncomeTickSeconds = 1,

	-- DataStore & Offline Earnings
	DataStoreName = "BreakOutAPet_v1",
	LeaderboardStoreName = "BreakOutAPet_Rescued_v1",
	AutosaveSeconds = 15,
	LoadRetries = 3,
	MaxOfflineSeconds = 10800, -- 3 hours
	OfflineEarningsRate = 0.5,

	-- Traps (Zone 3 Lasers)
	LaserDefaultOnSeconds = 2.5,
	LaserDefaultOffSeconds = 2.0,
	LaserKnockbackSpeed = 45,

	-- Friend Boost
	FriendBoostPerFriend = 0.05,
	MaxFriendBoostFriends = 5,

	-- Steal & Trade
	StealHoldSeconds = 2.0,
	NewPlayerProtectionSeconds = 120,
	AfterRobberyShieldSeconds = 60,
	MaxStealsPerPlayerPerMinute = 3,
	TradeMaxPets = 4,
	TradeConfirmCountdownSeconds = 3,
}

return Config
