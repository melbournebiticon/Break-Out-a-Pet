--!strict
-- TutorialGuide.luau (CLIENT)
-- Guides new players with a 3D Beam arrow and a sleek "Steal an Egg"-style toast (no permanent bottom text clutter).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Theme = require(script.Parent:WaitForChild("Theme"))
local Toasts = require(script.Parent:WaitForChild("Toasts"))

local TutorialGuide = {}

local function findTargetPart(player: Player, step: number): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return nil
	end

	if step == 1 then
		local bestPart: BasePart? = nil
		local bestDist = math.huge
		for _, cage in CollectionService:GetTagged("Cage") do
			if cage:IsA("Model") and cage:GetAttribute("Zone") == "Zone1" and not cage:GetAttribute("Taken") then
				local primary = cage.PrimaryPart
				if primary then
					local d = (primary.Position - root.Position).Magnitude
					if d < bestDist then
						bestDist = d
						bestPart = primary
					end
				end
			end
		end
		return bestPart
	elseif step == 2 then
		local plots = workspace:FindFirstChild("BasePlots")
		if plots then
			for _, plot in plots:GetChildren() do
				if plot:IsA("Model") and plot:GetAttribute("OwnerUserId") == player.UserId then
					local drop = plot:FindFirstChild("DropZone")
					if drop and drop:IsA("BasePart") then
						return drop
					end
				end
			end
		end
	end
	return nil
end

function TutorialGuide.Init(_screenGui: ScreenGui)
	local player = Players.LocalPlayer

	local beamFolder = Instance.new("Folder")
	beamFolder.Name = "TutorialBeam"
	beamFolder.Parent = workspace

	local att0 = Instance.new("Attachment")
	local att1 = Instance.new("Attachment")
	local targetAnchor = Instance.new("Part")
	targetAnchor.Name = "TutorialTargetAnchor"
	targetAnchor.Size = Vector3.new(0.5, 0.5, 0.5)
	targetAnchor.Transparency = 1
	targetAnchor.Anchored = true
	targetAnchor.CanCollide = false
	targetAnchor.CanTouch = false
	targetAnchor.CanQuery = false
	targetAnchor.Parent = beamFolder
	att1.Parent = targetAnchor

	local beam = Instance.new("Beam")
	beam.Attachment0 = att0
	beam.Attachment1 = att1
	beam.Width0 = 1.0
	beam.Width1 = 1.0
	beam.FaceCamera = true
	beam.Color = ColorSequence.new(Color3.fromRGB(80, 220, 255))
	beam.Enabled = false
	beam.Parent = beamFolder

	local lastShownStep = 0
	local function announceStep()
		local step = player:GetAttribute("TutorialStep")
		if typeof(step) ~= "number" or step == lastShownStep then
			return
		end
		lastShownStep = step
		if step == 1 then
			Toasts.Show("🎯 FIRST HEIST", Theme.AccentBlue, "Follow the blue beam to Zone 1 and hold E on a Mystery Cage!")
		elseif step == 2 then
			Toasts.Show("🏃 ESCAPE TO BASE!", Theme.AccentGreen, "Carry the cage back to your plot's green pad!")
		end
	end

	player:GetAttributeChangedSignal("TutorialStep"):Connect(announceStep)
	task.delay(1.0, announceStep)

	RunService.Heartbeat:Connect(function()
		local step = player:GetAttribute("TutorialStep")
		if step ~= 1 and step ~= 2 then
			beam.Enabled = false
			return
		end

		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local target = findTargetPart(player, step)
		if root and root:IsA("BasePart") and target then
			if att0.Parent ~= root then
				att0.Parent = root
			end
			targetAnchor.Position = target.Position
			beam.Enabled = true
		else
			beam.Enabled = false
		end
	end)
end

return TutorialGuide
