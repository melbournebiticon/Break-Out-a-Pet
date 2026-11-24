--!strict
-- TrapService.luau (SERVER)
-- Toggles Parts tagged "Laser" on/off. Touching an active laser while carrying drops the cage/pet and knocks back.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local CageService = require(script.Parent:WaitForChild("CageService"))

local TrapService = {}

local setupDone: { [Instance]: boolean } = {}
local touchCooldown: { [Player]: number } = {}
local extraLaserCatch: ((Player) -> ())? = nil
local rng = Random.new()

function TrapService.SetExtraLaserCatch(fn: (Player) -> ())
	extraLaserCatch = fn
end

local function setupLaser(instance: Instance)
	if setupDone[instance] then
		return
	end
	if not instance:IsA("BasePart") or not instance:IsDescendantOf(workspace) then
		return
	end

	local laser = instance
	setupDone[laser] = true
	laser.Destroying:Connect(function()
		setupDone[laser] = nil
	end)

	local rawOn = laser:GetAttribute("OnSeconds")
	local rawOff = laser:GetAttribute("OffSeconds")
	local onSeconds = if typeof(rawOn) == "number" and rawOn > 0 then rawOn else Config.LaserDefaultOnSeconds
	local offSeconds = if typeof(rawOff) == "number" and rawOff > 0 then rawOff else Config.LaserDefaultOffSeconds

	laser:SetAttribute("Active", true)

	laser.Touched:Connect(function(hit: BasePart)
		if laser:GetAttribute("Active") ~= true then
			return
		end
		local character = hit:FindFirstAncestorOfClass("Model")
		if not character then
			return
		end
		local player = Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end

		local now = os.clock()
		if touchCooldown[player] and (now - touchCooldown[player]) < 0.75 then
			return
		end
		touchCooldown[player] = now

		if CageService.IsCarrying(player) then
			CageService.DropCage(player, "caught")
		elseif extraLaserCatch then
			extraLaserCatch(player)
		end

		local root = character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local pushDir = (root.Position - laser.Position)
			local flat = Vector3.new(pushDir.X, 0, pushDir.Z)
			local unit = if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, 1)
			root.AssemblyLinearVelocity = unit * Config.LaserKnockbackSpeed + Vector3.new(0, 22, 0)
		end
	end)

	task.spawn(function()
		task.wait(rng:NextNumber() * onSeconds)
		while laser.Parent do
			laser:SetAttribute("Active", true)
			laser.Transparency = 0.15
			task.wait(onSeconds)
			if not laser.Parent then
				break
			end
			laser:SetAttribute("Active", false)
			laser.Transparency = 0.85
			task.wait(offSeconds)
		end
	end)
end

function TrapService.Init()
	for _, instance in CollectionService:GetTagged("Laser") do
		task.spawn(setupLaser, instance)
	end
	CollectionService:GetInstanceAddedSignal("Laser"):Connect(setupLaser)

	Players.PlayerRemoving:Connect(function(player)
		touchCooldown[player] = nil
	end)
end

return TrapService
