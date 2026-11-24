--!strict
-- VfxController.luau (CLIENT)
-- 1) Animates placed 3D pets on plots so they wander, turn, and hop around playfully!
-- 2) Floating background-free green "+$5" popups above placed pets every second.
-- 3) Particle burst + Epic+ light beam on "PetReveal".
-- 4) Camera shake when caught.

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local ShopData = require(Shared:WaitForChild("ShopData"))
local Rarities = require(Shared:WaitForChild("Rarities"))
local NumberFormat = require(Shared:WaitForChild("NumberFormat"))
local PetVisuals = require(Shared:WaitForChild("PetVisuals"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local SoundController = require(script.Parent:WaitForChild("SoundController"))

local VfxController = {}

local shakeUntil = 0
local shakeIntensity = 0.6

type PetWanderState = {
	HomePos: Vector3,
	PlotCenter: Vector3,
	CurrentPos: Vector3,
	TargetPos: Vector3,
	FacingAngle: number,
	WaitUntil: number,
	HopPhase: number,
}

local wanderStates: { [Model]: PetWanderState } = {}
local rng = Random.new()
local wasOnTreadmill = false
local treadmillExitCooldownUntil = 0

local function isPlayerTryingToWalkOff(): boolean
	if UserInputService:GetFocusedTextBox() then
		return false
	end
	if
		UserInputService:IsKeyDown(Enum.KeyCode.A)
		or UserInputService:IsKeyDown(Enum.KeyCode.S)
		or UserInputService:IsKeyDown(Enum.KeyCode.D)
		or UserInputService:IsKeyDown(Enum.KeyCode.Left)
		or UserInputService:IsKeyDown(Enum.KeyCode.Down)
		or UserInputService:IsKeyDown(Enum.KeyCode.Right)
		or UserInputService:IsKeyDown(Enum.KeyCode.Space)
	then
		return true
	end
	return false
end

local function stepTreadmillsAndRunner(dt: number, now: number)
	local localPlayer = Players.LocalPlayer
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	local activePad: BasePart? = nil
	local activeTreadmill: Model? = nil

	for _, pad in CollectionService:GetTagged("TreadmillPad") do
		if pad:IsA("BasePart") then
			local tm = pad.Parent
			if tm and tm:IsA("Model") then
				local beltSpeedAttr = tm:GetAttribute("BeltSpeed")
				local beltSpeed = if typeof(beltSpeedAttr) == "number" then beltSpeedAttr else 12
				local beltCenter = pad.Position

				-- Animate neon belt strips scrolling backward (+Z) at the treadmill's exact speed!
				for _, child in tm:GetChildren() do
					if child:IsA("BasePart") and string.find(child.Name, "Strip") then
						local idxAttr = child:GetAttribute("StripIndex")
						local idx = if typeof(idxAttr) == "number" then idxAttr else 1
						local cycleLen = 9.2
						local rawZ = ((now * beltSpeed * 0.42 + (idx - 1) * (cycleLen / 5)) % cycleLen) - (cycleLen * 0.5)
						child.Position = Vector3.new(beltCenter.X, beltCenter.Y + 0.02, beltCenter.Z + rawZ)
					end
				end

				-- Check if the local player is standing on their own plot's treadmill pad
				if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
					local plot = tm.Parent
					if plot and plot:IsA("Model") and plot:GetAttribute("OwnerUserId") == localPlayer.UserId then
						local dx = math.abs(root.Position.X - beltCenter.X)
						local dz = math.abs(root.Position.Z - beltCenter.Z)
						local dy = root.Position.Y - beltCenter.Y
						if dx <= pad.Size.X * 0.48 and dz <= pad.Size.Z * 0.46 and dy >= 0 and dy <= 6.5 then
							activePad = pad
							activeTreadmill = tm
						end
					end
				end
			end
		end
	end

	if activePad and (humanoid and humanoid.Jump or isPlayerTryingToWalkOff()) then
		treadmillExitCooldownUntil = now + 0.55
	end

	-- Auto-run on the treadmill when standing on it!
	if now >= treadmillExitCooldownUntil and activePad and activeTreadmill and root and root:IsA("BasePart") and humanoid then
		local levelAttr = localPlayer:GetAttribute("SpeedLevel")
		local tier = if typeof(levelAttr) == "number" then levelAttr else 0
		local tierInfo = ShopData.GetTreadmillTierInfo(tier)
		local runSpd = tierInfo.RunSpeed

		wasOnTreadmill = true
		localPlayer:SetAttribute("OnTreadmill", true)

		-- Match the character's running animation speed to the treadmill's tier speed!
		humanoid.WalkSpeed = runSpd

		-- Keep the character running in-place toward the treadmill console (-Z) while centered on the belt
		local targetPoint = Vector3.new(activePad.Position.X, root.Position.Y, activePad.Position.Z + 0.8)
		local newPos = root.Position:Lerp(targetPoint, math.clamp(dt * 14, 0, 1))
		root.CFrame = CFrame.lookAt(newPos, newPos + Vector3.new(0, 0, -5))
		humanoid:Move(Vector3.new(0, 0, -1), false)
	elseif wasOnTreadmill then
		wasOnTreadmill = false
		localPlayer:SetAttribute("OnTreadmill", false)
		if humanoid then
			local actualAttr = localPlayer:GetAttribute("ActualWalkSpeed")
			if typeof(actualAttr) == "number" and actualAttr > 0 then
				humanoid.WalkSpeed = actualAttr
			else
				local trainedAttr = localPlayer:GetAttribute("TrainedSpeed")
				local trained = if typeof(trainedAttr) == "number" then trainedAttr else 0
				local slow = if localPlayer:GetAttribute("SlowMode") == true then 0.55 else 1
				humanoid.WalkSpeed = (Config.BaseWalkSpeed + trained) * slow
			end
		end
	end
end

function VfxController.ShakeCamera(duration: number, intensity: number)
	shakeUntil = os.clock() + duration
	shakeIntensity = intensity
end

local function pickNewWanderTarget(state: PetWanderState): Vector3
	-- Roam freely across the entire huge 72x72 open grass yard of the plot!
	local rx = (rng:NextNumber() * 2 - 1) * 30.0
	local rz = (rng:NextNumber() * 2 - 1) * 28.0
	return Vector3.new(state.PlotCenter.X + rx, state.HomePos.Y, state.PlotCenter.Z + rz)
end

local function stepPlacedPets(dt: number, now: number)
	local plots = workspace:FindFirstChild("BasePlots")
	if not plots then
		return
	end

	local activeModels: { [Model]: boolean } = {}

	for _, plot in plots:GetChildren() do
		if plot:IsA("Model") then
			local floor = plot:FindFirstChild("Floor")
			local petsFolder = plot:FindFirstChild("Pets")
			local isMyPlot = plot:GetAttribute("OwnerUserId") == Players.LocalPlayer.UserId
			if floor and floor:IsA("BasePart") and petsFolder then
				for _, petModel in petsFolder:GetChildren() do
					if petModel:IsA("Model") and petModel.PrimaryPart then
						-- Hide "Steal Pet" prompt on the owner's own pets!
						if isMyPlot then
							local stealPrompt = petModel.PrimaryPart:FindFirstChild("StealPrompt")
							if stealPrompt and stealPrompt:IsA("ProximityPrompt") and stealPrompt.Enabled then
								stealPrompt.Enabled = false
							end
						end
						activeModels[petModel] = true
						local primary = petModel.PrimaryPart
						local state = wanderStates[petModel]
						if not state then
							local startPos = primary.Position
							state = {
								HomePos = startPos,
								PlotCenter = Vector3.new(floor.Position.X, startPos.Y, floor.Position.Z),
								CurrentPos = startPos,
								TargetPos = startPos,
								FacingAngle = rng:NextNumber() * math.pi * 2,
								WaitUntil = now + rng:NextNumber() * 1.2,
								HopPhase = rng:NextNumber() * 10,
							}
							state.TargetPos = pickNewWanderTarget(state)
							wanderStates[petModel] = state
						end

						if now < state.WaitUntil then
							-- Gentle idle breathing bounce while resting
							local idleBob = math.sin(now * 4 + state.HopPhase) * 0.14
							petModel:PivotTo(
								CFrame.new(state.CurrentPos + Vector3.new(0, idleBob, 0))
									* CFrame.Angles(0, state.FacingAngle, 0)
							)
						else
							local toTarget = Vector3.new(
								state.TargetPos.X - state.CurrentPos.X,
								0,
								state.TargetPos.Z - state.CurrentPos.Z
							)
							local dist = toTarget.Magnitude
							if dist <= 0.35 then
								state.WaitUntil = now + 0.9 + rng:NextNumber() * 1.6
								state.TargetPos = pickNewWanderTarget(state)
							else
								local dir = toTarget.Unit
								local stepDist = math.min(dist, 5.2 * dt)
								state.CurrentPos += dir * stepDist
								state.FacingAngle = math.atan2(-dir.X, -dir.Z)

								-- Playful hop + waddle tilt while walking!
								local hop = math.abs(math.sin(now * 10 + state.HopPhase)) * 0.65
								local waddle = math.sin(now * 10 + state.HopPhase) * math.rad(8)
								petModel:PivotTo(
									CFrame.new(state.CurrentPos + Vector3.new(0, hop, 0))
										* CFrame.Angles(0, state.FacingAngle, waddle)
								)
							end
						end
					end
				end
			end
		end
	end

	for model in wanderStates do
		if not activeModels[model] then
			wanderStates[model] = nil
		end
	end
end

local function spawnFloatingIncomeText(part: BasePart, amount: number)
	local gui = Instance.new("BillboardGui")
	gui.Name = "IncomePopup"
	gui.Size = UDim2.fromScale(2.8, 0.95)
	gui.StudsOffset = Vector3.new((math.random() - 0.5) * 0.8, 1.8, 0)
	gui.MaxDistance = 55
	gui.AlwaysOnTop = false
	gui.Adornee = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(70, 255, 110)
	label.TextStrokeColor3 = Color3.fromRGB(10, 35, 15)
	label.TextStrokeTransparency = 0
	label.Text = `+${NumberFormat.Short(amount)}`
	label.Parent = gui

	gui.Parent = part

	local targetOffset = gui.StudsOffset + Vector3.new(0, 2.2, 0)
	TweenService:Create(gui, TweenInfo.new(0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffset = targetOffset,
	}):Play()

	task.delay(0.45, function()
		if label.Parent then
			TweenService:Create(label, TweenInfo.new(0.4), {
				TextTransparency = 1,
				TextStrokeTransparency = 1,
			}):Play()
		end
	end)

	task.delay(0.88, function()
		if gui.Parent then
			gui:Destroy()
		end
	end)
end

local function onPetRevealAdded(gui: BillboardGui)
	local adornee = gui.Adornee
	if not adornee or not adornee:IsA("BasePart") then
		return
	end

	local rarityName = gui:GetAttribute("Rarity")
	local rName = if typeof(rarityName) == "string" then rarityName else "Common"
	local rInfo = Rarities.Data[rName] or Rarities.Data.Common

	if rInfo.SortOrder >= 3 then
		SoundController.Play("RevealEpic")
	elseif rInfo.SortOrder == 2 then
		SoundController.Play("RevealRare")
	else
		SoundController.Play("RevealCommon")
	end

	local attachment = Instance.new("Attachment")
	attachment.Parent = adornee

	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(rInfo.Color)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.7),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Lifetime = NumberRange.new(0.4, 0.8)
	emitter.Speed = NumberRange.new(8, 16)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = 0
	emitter.Parent = attachment
	emitter:Emit(20)

	if rInfo.SortOrder >= 3 then
		local beamPart = Instance.new("Part")
		beamPart.Name = "RevealBeam"
		beamPart.Size = Vector3.new(1.5, 18, 1.5)
		beamPart.CFrame = adornee.CFrame * CFrame.new(0, 9, 0)
		beamPart.Anchored = true
		beamPart.CanCollide = false
		beamPart.CanTouch = false
		beamPart.CanQuery = false
		beamPart.Material = Enum.Material.Neon
		beamPart.Color = rInfo.Color
		beamPart.Transparency = 0.45
		beamPart.Parent = workspace
		task.delay(0.9, function()
			beamPart:Destroy()
		end)
	end

	task.delay(1.2, function()
		if attachment.Parent then
			attachment:Destroy()
		end
	end)
end

function VfxController.Init()
	workspace.DescendantAdded:Connect(function(inst: Instance)
		if inst:IsA("BillboardGui") and inst.Name == "PetReveal" then
			task.defer(onPetRevealAdded, inst)
		end
	end)

	-- Floating "+0.20 ⚡ Speed!" popup whenever the player trains on the Takbuhan Treadmill!
	Remotes.GetEvent("TreadmillTick").OnClientEvent:Connect(function(gain: any)
		if typeof(gain) ~= "number" then
			return
		end
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			return
		end
		SoundController.Play("RevealCommon")

		local gui = Instance.new("BillboardGui")
		gui.Name = "SpeedPopup"
		gui.Size = UDim2.fromScale(3.6, 1.0)
		gui.StudsOffset = Vector3.new((math.random() - 0.5) * 1.2, 2.5, 0)
		gui.MaxDistance = 50
		gui.AlwaysOnTop = false
		gui.Adornee = root

		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(80, 230, 255)
		label.TextStrokeTransparency = 0
		label.Text = `+{NumberFormat.Short(gain)} ⚡ Speed!`
		label.Parent = gui
		gui.Parent = root

		TweenService:Create(gui, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			StudsOffset = gui.StudsOffset + Vector3.new(0, 2.2, 0),
		}):Play()
		task.delay(0.82, function()
			if gui.Parent then
				gui:Destroy()
			end
		end)
	end)

	-- 3D Pet Jump-to-Player Animation when an unlocked cage is opened!
	Remotes.GetEvent("CageOpenedAnim").OnClientEvent:Connect(function(startPos: any, petId: any, mutation: any)
		if typeof(startPos) ~= "Vector3" or typeof(petId) ~= "string" then
			return
		end
		local mutStr: string? = if typeof(mutation) == "string" then mutation else nil
		local localPlayer = Players.LocalPlayer
		local model = PetVisuals.BuildModel(petId, mutStr, CFrame.new(startPos))
		model.Name = "JumpingPetAnim"
		model.Parent = workspace

		local duration = 0.65
		local started = os.clock()
		local conn: RBXScriptConnection
		conn = RunService.RenderStepped:Connect(function()
			local alpha = math.clamp((os.clock() - started) / duration, 0, 1)
			local character = localPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local endPos = if root and root:IsA("BasePart") then root.Position + Vector3.new(0, 1.2, 0) else (startPos + Vector3.new(0, 4, 0))

			-- Parabolic jump arc + joyful 360 spin toward the player
			local flatPos = startPos:Lerp(endPos, alpha)
			local arcHeight = math.sin(alpha * math.pi) * 8.0
			local currentPos = flatPos + Vector3.new(0, arcHeight, 0)
			local spinAngle = alpha * math.pi * 2

			if model.Parent then
				model:PivotTo(CFrame.new(currentPos) * CFrame.Angles(0, spinAngle, 0))
			end

			if alpha >= 1 then
				conn:Disconnect()
				SoundController.Play("Deliver")
				if model.Parent then
					model:Destroy()
				end
			end
		end)
	end)

	-- Every second, pop floating green "+$X" above placed pets on plots
	task.spawn(function()
		local localPlayer = Players.LocalPlayer
		while true do
			task.wait(Config.IncomeTickSeconds)
			local plots = workspace:FindFirstChild("BasePlots")
			local cam = workspace.CurrentCamera
			if plots and cam then
				local mult = if localPlayer:GetAttribute("OwnsDoubleMoney") == true then 2 else 1
				for _, plot in plots:GetChildren() do
					local petsFolder = plot:FindFirstChild("Pets")
					if petsFolder then
						for _, petModel in petsFolder:GetChildren() do
							if petModel:IsA("Model") and petModel.PrimaryPart then
								local dist = (petModel.PrimaryPart.Position - cam.CFrame.Position).Magnitude
								if dist <= 65 then
									local rawRate = petModel:GetAttribute("IncomePerSec")
									if typeof(rawRate) == "number" and rawRate > 0 then
										local isMine = plot:GetAttribute("OwnerUserId") == localPlayer.UserId
										local shown = if isMine then rawRate * mult else rawRate
										spawnFloatingIncomeText(petModel.PrimaryPart, shown)
									end
								end
							end
						end
					end
				end
			end
		end
	end)

	RunService.RenderStepped:Connect(function(dt: number)
		local now = os.clock()
		stepPlacedPets(dt, now)
		stepTreadmillsAndRunner(dt, now)

		if now < shakeUntil then
			local cam = workspace.CurrentCamera
			if cam then
				local ox = (rng:NextNumber() - 0.5) * 2 * shakeIntensity
				local oy = (rng:NextNumber() - 0.5) * 2 * shakeIntensity
				cam.CFrame = cam.CFrame * CFrame.new(ox, oy, 0)
			end
		end
	end)
end

return VfxController
