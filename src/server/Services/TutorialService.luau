--!strict
-- TutorialService.luau (SERVER)
-- Guides new players through their first heist: Step 1 (open a Zone 1 cage) -> Step 2 (deliver to green DropZone) -> Step 3 (Done).

local Players = game:GetService("Players")

local DataService = require(script.Parent:WaitForChild("DataService"))
local CageService = require(script.Parent:WaitForChild("CageService"))

local TutorialService = {}

local function setupPlayer(player: Player)
	local profile = DataService.WaitForProfile(player)
	if not profile or not player.Parent then
		return
	end

	if profile.TutorialDone then
		player:SetAttribute("TutorialStep", 3)
	else
		player:SetAttribute("TutorialStep", 1)
	end
end

function TutorialService.Init()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(setupPlayer, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(setupPlayer, player)
	end

	CageService.CagePickedUp:Connect(function(player: Player)
		if player:GetAttribute("TutorialStep") == 1 then
			player:SetAttribute("TutorialStep", 2)
		end
	end)

	CageService.CageDelivered:Connect(function(player: Player)
		local step = player:GetAttribute("TutorialStep")
		if step == 1 or step == 2 then
			player:SetAttribute("TutorialStep", 3)
			DataService.SetTutorialDone(player)
		end
	end)
end

return TutorialService
