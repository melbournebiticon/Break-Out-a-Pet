--!strict
-- EconomyService.luau (SERVER)
-- Manages player Money, leaderstats.Money, IncomePerSec calculation, 1s income loop, and offline earnings.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local PetData = require(Shared:WaitForChild("PetData"))
local MutationData = require(Shared:WaitForChild("MutationData"))
local NumberFormat = require(Shared:WaitForChild("NumberFormat"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local InventoryService = require(script.Parent:WaitForChild("InventoryService"))
local ClientSyncService = require(script.Parent:WaitForChild("ClientSyncService"))

local EconomyService = {}

local multiplierProviders: { [string]: (Player) -> number } = {}

function EconomyService.AddMultiplierProvider(name: string, fn: (Player) -> number)
	multiplierProviders[name] = fn
end

local function ensureMoneyLeaderstat(player: Player): StringValue
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		stats.Parent = player
	end
	local moneyVal = stats:FindFirstChild("Money")
	if moneyVal and moneyVal:IsA("StringValue") then
		return moneyVal
	end
	local created = Instance.new("StringValue")
	created.Name = "Money"
	created.Value = "0"
	created.Parent = stats
	return created
end

local function syncMoneyDisplay(player: Player)
	local profile = DataService.GetProfile(player)
	if not profile then
		return
	end
	player:SetAttribute("Money", profile.Money)
	local stat = ensureMoneyLeaderstat(player)
	stat.Value = NumberFormat.Short(profile.Money)
end

function EconomyService.GetMoney(player: Player): number
	local profile = DataService.GetProfile(player)
	return if profile then profile.Money else 0
end

function EconomyService.AddMoney(player: Player, amount: number)
	if amount ~= amount or amount == math.huge or amount == -math.huge or amount <= 0 then
		return
	end
	local profile = DataService.GetProfile(player)
	if not profile then
		return
	end
	profile.Money += math.floor(amount)
	DataService.MarkDirty(player)
	syncMoneyDisplay(player)
end

function EconomyService.DirectDeductMoney(player: Player, amount: number): number
	local profile = DataService.GetProfile(player)
	if not profile or amount <= 0 then
		return 0
	end
	local actual = math.min(profile.Money, math.floor(amount))
	if actual > 0 then
		profile.Money -= actual
		DataService.MarkDirty(player)
		syncMoneyDisplay(player)
	end
	return actual
end

function EconomyService.TrySpend(player: Player, amount: number): boolean
	if amount ~= amount or amount == math.huge or amount < 0 then
		return false
	end
	local cost = math.floor(amount)
	local profile = DataService.GetProfile(player)
	if not profile or profile.Money < cost then
		return false
	end
	profile.Money -= cost
	DataService.MarkDirty(player)
	syncMoneyDisplay(player)
	return true
end

function EconomyService.GetIncomeMultiplier(player: Player): number
	local mult = 1
	for _, fn in multiplierProviders do
		local factor = fn(player)
		if typeof(factor) == "number" and factor > 0 then
			mult *= factor
		end
	end
	return mult
end

function EconomyService.GetIncomePerSec(player: Player): number
	local profile = DataService.GetProfile(player)
	if not profile then
		return 0
	end

	local sum = 0
	for _, owned in profile.Pets do
		if (owned.State == "Placed" or owned.Equipped) and not owned.InTransit then
			local info = PetData.Get(owned.PetId)
			if info and info.IncomePerSec > 0 then
				local mutMult = MutationData.GetMultiplier(owned.Mutation)
				sum += info.IncomePerSec * mutMult
			end
		end
	end

	local total = math.floor(sum * EconomyService.GetIncomeMultiplier(player) + 0.5)
	player:SetAttribute("IncomePerSec", total)
	return total
end

function EconomyService.RefreshPlayer(player: Player)
	if not DataService.IsLoaded(player) then
		return
	end
	syncMoneyDisplay(player)
	EconomyService.GetIncomePerSec(player)
end

local function setupPlayer(player: Player)
	local profile = DataService.WaitForProfile(player)
	if not profile or not player.Parent then
		return
	end

	local now = os.time()
	local awaySeconds = math.clamp(now - profile.LastSeen, 0, Config.MaxOfflineSeconds)

	syncMoneyDisplay(player)
	local incomePerSec = EconomyService.GetIncomePerSec(player)

	if awaySeconds >= 10 and incomePerSec > 0 then
		local earned = math.floor(incomePerSec * awaySeconds * Config.OfflineEarningsRate)
		if earned >= 1 then
			EconomyService.AddMoney(player, earned)
			task.delay(1.5, function()
				if player.Parent then
					ClientSyncService.Notify(
						player,
						`Welcome back! You earned ${NumberFormat.Short(earned)} while you were away!`,
						Color3.fromRGB(90, 240, 120)
					)
				end
			end)
		end
	end
	profile.LastSeen = now
end

function EconomyService.Init()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(setupPlayer, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(setupPlayer, player)
	end

	InventoryService.PetsChanged:Connect(function(player: Player)
		EconomyService.GetIncomePerSec(player)
	end)

	-- Single income loop for all players
	task.spawn(function()
		while true do
			task.wait(Config.IncomeTickSeconds)
			for _, player in Players:GetPlayers() do
				if DataService.IsLoaded(player) then
					local rate = EconomyService.GetIncomePerSec(player)
					if rate > 0 then
						EconomyService.AddMoney(player, rate * Config.IncomeTickSeconds)
					end
				end
			end
		end
	end)
end

return EconomyService
