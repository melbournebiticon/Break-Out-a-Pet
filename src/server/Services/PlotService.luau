--!strict
-- PlotService.luau (SERVER)
-- Assigns each player their own base plot from Workspace.BasePlots, manages respawn location and robbery shields.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local DataService = require(script.Parent:WaitForChild("DataService"))

local PlotService = {}

local PlotClaimedEvent = Instance.new("BindableEvent")
PlotService.PlotClaimed = PlotClaimedEvent.Event

local plots: { Model } = {}
local plotByUserId: { [number]: Model } = {}

function PlotService.SetShield(plot: Model, durationSeconds: number)
	local now = workspace:GetServerTimeNow()
	local current = plot:GetAttribute("ShieldUntil")
	local curNum = if typeof(current) == "number" then current else 0
	plot:SetAttribute("ShieldUntil", math.max(curNum, now + durationSeconds))
end

function PlotService.IsShielded(plot: Model): boolean
	local shieldUntil = plot:GetAttribute("ShieldUntil")
	if typeof(shieldUntil) == "number" then
		return workspace:GetServerTimeNow() < shieldUntil
	end
	return false
end

function PlotService.Claim(player: Player): Model?
	local profile = DataService.WaitForProfile(player)
	if not profile or not player.Parent then
		return nil
	end

	if plotByUserId[player.UserId] then
		return plotByUserId[player.UserId]
	end

	for _, plot in plots do
		if plot:GetAttribute("OwnerUserId") == 0 then
			plot:SetAttribute("OwnerUserId", player.UserId)
			plot:SetAttribute("OwnerName", player.DisplayName)
			plotByUserId[player.UserId] = plot

			-- New player protection shield
			PlotService.SetShield(plot, Config.NewPlayerProtectionSeconds)

			local spawnPart = plot:FindFirstChild("Spawn")
			if spawnPart and spawnPart:IsA("SpawnLocation") then
				player.RespawnLocation = spawnPart
				local function moveToPlot(character: Model)
					task.defer(function()
						if character.Parent and plotByUserId[player.UserId] == plot then
							character:PivotTo(spawnPart.CFrame + Vector3.new(0, 4, 0))
						end
					end)
				end
				player.CharacterAdded:Connect(moveToPlot)
				if player.Character then
					moveToPlot(player.Character)
				end
			end

			PlotClaimedEvent:Fire(player, plot)
			return plot
		end
	end

	warn(`No free plot for {player.Name}`)
	return nil
end

function PlotService.Release(player: Player)
	local plot = plotByUserId[player.UserId]
	if plot then
		plot:SetAttribute("OwnerUserId", 0)
		plot:SetAttribute("OwnerName", "")
		plot:SetAttribute("ShieldUntil", 0)
		plotByUserId[player.UserId] = nil
	end
end

function PlotService.GetPlot(player: Player): Model?
	return plotByUserId[player.UserId]
end

function PlotService.GetAllPlots(): { Model }
	return plots
end

function PlotService.Init()
	local folder = workspace:WaitForChild("BasePlots", 10)
	if not folder then
		warn("Workspace.BasePlots not found. Run studio/Blockout.luau in the Studio command bar first.")
		return
	end

	for _, child in folder:GetChildren() do
		if child:IsA("Model") then
			child:SetAttribute("OwnerUserId", 0)
			child:SetAttribute("OwnerName", "")
			child:SetAttribute("ShieldUntil", 0)
			table.insert(plots, child)
		end
	end
	table.sort(plots, function(a, b)
		return a.Name < b.Name
	end)

	Players.PlayerAdded:Connect(function(player)
		task.spawn(PlotService.Claim, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(PlotService.Claim, player)
	end
	Players.PlayerRemoving:Connect(PlotService.Release)
end

return PlotService
