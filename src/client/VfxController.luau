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
local CageVisuals = require(Shared:WaitForChild("CageVisuals"))
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

-- Procedural Animation Caches (Cage Struggle, Carried Overhead Pose & Sweat, Guard Stun Spin-Knockdown)
local cageBaseCFrames: { [Model]: CFrame } = {}
local cagePhaseOffsets: { [Model]: number } = {}
local coreBaseOffsets: { [BasePart]: Vector3 } = {}

type ArmPoseState = {
	RightMotor: Motor6D?,
	LeftMotor: Motor6D?,
	RightOrigC0: CFrame?,
	LeftOrigC0: CFrame?,
	IsR15: boolean,
	WasOverridden: boolean,
	SweatEmitter: ParticleEmitter?,
}
local characterArmStates: { [Model]: ArmPoseState } = {}

type StunAnimState = {
	StartedAt: number,
	EndsAt: number,
	BaseY: number,
	DizzyGui: BillboardGui?,
}
local stunnedGuards: { [Model]: StunAnimState } = {}

-- 1A) Uncollected & Plot Cage Struggle Bobbing/Shaking (scaled by Rarity/Zone)
local function stepCageStruggle(now: number)
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local camPos = cam.CFrame.Position

	for _, inst in CollectionService:GetTagged("Cage") do
		if inst:IsA("Model") and inst.PrimaryPart then
			local isTaken = inst:GetAttribute("Taken") == true
			if not isTaken then
				local primary = inst.PrimaryPart
				local dist = (primary.Position - camPos).Magnitude
				if dist <= 95 then
					local baseCF = cageBaseCFrames[inst]
					if not baseCF then
						baseCF = inst:GetPivot()
						cageBaseCFrames[inst] = baseCF
						cagePhaseOffsets[inst] = rng:NextNumber() * math.pi * 2
					end
					local phase = cagePhaseOffsets[inst] or 0
					local zoneAttr = inst:GetAttribute("Zone")
					local lootAttr = inst:GetAttribute("LootTable")
					local intensity = CageVisuals.GetZoneStruggleIntensity(
						if typeof(zoneAttr) == "string" then zoneAttr else nil,
						if typeof(lootAttr) == "string" then lootAttr else nil
					)

					-- Periodic frantic struggle bursts every ~1.8 seconds
					local cycle = (now * (1.2 + intensity * 0.7) + phase) % (math.pi * 2)
					local burst = math.max(0, math.sin(cycle)) ^ 3
					local freq = 14 + intensity * 16
					local bobY = math.abs(math.sin(now * freq + phase)) * (0.18 + 0.42 * intensity) * burst
					local tiltZ = math.sin(now * freq + phase) * math.rad(4 + 11 * intensity) * burst
					local tiltX = math.cos(now * (freq * 0.85) + phase) * math.rad(3 + 7 * intensity) * burst

					inst:PivotTo(baseCF * CFrame.new(0, bobY, 0) * CFrame.Angles(tiltX, 0, tiltZ))

					local core = inst:FindFirstChild("MysteryCore")
					if core and core:IsA("BasePart") then
						local baseOff = coreBaseOffsets[core]
						if not baseOff then
							baseOff = core.Position - baseCF.Position
							coreBaseOffsets[core] = baseOff
						end
						local coreHop = math.sin(now * (6 + intensity * 8) + phase) * (0.22 + 0.35 * intensity)
						local coreSwirlX = math.cos(now * 5 + phase) * 0.25 * intensity
						core.CFrame = baseCF * CFrame.new(baseOff + Vector3.new(coreSwirlX, coreHop + bobY, 0))
					end
				end
			else
				cageBaseCFrames[inst] = nil
			end
		end
	end
end

-- 1B) Carried Cage / Stolen Pet Panic Shake + Character Overhead Arm Motor6Ds + Running Sweat Particles
local function ensureCarryArmState(character: Model): ArmPoseState
	local existing = characterArmStates[character]
	if existing then
		return existing
	end

	local rightMotor: Motor6D? = nil
	local leftMotor: Motor6D? = nil
	local isR15 = false

	local rightUpper = character:FindFirstChild("RightUpperArm")
	local leftUpper = character:FindFirstChild("LeftUpperArm")
	if rightUpper and leftUpper then
		isR15 = true
		local rs = rightUpper:FindFirstChild("RightShoulder")
		local ls = leftUpper:FindFirstChild("LeftShoulder")
		if rs and rs:IsA("Motor6D") then
			rightMotor = rs
		end
		if ls and ls:IsA("Motor6D") then
			leftMotor = ls
		end
	else
		local torso = character:FindFirstChild("Torso")
		if torso then
			local rs = torso:FindFirstChild("Right Shoulder")
			local ls = torso:FindFirstChild("Left Shoulder")
			if rs and rs:IsA("Motor6D") then
				rightMotor = rs
			end
			if ls and ls:IsA("Motor6D") then
				leftMotor = ls
			end
		end
	end

	local head = character:FindFirstChild("Head")
	local sweatEmitter: ParticleEmitter? = nil
	if head and head:IsA("BasePart") then
		local att = Instance.new("Attachment")
		att.Name = "CarrySweatAtt"
		att.Position = Vector3.new(0, 0.55, 0)
		att.Parent = head

		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "CarrySweatEmitter"
		emitter.Color = ColorSequence.new(Color3.fromRGB(135, 225, 255))
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.16),
			NumberSequenceKeypoint.new(0.5, 0.22),
			NumberSequenceKeypoint.new(1, 0),
		})
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.15),
			NumberSequenceKeypoint.new(1, 1),
		})
		emitter.Lifetime = NumberRange.new(0.32, 0.52)
		emitter.Speed = NumberRange.new(3.5, 6.5)
		emitter.SpreadAngle = Vector2.new(65, 35)
		emitter.Acceleration = Vector3.new(0, -24, 0)
		emitter.Rate = 0
		emitter.Parent = att
		sweatEmitter = emitter
	end

	local state: ArmPoseState = {
		RightMotor = rightMotor,
		LeftMotor = leftMotor,
		RightOrigC0 = if rightMotor then rightMotor.C0 else nil,
		LeftOrigC0 = if leftMotor then leftMotor.C0 else nil,
		IsR15 = isR15,
		WasOverridden = false,
		SweatEmitter = sweatEmitter,
	}
	characterArmStates[character] = state
	character.Destroying:Connect(function()
		characterArmStates[character] = nil
	end)
	return state
end

local function stepCarriedPanicAndArms(now: number)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character then
			local isCarrying = (player:GetAttribute("IsCarryingCage") == true)
				or (player:GetAttribute("IsCarryingStolen") == true)
			local armState = ensureCarryArmState(character)
			local root = character:FindFirstChild("HumanoidRootPart")
			local planarSpeed = 0
			if root and root:IsA("BasePart") then
				local v = root.AssemblyLinearVelocity
				planarSpeed = Vector3.new(v.X, 0, v.Z).Magnitude
			end

			if isCarrying then
				armState.WasOverridden = true
				local isRunning = planarSpeed > 2.5
				local isChased = player:GetAttribute("BeingChased") == true
				local armBob = if isRunning then math.sin(now * 16) * math.rad(7) else math.sin(now * 4) * math.rad(2)

				if armState.RightMotor and armState.RightOrigC0 then
					if armState.IsR15 then
						armState.RightMotor.C0 = armState.RightOrigC0 * CFrame.Angles(math.rad(162) + armBob, 0, math.rad(-10))
					else
						armState.RightMotor.C0 = armState.RightOrigC0 * CFrame.Angles(0, 0, math.rad(162) + armBob)
					end
				end
				if armState.LeftMotor and armState.LeftOrigC0 then
					if armState.IsR15 then
						armState.LeftMotor.C0 = armState.LeftOrigC0 * CFrame.Angles(math.rad(162) - armBob, 0, math.rad(10))
					else
						armState.LeftMotor.C0 = armState.LeftOrigC0 * CFrame.Angles(0, 0, math.rad(-162) - armBob)
					end
				end

				if armState.SweatEmitter then
					armState.SweatEmitter.Rate = if isChased and isRunning
						then 18
						elseif isRunning then 10
						elseif isChased then 6
						else 0
				end

				-- Animate the carried model's CarryMotor C1 for panicked struggle bobbing/shaking!
				local rarityAttr = player:GetAttribute("CarriedRarity")
				local rarityStr = if typeof(rarityAttr) == "string" then rarityAttr else nil
				local panicBoost = if isChased then 1.35 elseif isRunning then 1.15 else 0.75
				local struggleCF = PetVisuals.GetStruggleCFrame(now, rarityStr, panicBoost)

				-- Find CarryMotor either inside character (StolenPetCarry) or workspace (Carried Cage)
				if root and root:IsA("BasePart") then
					for _, assemblyPart in root:GetConnectedParts() do
						local cm = assemblyPart:FindFirstChild("CarryMotor")
						if cm and cm:IsA("Motor6D") then
							cm.C1 = struggleCF
							break
						end
					end
				end
			else
				if armState.WasOverridden then
					armState.WasOverridden = false
					if armState.RightMotor and armState.RightOrigC0 then
						armState.RightMotor.C0 = armState.RightOrigC0
					end
					if armState.LeftMotor and armState.LeftOrigC0 then
						armState.LeftMotor.C0 = armState.LeftOrigC0
					end
				end
				if armState.SweatEmitter and armState.SweatEmitter.Rate > 0 then
					armState.SweatEmitter.Rate = 0
				end
			end
		end
	end
end

-- 1C) Stunned Guard Dizzy Stars Indicator Cleanup (never override server NPC PivotTo on the client!)
local function stepStunnedGuards(now: number)
	for model, st in stunnedGuards do
		if not model.Parent or not model.PrimaryPart or now >= st.EndsAt then
			if st.DizzyGui and st.DizzyGui.Parent then
				st.DizzyGui:Destroy()
			end
			stunnedGuards[model] = nil
		end
	end
end

-- 1D) Pamalo Squash-and-Stretch Tool Swing Tween + Hit Impact Burst
local function playLocalPamaloSwingJuice(landedHit: boolean, hitPos: Vector3?)
	local localPlayer = Players.LocalPlayer
	local character = localPlayer.Character
	if character then
		local tool = character:FindFirstChildOfClass("Tool")
		local handle = tool and tool:FindFirstChild("Handle")
		if handle and handle:IsA("BasePart") then
			local origSize = handle.Size
			-- Wind-up squash
			handle.Size = Vector3.new(origSize.X * 1.22, origSize.Y * 0.82, origSize.Z * 1.22)
			-- Stretch on forward slap
			local stretchTween = TweenService:Create(
				handle,
				TweenInfo.new(0.07, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Size = Vector3.new(origSize.X * 0.86, origSize.Y * 1.28, origSize.Z * 0.86) }
			)
			stretchTween:Play()
			task.delay(0.08, function()
				if handle.Parent then
					TweenService:Create(
						handle,
						TweenInfo.new(0.12, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
						{ Size = origSize }
					):Play()
				end
			end)
		end
	end

	if landedHit then
		SoundController.Play("PamaloSlap")
		-- Brief 0.05s local hitstop camera shake!
		VfxController.ShakeCamera(0.05, 0.78)

		if typeof(hitPos) == "Vector3" then
			local ring = Instance.new("Part")
			ring.Name = "PamaloHitBurst"
			ring.Shape = Enum.PartType.Ball
			ring.Size = Vector3.new(1.2, 1.2, 1.2)
			ring.CFrame = CFrame.new(hitPos)
			ring.Color = Color3.fromRGB(255, 220, 55)
			ring.Material = Enum.Material.Neon
			ring.Transparency = 0.25
			ring.Anchored = true
			ring.CanCollide = false
			ring.CanTouch = false
			ring.CanQuery = false
			ring.Parent = workspace
			TweenService:Create(ring, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = Vector3.new(6.2, 6.2, 6.2),
				Transparency = 1,
			}):Play()
			task.delay(0.2, function()
				if ring.Parent then
					ring:Destroy()
				end
			end)
		end
	end
end

-- 1E) Guard Alert Bounce & Exclamation Indicator
local function playGuardAlertBounce(enemyModel: Model)
	local root = enemyModel.PrimaryPart or enemyModel:FindFirstChild("HumanoidRootPart")
	local head = enemyModel:FindFirstChild("Head")
	if not root or not root:IsA("BasePart") then
		return
	end

	local cam = workspace.CurrentCamera
	if cam and (root.Position - cam.CFrame.Position).Magnitude <= 95 then
		SoundController.Play("GuardAlert")
	end

	-- Pop exclamation indicator above head
	local adornee: BasePart = if head and head:IsA("BasePart") then head else root
	local alertGui = Instance.new("BillboardGui")
	alertGui.Name = "GuardAlertExclaim"
	alertGui.Size = UDim2.fromScale(0.2, 0.2)
	alertGui.StudsOffset = Vector3.new(0, 3.6, 0)
	alertGui.MaxDistance = 70
	alertGui.AlwaysOnTop = true
	alertGui.Adornee = adornee

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.FredokaOne
	lbl.TextScaled = true
	lbl.TextColor3 = Color3.fromRGB(255, 230, 45)
	lbl.TextStrokeColor3 = Color3.fromRGB(165, 20, 20)
	lbl.TextStrokeTransparency = 0
	lbl.Text = "❗ HOY!"
	lbl.Parent = alertGui
	alertGui.Parent = adornee

	TweenService:Create(alertGui, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromScale(3.6, 1.35),
		StudsOffset = Vector3.new(0, 4.4, 0),
	}):Play()

	-- Squash & stretch torso pop on the Guard model (without overriding server Root CFrame!)
	local torso = enemyModel:FindFirstChild("UpperTorso") or enemyModel:FindFirstChild("TorsoBody")
	local origTorsoSize = if torso and torso:IsA("BasePart") then torso.Size else nil
	if torso and torso:IsA("BasePart") and origTorsoSize then
		torso.Size = Vector3.new(origTorsoSize.X * 1.18, origTorsoSize.Y * 0.82, origTorsoSize.Z * 1.18)
		TweenService:Create(torso, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = Vector3.new(origTorsoSize.X * 0.9, origTorsoSize.Y * 1.18, origTorsoSize.Z * 0.9),
		}):Play()
		task.delay(0.15, function()
			if torso.Parent then
				TweenService:Create(torso, TweenInfo.new(0.16, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
					Size = origTorsoSize,
				}):Play()
			end
		end)
	end

	task.delay(0.65, function()
		if alertGui.Parent then
			alertGui:Destroy()
		end
	end)
end

local function startGuardStunSpin(enemyModel: Model, stunDuration: number)
	local root = enemyModel.PrimaryPart or enemyModel:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local head = enemyModel:FindFirstChild("Head")
	local adornee: BasePart = if head and head:IsA("BasePart") then head else root

	local old = stunnedGuards[enemyModel]
	if old and old.DizzyGui and old.DizzyGui.Parent then
		old.DizzyGui:Destroy()
	end

	local dizzyGui = Instance.new("BillboardGui")
	dizzyGui.Name = "DizzyStarsGui"
	dizzyGui.Size = UDim2.fromScale(3.4, 1.1)
	dizzyGui.StudsOffset = Vector3.new(0, 3.2, 0)
	dizzyGui.MaxDistance = 65
	dizzyGui.AlwaysOnTop = true
	dizzyGui.Adornee = adornee

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.FredokaOne
	lbl.TextScaled = true
	lbl.TextColor3 = Color3.fromRGB(255, 235, 75)
	lbl.TextStrokeTransparency = 0
	lbl.Text = "💫⭐️💫"
	lbl.Parent = dizzyGui
	dizzyGui.Parent = adornee

	local now = os.clock()
	stunnedGuards[enemyModel] = {
		StartedAt = now,
		EndsAt = now + math.max(0.5, stunDuration),
		BaseY = root.Position.Y,
		DizzyGui = dizzyGui,
	}
end

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
	-- Keep each pet roaming cleanly within its own designated Habitat Spot radius (±3.8 studs) so pets never overlap in one corner!
	local angle = rng:NextNumber() * math.pi * 2
	local radius = 1.2 + rng:NextNumber() * 2.6
	local rx = math.cos(angle) * radius
	local rz = math.sin(angle) * radius
	return Vector3.new(state.HomePos.X + rx, state.HomePos.Y, state.HomePos.Z + rz)
end

local bangkaBaseCFrames: { [Model]: CFrame } = {}
local function stepBangkaBoats(now: number)
	for idx, boat in CollectionService:GetTagged("BangkaBoat") do
		if boat:IsA("Model") and boat.PrimaryPart then
			local baseCF = bangkaBaseCFrames[boat]
			if not baseCF then
				baseCF = boat:GetPivot()
				bangkaBaseCFrames[boat] = baseCF
			end
			local phase = idx * 1.7
			local cruiseZ = math.sin(now * 0.18 + phase) * 55.0
			local bobY = math.sin(now * 1.9 + phase) * 0.45
			local pitch = math.sin(now * 1.6 + phase) * math.rad(3.5)
			local roll = math.cos(now * 1.3 + phase) * math.rad(4.0)
			boat:PivotTo(baseCF * CFrame.new(0, bobY, cruiseZ) * CFrame.Angles(pitch, 0, roll))
		end
	end
end

local function stepPlacedPets(dt: number, now: number)
	local plots = workspace:FindFirstChild("BasePlots")
	if not plots then
		return
	end

	local activeModels: { [Model]: boolean } = {}
	local hidePetLabels = Players.LocalPlayer:GetAttribute("HidePetLabels") == true

	for _, plot in plots:GetChildren() do
		if plot:IsA("Model") then
			local floor = plot:FindFirstChild("Floor")
			local petsFolder = plot:FindFirstChild("Pets")
			if floor and floor:IsA("BasePart") and petsFolder then
				for _, petModel in petsFolder:GetChildren() do
					if petModel:IsA("Model") and petModel.PrimaryPart then
						local primary = petModel.PrimaryPart
						local petInfoGui = primary:FindFirstChild("PetInfo")
						if petInfoGui and petInfoGui:IsA("BillboardGui") then
							petInfoGui.Enabled = not hidePetLabels
						end
						activeModels[petModel] = true
						local state = wanderStates[petModel]
						if not state then
							local homeAttr = petModel:GetAttribute("HabitatHomePos")
							local startPos = if typeof(homeAttr) == "Vector3" then Vector3.new(homeAttr.X, primary.Position.Y, homeAttr.Z) else primary.Position
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

	-- Pamalo Slap & Sipat VFX (Squash-and-stretch swing, 0.05s hitstop camera shake & impact ring)
	Remotes.GetEvent("PamaloVfx").OnClientEvent:Connect(function(action: any, arg1: any, arg2: any, arg3: any)
		if action == "Swing" then
			playLocalPamaloSwingJuice(arg2 == true, if typeof(arg3) == "Vector3" then arg3 else nil)
		elseif action == "SipatThrow" then
			SoundController.Play("SipatThrow")
			playLocalPamaloSwingJuice(false, nil)
		elseif action == "SipatHit" then
			playLocalPamaloSwingJuice(true, if typeof(arg1) == "Vector3" then arg1 else nil)
		end
	end)

	-- Enemy Alert Bounce & Stun Spin-Knockdown VFX
	Remotes.GetEvent("EnemyVfx").OnClientEvent:Connect(function(action: any, enemyModel: any, arg1: any)
		if typeof(enemyModel) ~= "Instance" or not enemyModel:IsA("Model") then
			return
		end
		if action == "Alert" then
			playGuardAlertBounce(enemyModel)
		elseif action == "Stun" then
			local dur = if typeof(arg1) == "number" then arg1 else 1.5
			startGuardStunSpin(enemyModel, dur)
		end
	end)

	-- Fiesta Plaza Minigame VFX (Hampas Palayok hits/shatter coin burst, Agawan Biik tags, Boodle Fight feast)
	Remotes.GetEvent("FiestaVfx").OnClientEvent:Connect(function(action: any, pos: any, arg1: any, arg2: any, arg3: any)
		if typeof(pos) ~= "Vector3" then
			return
		end
		if action == "PalayokHit" then
			SoundController.Play("PalayokCrack")
			local dmg = if typeof(arg1) == "number" then arg1 else 25
			local emoji = if typeof(arg2) == "string" then arg2 else "🩴"
			local host = Instance.new("Part")
			host.Size = Vector3.new(0.5, 0.5, 0.5)
			host.Position = pos + Vector3.new((math.random() - 0.5) * 2.5, 1.5, (math.random() - 0.5) * 2.5)
			host.Anchored = true
			host.Transparency = 1
			host.CanCollide = false
			host.CanQuery = false
			host.Parent = workspace

			local gui = Instance.new("BillboardGui")
			gui.Size = UDim2.fromScale(4.2, 1.3)
			gui.AlwaysOnTop = true
			gui.Adornee = host
			local lbl = Instance.new("TextLabel")
			lbl.Size = UDim2.fromScale(1, 1)
			lbl.BackgroundTransparency = 1
			lbl.Font = Enum.Font.FredokaOne
			lbl.TextScaled = true
			lbl.TextColor3 = Color3.fromRGB(255, 215, 45)
			lbl.TextStrokeTransparency = 0
			lbl.Text = `💥 -{dmg} HP! ({emoji})`
			lbl.Parent = gui
			gui.Parent = host

			TweenService:Create(gui, TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				StudsOffset = Vector3.new(0, 2.4, 0),
			}):Play()
			task.delay(0.68, function()
				if host.Parent then
					host:Destroy()
				end
			end)
		elseif action == "PalayokBreak" then
			SoundController.Play("FiestaFanfare")
			VfxController.ShakeCamera(0.28, 0.8)
			-- Burst flying coins & gems out of the shattered Palayok!
			for i = 1, 16 do
				local isGem = (i % 3 == 0)
				local drop = Instance.new("Part")
				drop.Name = "FiestaLootParticle"
				drop.Shape = if isGem then Enum.PartType.Block else Enum.PartType.Cylinder
				drop.Size = if isGem then Vector3.new(0.85, 0.85, 0.85) else Vector3.new(0.25, 0.95, 0.95)
				drop.Position = pos
				drop.Anchored = true
				drop.CanCollide = false
				drop.CanQuery = false
				drop.Color = if isGem then Color3.fromRGB(0, 240, 255) else Color3.fromRGB(255, 215, 40)
				drop.Material = Enum.Material.Neon
				drop.Parent = workspace

				local angle = (i / 16) * math.pi * 2
				local dist = 5 + math.random() * 8
				local targetPos = Vector3.new(pos.X + math.cos(angle) * dist, pos.Y - 3.2, pos.Z + math.sin(angle) * dist)
				TweenService:Create(drop, TweenInfo.new(0.75, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), {
					Position = targetPos,
				}):Play()
				task.delay(1.3, function()
					if drop.Parent then
						drop:Destroy()
					end
				end)
			end
		elseif action == "BiikTagged" then
			SoundController.Play("BiikSqueal")
			local taggerName = if typeof(arg1) == "string" then arg1 else "Player"
			local pts = if typeof(arg2) == "number" then arg2 else 25
			local emoji = if typeof(arg3) == "string" then arg3 else "🩴"
			local host = Instance.new("Part")
			host.Size = Vector3.new(0.5, 0.5, 0.5)
			host.Position = pos + Vector3.new(0, 2.2, 0)
			host.Anchored = true
			host.Transparency = 1
			host.CanCollide = false
			host.CanQuery = false
			host.Parent = workspace

			local gui = Instance.new("BillboardGui")
			gui.Size = UDim2.fromScale(4.8, 1.35)
			gui.AlwaysOnTop = true
			gui.Adornee = host
			local lbl = Instance.new("TextLabel")
			lbl.Size = UDim2.fromScale(1, 1)
			lbl.BackgroundTransparency = 1
			lbl.Font = Enum.Font.FredokaOne
			lbl.TextScaled = true
			lbl.TextColor3 = Color3.fromRGB(255, 225, 55)
			lbl.TextStrokeTransparency = 0
			lbl.Text = `🐖 +{pts} PTS! ({emoji} {taggerName})`
			lbl.Parent = gui
			gui.Parent = host

			TweenService:Create(gui, TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				StudsOffset = Vector3.new(0, 2.5, 0),
			}):Play()
			task.delay(0.78, function()
				if host.Parent then
					host:Destroy()
				end
			end)
		elseif action == "BoodleEat" then
			SoundController.Play("BoodleEat")
		end
	end)

	-- Street Food Feeding ("Alaga & Pakain") Happy Hop, Heart Burst VFX & Munching SFX!
	Remotes.GetEvent("PetFedVfx").OnClientEvent:Connect(function(_foodId: any, foodEmoji: any, foodName: any)
		SoundController.Play("BoodleEat")
		local emojiStr = if typeof(foodEmoji) == "string" then foodEmoji else "🍡"
		local nameStr = if typeof(foodName) == "string" then foodName else "Street Food"

		local localPlayer = Players.LocalPlayer
		local plots = workspace:FindFirstChild("BasePlots")
		if not plots then
			return
		end

		for _, plot in plots:GetChildren() do
			if plot:IsA("Model") and plot:GetAttribute("OwnerUserId") == localPlayer.UserId then
				local petsFolder = plot:FindFirstChild("Pets")
				if petsFolder then
					for _, petModel in petsFolder:GetChildren() do
						if petModel:IsA("Model") and petModel.PrimaryPart then
							local primary = petModel.PrimaryPart
							local att = Instance.new("Attachment")
							att.Position = Vector3.new(0, 1.5, 0)
							att.Parent = primary

							local heartEmitter = Instance.new("ParticleEmitter")
							heartEmitter.Color = ColorSequence.new(
								Color3.fromRGB(255, 85, 125),
								Color3.fromRGB(255, 215, 65)
							)
							heartEmitter.Size = NumberSequence.new({
								NumberSequenceKeypoint.new(0, 0.45),
								NumberSequenceKeypoint.new(0.7, 0.35),
								NumberSequenceKeypoint.new(1, 0),
							})
							heartEmitter.Lifetime = NumberRange.new(0.6, 1.1)
							heartEmitter.Speed = NumberRange.new(6, 12)
							heartEmitter.SpreadAngle = Vector2.new(180, 75)
							heartEmitter.Rate = 0
							heartEmitter.LightEmission = 0.75
							heartEmitter.Parent = att
							heartEmitter:Emit(16)

							local gui = Instance.new("BillboardGui")
							gui.Name = "BusogHeartPopup"
							gui.Size = UDim2.fromScale(4.2, 1.25)
							gui.StudsOffset = Vector3.new(0, 2.8, 0)
							gui.MaxDistance = 55
							gui.AlwaysOnTop = true
							gui.Adornee = primary

							local lbl = Instance.new("TextLabel")
							lbl.Size = UDim2.fromScale(1, 1)
							lbl.BackgroundTransparency = 1
							lbl.Font = Enum.Font.FredokaOne
							lbl.TextScaled = true
							lbl.TextColor3 = Color3.fromRGB(255, 130, 175)
							lbl.TextStrokeTransparency = 0
							lbl.Text = `❤️ BUSOG! ({emojiStr} {nameStr} +20% $/s)`
							lbl.Parent = gui
							gui.Parent = primary

							TweenService:Create(gui, TweenInfo.new(0.95, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
								StudsOffset = Vector3.new(0, 4.8, 0),
							}):Play()

							task.delay(1.1, function()
								if gui.Parent then
									gui:Destroy()
								end
								if att.Parent then
									att:Destroy()
								end
							end)
						end
					end
				end
			end
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
			local hideLabels = localPlayer:GetAttribute("HidePetLabels") == true
			if plots and cam and not hideLabels then
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
		stepBangkaBoats(now)
		stepTreadmillsAndRunner(dt, now)
		stepCageStruggle(now)
		stepCarriedPanicAndArms(now)
		stepStunnedGuards(now)

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
