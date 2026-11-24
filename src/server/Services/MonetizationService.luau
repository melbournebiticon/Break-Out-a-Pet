--!strict
-- MonetizationService.luau (SERVER)
-- Handles GamePasses, Developer Products (ProcessReceipt with idempotency), and Friend Boost multiplier.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Monetization = require(Shared:WaitForChild("Monetization"))
local NumberFormat = require(Shared:WaitForChild("NumberFormat"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local RateLimiter = require(Shared:WaitForChild("RateLimiter"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))
local InventoryService = require(script.Parent:WaitForChild("InventoryService"))
local StatsService = require(script.Parent:WaitForChild("StatsService"))
local BaseService = require(script.Parent:WaitForChild("BaseService"))
local ClientSyncService = require(script.Parent:WaitForChild("ClientSyncService"))

local MonetizationService = {}

local ownedPasses: { [Player]: { [string]: boolean } } = {}
local friendCounts: { [Player]: number } = {}

local function hasPass(player: Player, key: string): boolean
	local bucket = ownedPasses[player]
	return if bucket and bucket[key] then true else false
end

local function applyPassEffects(player: Player)
	player:SetAttribute("OwnsDoubleMoney", hasPass(player, "DoubleMoney"))
	player:SetAttribute("OwnsVipSpeed", hasPass(player, "VipSpeed"))
	player:SetAttribute("OwnsExtraSlots", hasPass(player, "ExtraSlots"))

	if hasPass(player, "ExtraSlots") then
		local current = InventoryService.GetPetSlots(player)
		local targetMax = Config.MaxPetSlots + Monetization.GamePasses.ExtraSlots.ExtraSlots
		if current < targetMax then
			InventoryService.SetPetSlots(player, math.max(current, Config.StartingPetSlots + Monetization.GamePasses.ExtraSlots.ExtraSlots))
		end
	end

	StatsService.Refresh(player)
	EconomyService.RefreshPlayer(player)
	BaseService.Refresh(player)
end

local function checkPlayerPasses(player: Player)
	local profile = DataService.WaitForProfile(player)
	if not profile or not player.Parent then
		return
	end

	local bucket: { [string]: boolean } = ownedPasses[player] or {}
	ownedPasses[player] = bucket

	for key, passInfo in Monetization.GamePasses do
		if passInfo.Id > 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passInfo.Id)
			end)
			if ok and owns then
				bucket[key] = true
			end
		end
	end

	applyPassEffects(player)
end

local function updateAllFriendBoosts()
	local allPlayers = Players:GetPlayers()
	for _, player in allPlayers do
		local count = 0
		for _, other in allPlayers do
			if other ~= player then
				local ok, isFriend = pcall(function()
					return player:IsFriendsWith(other.UserId)
				end)
				if ok and isFriend then
					count += 1
				end
			end
		end
		count = math.min(count, Config.MaxFriendBoostFriends)
		friendCounts[player] = count
		local pct = math.floor(count * Config.FriendBoostPerFriend * 100 + 0.5)
		player:SetAttribute("FriendBoost", pct)
		EconomyService.RefreshPlayer(player)
	end
end

local function processReceipt(receiptInfo: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local profile = DataService.GetProfile(player)
	if not profile then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local purchaseId = tostring(receiptInfo.PurchaseId)
	for _, existingId in profile.ProcessedReceipts do
		if existingId == purchaseId then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
	end

	local productId = receiptInfo.ProductId
	local granted = false

	if productId > 0 and productId == Monetization.Products.LuckyCage.Id then
		profile.LuckyNextCage = true
		ClientSyncService.Notify(player, "🍀 Lucky Next Cage purchased! Open any cage!", Color3.fromRGB(255, 215, 50))
		granted = true
	elseif productId > 0 and productId == Monetization.Products.MoneyPackSmall.Id then
		local pack = Monetization.Products.MoneyPackSmall
		local amount = math.max(pack.MinAmount, EconomyService.GetIncomePerSec(player) * pack.IncomeSeconds)
		EconomyService.AddMoney(player, amount)
		ClientSyncService.Notify(player, `💰 Received +${NumberFormat.Short(amount)}!`, Color3.fromRGB(100, 255, 130))
		granted = true
	elseif productId > 0 and productId == Monetization.Products.MoneyPackLarge.Id then
		local pack = Monetization.Products.MoneyPackLarge
		local amount = math.max(pack.MinAmount, EconomyService.GetIncomePerSec(player) * pack.IncomeSeconds)
		EconomyService.AddMoney(player, amount)
		ClientSyncService.Notify(player, `💰 Received +${NumberFormat.Short(amount)}!`, Color3.fromRGB(100, 255, 130))
		granted = true
	end

	if not granted then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	table.insert(profile.ProcessedReceipts, purchaseId)
	while #profile.ProcessedReceipts > 50 do
		table.remove(profile.ProcessedReceipts, 1)
	end
	DataService.MarkDirty(player)
	DataService.SavePlayer(player, true)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetizationService.Init()
	InventoryService.SetMaxSlotsGetter(function(player: Player): number
		if hasPass(player, "ExtraSlots") then
			return Config.MaxPetSlots + Monetization.GamePasses.ExtraSlots.ExtraSlots
		end
		return Config.MaxPetSlots
	end)

	EconomyService.AddMultiplierProvider("DoubleMoneyPass", function(player: Player): number
		return if hasPass(player, "DoubleMoney") then Monetization.GamePasses.DoubleMoney.Multiplier else 1
	end)

	EconomyService.AddMultiplierProvider("FriendBoost", function(player: Player): number
		local count = friendCounts[player] or 0
		return 1 + count * Config.FriendBoostPerFriend
	end)

	StatsService.AddSpeedModifier("VipSpeedPass", function(player: Player): number
		return if hasPass(player, "VipSpeed") then Monetization.GamePasses.VipSpeed.SpeedMultiplier else 1
	end)

	MarketplaceService.ProcessReceipt = processReceipt

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, gamePassId: number, wasPurchased: boolean)
		if not wasPurchased or not player then
			return
		end
		for key, info in Monetization.GamePasses do
			if info.Id > 0 and info.Id == gamePassId then
				if not ownedPasses[player] then
					ownedPasses[player] = {}
				end
				ownedPasses[player][key] = true
				applyPassEffects(player)
				ClientSyncService.Notify(player, `🎉 Unlocked {info.Name}!`, Color3.fromRGB(255, 215, 50))
			end
		end
	end)

	local promptEvent = Remotes.GetEvent("PromptPurchase")
	promptEvent.OnServerEvent:Connect(function(player: Player, kind: any, id: any)
		if not RateLimiter.Check(player, "PromptPurchase", 0.5) then
			return
		end
		if typeof(kind) ~= "string" or typeof(id) ~= "number" or id <= 0 then
			return
		end

		if kind == "GamePass" then
			for _, info in Monetization.GamePasses do
				if info.Id == id then
					pcall(function()
						MarketplaceService:PromptGamePassPurchase(player, id)
					end)
					return
				end
			end
		elseif kind == "Product" then
			for _, info in Monetization.Products do
				if info.Id == id then
					pcall(function()
						MarketplaceService:PromptProductPurchase(player, id)
					end)
					return
				end
			end
		end
	end)

	Players.PlayerAdded:Connect(function(player: Player)
		task.spawn(checkPlayerPasses, player)
		task.defer(updateAllFriendBoosts)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(checkPlayerPasses, player)
	end
	task.defer(updateAllFriendBoosts)

	Players.PlayerRemoving:Connect(function(player: Player)
		ownedPasses[player] = nil
		friendCounts[player] = nil
		task.defer(updateAllFriendBoosts)
	end)
end

return MonetizationService
