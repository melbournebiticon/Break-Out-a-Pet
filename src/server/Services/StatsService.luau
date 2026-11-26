--!strict
-- StatsService.luau (SERVER)
-- The ONLY place that sets a player's Humanoid.WalkSpeed and JumpHeight.
-- Drives the interactive "Takbuhan Treadmill" speed training loop and Slow Mode toggle.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local ShopData = require(Shared:WaitForChild("ShopData"))
local NumberFormat = require(Shared:WaitForChild("NumberFormat"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local RateLimiter = require(Shared:WaitForChild("RateLimiter"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))
local ClientSyncService = require(script.Parent:WaitForChild("ClientSyncService"))

local StatsService = {}

local speedModifiers: { [string]: (Player) -> number } = {}
local jumpModifiers: { [string]: (Player) -> number } = {}
local consoleSetupDone: { [Instance]: boolean } = {}

function StatsService.UpdatePlotTreadmillVisuals(player: Player)
	local plots = workspace:FindFirstChild("BasePlots")
	if not plots then
		return
	end
	local tier = StatsService.GetSpeedLevel(player)
	local tierInfo = ShopData.GetTreadmillTierInfo(tier)
	local gain = ShopData.GetTrainerGainPerSec(tier)
	local price = ShopData.GetSpeedPrice(tier)
	local color = tierInfo.AccentColor

	for _, plot in plots:GetChildren() do
		if plot:IsA("Model") and plot:GetAttribute("OwnerUserId") == player.UserId then
			local tm = plot:FindFirstChild("PlotTreadmill")
			if tm then
				tm:SetAttribute("TreadmillTier", tier)
				tm:SetAttribute("BeltSpeed", tierInfo.RunSpeed)

				local platform = tm:FindFirstChild("Platform")
				if platform and platform:IsA("BasePart") then
					platform.Color = tierInfo.PlatformColor
					platform.Material = tierInfo.PlatformMat
				end

				local belt = tm:FindFirstChild("TreadmillBelt")
				if belt and belt:IsA("BasePart") then
					belt.Color = tierInfo.BeltColor
				end

				for _, railName in { "RailL", "RailR" } do
					local rail = tm:FindFirstChild(railName)
					if rail and rail:IsA("BasePart") then
						rail.Color = tierInfo.RailColor
						rail.Material = tierInfo.RailMat
					end
				end

				for _, part in tm:GetChildren() do
					if part:IsA("BasePart") then
						if string.find(part.Name, "Strip") then
							part.Color = color
						elseif part.Name == "TierAddon_SideGlowL" or part.Name == "TierAddon_SideGlowR" then
							part.Color = color
							part.Transparency = if tier >= 1 then 0 else 1
						elseif part.Name == "TierAddon_ArchL" or part.Name == "TierAddon_ArchR" then
							part.Color = tierInfo.RailColor
							part.Transparency = if tier >= 3 then 0 else 1
						elseif part.Name == "TierAddon_ArchTop" then
							part.Color = color
							part.Transparency = if tier >= 3 then 0 else 1
						elseif part.Name == "TierAddon_TurboL" or part.Name == "TierAddon_TurboR" then
							part.Color = color
							part.Transparency = if tier >= 5 then 0 else 1
						elseif part.Name == "TierAddon_WingL" or part.Name == "TierAddon_WingR" then
							part.Color = color
							part.Transparency = if tier >= 8 then 0.1 else 1
						end
					end
				end

				local sign = tm:FindFirstChild("TreadmillSign")
				if sign then
					for _, child in sign:GetChildren() do
						if child:IsA("SurfaceGui") then
							local bg = child:FindFirstChildOfClass("Frame")
							if bg then
								local labels = {}
								for _, l in bg:GetChildren() do
									if l:IsA("TextLabel") then
										table.insert(labels, l)
									end
								end
								if labels[1] then
									labels[1].Text = `🏃 {tierInfo.Name} (Tier {tier})`
									labels[1].TextColor3 = color
								end
								if labels[2] then
									local upText = if price then `Upgrade: {NumberFormat.Short(price)}` else "MAX TIER!"
									labels[2].Text = `+{NumberFormat.Short(gain)} Speed/sec • {upText}`
								end
							end
						end
					end
				end
				local console = tm:FindFirstChild("TreadmillConsole")
				local prompt = console and console:FindFirstChildOfClass("ProximityPrompt")
				if prompt then
					prompt.ActionText = if price
						then `Upgrade Treadmill ({NumberFormat.Short(price)})`
						else "Max Tier Reached"
					prompt.ObjectText = `{tierInfo.Name} • Tier {tier} (+{NumberFormat.Short(gain)} Speed/s)`
				end
			end
		end
	end
end

function StatsService.AddSpeedModifier(name: string, fn: (Player) -> number)
	speedModifiers[name] = fn
end

function StatsService.AddJumpModifier(name: string, fn: (Player) -> number)
	jumpModifiers[name] = fn
end

function StatsService.GetSpeedLevel(player: Player): number
	local profile = DataService.GetProfile(player)
	return if profile then profile.SpeedLevel else 0
end

function StatsService.GetTrainedSpeed(player: Player): number
	local profile = DataService.GetProfile(player)
	return if profile then profile.TrainedSpeed else 0
end

function StatsService.AddTrainedSpeed(player: Player, delta: number)
	local profile = DataService.GetProfile(player)
	if not profile or delta <= 0 then
		return
	end
	profile.TrainedSpeed = math.clamp(math.floor((profile.TrainedSpeed + delta) * 100 + 0.5) / 100, 0, 999999999999)
	player:SetAttribute("TrainedSpeed", profile.TrainedSpeed)
	DataService.MarkDirty(player)
	StatsService.Refresh(player)
end

function StatsService.SetSpeedLevel(player: Player, level: number)
	local profile = DataService.GetProfile(player)
	if not profile then
		return
	end
	profile.SpeedLevel = math.clamp(math.floor(level), 0, ShopData.Speed.MaxLevel)
	player:SetAttribute("SpeedLevel", profile.SpeedLevel)
	DataService.MarkDirty(player)
	StatsService.Refresh(player)
	StatsService.UpdatePlotTreadmillVisuals(player)
end

function StatsService.GetTotalSpeedStat(player: Player): number
	return Config.BaseWalkSpeed + StatsService.GetTrainedSpeed(player)
end

function StatsService.GetBaseWalkSpeed(player: Player): number
	local totalStat = StatsService.GetTotalSpeedStat(player)
	player:SetAttribute("TotalSpeedStat", totalStat)
	return ShopData.StatToPhysicalWalkSpeed(totalStat)
end

function StatsService.Refresh(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local speedMult = 1
	for _, fn in speedModifiers do
		local m = fn(player)
		if typeof(m) == "number" and m > 0 then
			speedMult *= m
		end
	end

	if player:GetAttribute("SlowMode") == true then
		speedMult *= 0.55
	end

	local jumpMult = 1
	for _, fn in jumpModifiers do
		local m = fn(player)
		if typeof(m) == "number" and m > 0 then
			jumpMult *= m
		end
	end

	local finalWalkSpeed = StatsService.GetBaseWalkSpeed(player) * speedMult
	player:SetAttribute("ActualWalkSpeed", finalWalkSpeed)
	humanoid.WalkSpeed = finalWalkSpeed
	humanoid.UseJumpPower = false
	humanoid.JumpHeight = Config.BaseJumpHeight * jumpMult
end

local function isStandingOnOwnTreadmill(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
		return false
	end

	for _, pad in CollectionService:GetTagged("TreadmillPad") do
		if pad:IsA("BasePart") then
			local plot = pad:FindFirstAncestorOfClass("Model")
			local plotRoot = if plot and plot.Name == "PlotTreadmill" then plot.Parent else plot
			if not plotRoot or not plotRoot:IsA("Model") or plotRoot:GetAttribute("OwnerUserId") == player.UserId then
				local dx = math.abs(root.Position.X - pad.Position.X)
				local dz = math.abs(root.Position.Z - pad.Position.Z)
				local dy = root.Position.Y - pad.Position.Y
				if dx <= pad.Size.X * 0.5 + 1.2 and dz <= pad.Size.Z * 0.5 + 1.2 and dy >= 0 and dy <= 7 then
					return true
				end
			end
		end
	end
	return false
end

local function setupTreadmillConsole(instance: Instance)
	if consoleSetupDone[instance] or not instance:IsA("BasePart") then
		return
	end
	consoleSetupDone[instance] = true

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Upgrade Treadmill ($200)"
	prompt.ObjectText = "🏃 My Speed Treadmill"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function(player: Player)
		local tm = instance.Parent
		local plot = tm and tm.Parent
		if not plot or plot:GetAttribute("OwnerUserId") ~= player.UserId then
			ClientSyncService.Notify(player, "Train and upgrade on your own Plot's Treadmill!", Color3.fromRGB(255, 95, 95))
			return
		end
		local currentLevel = StatsService.GetSpeedLevel(player)
		local price = ShopData.GetSpeedPrice(currentLevel)
		if not price then
			ClientSyncService.Notify(player, "Your Treadmill is already at MAX Tier!", Color3.fromRGB(255, 215, 55))
			return
		end
		if not EconomyService.TrySpend(player, price) then
			ClientSyncService.Notify(player, `Need $${NumberFormat.Short(price)} to upgrade your Treadmill!`, Color3.fromRGB(255, 95, 95))
			return
		end
		StatsService.SetSpeedLevel(player, currentLevel + 1)
		local newGain = ShopData.GetTrainerGainPerSec(currentLevel + 1)
		ClientSyncService.Notify(player, string.format("🏃 Treadmill Upgraded to Tier %d (+%.2f Speed/sec)!", currentLevel + 1, newGain), Color3.fromRGB(80, 235, 255))
	end)
	prompt.Parent = instance
end

local function watchPlayer(player: Player)
	local profile = DataService.WaitForProfile(player)
	if not profile or not player.Parent then
		return
	end
	player:SetAttribute("SpeedLevel", profile.SpeedLevel)
	player:SetAttribute("TrainedSpeed", profile.TrainedSpeed)
	player:SetAttribute("SlowMode", false)

	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Humanoid", 5)
		task.defer(function()
			StatsService.Refresh(player)
		end)
	end)

	if player.Character then
		task.spawn(function()
			player.Character:WaitForChild("Humanoid", 5)
			StatsService.Refresh(player)
		end)
	end
	task.delay(1.0, function()
		if player.Parent then
			StatsService.UpdatePlotTreadmillVisuals(player)
		end
	end)
end

function StatsService.Init()
	local treadmillTickEvent = Remotes.GetEvent("TreadmillTick")
	local slowModeEvent = Remotes.GetEvent("ToggleSlowMode")

	for _, inst in CollectionService:GetTagged("PlotTreadmillConsole") do
		task.spawn(setupTreadmillConsole, inst)
	end
	CollectionService:GetInstanceAddedSignal("PlotTreadmillConsole"):Connect(setupTreadmillConsole)

	PlotService.PlotClaimed:Connect(function(player: Player)
		task.defer(function()
			if player.Parent then
				StatsService.UpdatePlotTreadmillVisuals(player)
			end
		end)
	end)

	slowModeEvent.OnServerEvent:Connect(function(player: Player)
		if not RateLimiter.Check(player, "ToggleSlowMode", 0.2) then
			return
		end
		local cur = player:GetAttribute("SlowMode") == true
		player:SetAttribute("SlowMode", not cur)
		StatsService.Refresh(player)
	end)

	Players.PlayerAdded:Connect(function(player)
		task.spawn(watchPlayer, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(watchPlayer, player)
	end

	-- Treadmill Speed Training Loop (every 1.0s while on the player's own Plot Treadmill)
	task.spawn(function()
		while true do
			task.wait(1.0)
			for _, player in Players:GetPlayers() do
				if DataService.IsLoaded(player) and isStandingOnOwnTreadmill(player) then
					local tier = StatsService.GetSpeedLevel(player)
					local gain = ShopData.GetTrainerGainPerSec(tier)
					local boostUntil = player:GetAttribute("FiestaSpeedBoostUntil")
					if typeof(boostUntil) == "number" and boostUntil > workspace:GetServerTimeNow() then
						gain *= 2
					end
					StatsService.AddTrainedSpeed(player, gain)
					treadmillTickEvent:FireClient(player, gain)
				end
			end
		end
	end)
end

return StatsService
