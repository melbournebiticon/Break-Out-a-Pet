--!strict
-- AbilityService.luau (SERVER)
-- Implements passive and active pet abilities:
-- high_jump, sprint_boost, silent, fast_carry, invisible, scare_dogs, revive, freeze_guards, blink, random_ability, coin_siphon.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AbilityData = require(Shared:WaitForChild("AbilityData"))
local PetData = require(Shared:WaitForChild("PetData"))
local NumberFormat = require(Shared:WaitForChild("NumberFormat"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local RateLimiter = require(Shared:WaitForChild("RateLimiter"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local InventoryService = require(script.Parent:WaitForChild("InventoryService"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))
local StatsService = require(script.Parent:WaitForChild("StatsService"))
local CageService = require(script.Parent:WaitForChild("CageService"))
local EnemyService = require(script.Parent:WaitForChild("EnemyService"))
local ClientSyncService = require(script.Parent:WaitForChild("ClientSyncService"))

local AbilityService = {}

local activeEffectId: { [Player]: string } = {}
local reviveReadyAt: { [Player]: number } = {}
local rng = Random.new()

local function getEquippedAbility(player: Player): PetData.Ability?
	local equipped = InventoryService.GetEquipped(player)
	if not equipped then
		return nil
	end
	local info = PetData.Get(equipped.PetId)
	return if info then info.Ability else nil
end

local function isAbilityActive(player: Player): boolean
	local activeUntil = player:GetAttribute("AbilityActiveUntil")
	if typeof(activeUntil) == "number" then
		return workspace:GetServerTimeNow() < activeUntil
	end
	return false
end

local function getCurrentActiveId(player: Player): string?
	if not isAbilityActive(player) then
		return nil
	end
	return activeEffectId[player]
end

function AbilityService.GetSightMultiplier(player: Player, enemyType: string?): number
	local ability = getEquippedAbility(player)
	local activeId = getCurrentActiveId(player)

	if activeId == "invisible" then
		return AbilityData.invisible.SightMultiplier
	end
	if ability then
		if ability.AbilityId == "scare_dogs" and enemyType == "Dog" then
			return 0
		end
		if ability.AbilityId == "silent" then
			return AbilityData.silent.SightMultiplier
		end
	end
	return 1
end

local function getJumpModifier(player: Player): number
	local ability = getEquippedAbility(player)
	if ability and ability.AbilityId == "high_jump" then
		return AbilityData.high_jump.JumpMultiplier
	end
	return 1
end

local function getSpeedModifier(player: Player): number
	local mult = 1
	local ability = getEquippedAbility(player)
	local activeId = getCurrentActiveId(player)

	if activeId == "sprint_boost" then
		mult *= AbilityData.sprint_boost.SpeedMultiplier
	end

	if ability and ability.AbilityId == "fast_carry" and CageService.IsCarrying(player) then
		local carryMult = CageService.GetCarryMultiplier(player)
		if carryMult > 0 and carryMult < 1 then
			local reduced = 1 - (1 - carryMult) * (1 - AbilityData.fast_carry.SlowdownReduction)
			mult *= (reduced / carryMult)
		end
	end

	return mult
end

local function tryInterceptCatch(player: Player): boolean
	local ability = getEquippedAbility(player)
	if not ability or ability.AbilityId ~= "revive" then
		return false
	end
	local now = workspace:GetServerTimeNow()
	local readyAt = reviveReadyAt[player] or 0
	if now < readyAt then
		return false
	end

	reviveReadyAt[player] = now + AbilityData.revive.CooldownSeconds
	player:SetAttribute("AbilityReadyAt", reviveReadyAt[player])
	ClientSyncService.Notify(player, "🔥 Phoenix Revive saved your cage!", Color3.fromRGB(255, 165, 40))
	return true
end

local function executeActiveAbility(player: Player)
	if not DataService.IsLoaded(player) then
		return
	end
	local ability = getEquippedAbility(player)
	if not ability or ability.Duration <= 0 then
		return
	end

	local now = workspace:GetServerTimeNow()
	local readyAtAttr = player:GetAttribute("AbilityReadyAt")
	local readyAt = if typeof(readyAtAttr) == "number" then readyAtAttr else 0
	if now < readyAt then
		return
	end

	local effectId = ability.AbilityId
	if effectId == "random_ability" then
		local pool = { "sprint_boost", "invisible", "freeze_guards", "blink" }
		effectId = pool[rng:NextInteger(1, #pool)]
	end

	activeEffectId[player] = effectId
	player:SetAttribute("AbilityActiveUntil", now + ability.Duration)
	player:SetAttribute("AbilityReadyAt", now + ability.Cooldown)

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")

	if effectId == "freeze_guards" and root and root:IsA("BasePart") then
		local count = EnemyService.FreezeNearby(root.Position, AbilityData.freeze_guards.Radius, ability.Duration)
		ClientSyncService.Notify(player, `❄️ Froze {count} guard(s)!`, Color3.fromRGB(100, 220, 255))
	elseif effectId == "blink" and character and root and root:IsA("BasePart") then
		local look = root.CFrame.LookVector
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character }
		local hit = workspace:Raycast(root.Position, look * AbilityData.blink.Distance, params)
		local dist = if hit then math.max(0, (hit.Position - root.Position).Magnitude - 2) else AbilityData.blink.Distance
		character:PivotTo(root.CFrame + look * dist)
	end

	StatsService.Refresh(player)
	task.delay(ability.Duration, function()
		if player.Parent then
			StatsService.Refresh(player)
		end
	end)
end

function AbilityService.Init()
	StatsService.AddJumpModifier("AbilityJump", getJumpModifier)
	StatsService.AddSpeedModifier("AbilitySpeed", getSpeedModifier)
	EnemyService.SetSightMultiplierGetter(AbilityService.GetSightMultiplier)
	CageService.SetCatchInterceptor(tryInterceptCatch)

	InventoryService.PetsChanged:Connect(function(player: Player)
		activeEffectId[player] = nil
		player:SetAttribute("AbilityActiveUntil", 0)
		StatsService.Refresh(player)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		activeEffectId[player] = nil
		reviveReadyAt[player] = nil
	end)

	local useEvent = Remotes.GetEvent("UseAbility")
	useEvent.OnServerEvent:Connect(function(player: Player)
		if not RateLimiter.Check(player, "UseAbility", 0.25) then
			return
		end
		executeActiveAbility(player)
	end)

	-- Passive Octopus coin_siphon loop
	task.spawn(function()
		while true do
			task.wait(AbilityData.coin_siphon.IntervalSeconds)
			local allPlayers = Players:GetPlayers()
			if #allPlayers >= 2 then
				for _, owner in allPlayers do
					local ability = getEquippedAbility(owner)
					if ability and ability.AbilityId == "coin_siphon" then
						local victims: { Player } = {}
						for _, other in allPlayers do
							if other ~= owner and EconomyService.GetMoney(other) >= 50 then
								table.insert(victims, other)
							end
						end
						if #victims > 0 then
							local victim = victims[rng:NextInteger(1, #victims)]
							local rawAmount = math.floor(EconomyService.GetMoney(victim) * AbilityData.coin_siphon.VictimFraction)
							local cap = math.max(100, EconomyService.GetIncomePerSec(owner) * AbilityData.coin_siphon.MaxIncomeMultiple)
							local siphon = math.clamp(rawAmount, 1, cap)
							local taken = EconomyService.DirectDeductMoney(victim, siphon)
							if taken > 0 then
								EconomyService.AddMoney(owner, taken)
								ClientSyncService.Notify(owner, `🐙 Octopus siphoned ${NumberFormat.Short(taken)} from {victim.DisplayName}!`, Color3.fromRGB(180, 110, 255))
								ClientSyncService.Notify(victim, `🐙 {owner.DisplayName}'s Octopus siphoned ${NumberFormat.Short(taken)}!`, Color3.fromRGB(255, 140, 90))
							end
						end
					end
				end
			end
		end
	end)
end

return AbilityService
