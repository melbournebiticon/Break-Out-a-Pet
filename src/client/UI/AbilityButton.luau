--!strict
-- AbilityButton.luau (CLIENT)
-- Bottom-right Equipped Skill HUD Card + Q shortcut with 3D Pet preview, skill description, and cooldown timer.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PetData = require(Shared:WaitForChild("PetData"))
local PetVisuals = require(Shared:WaitForChild("PetVisuals"))
local PamaloConfig = require(Shared:WaitForChild("PamaloConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Theme = require(script.Parent:WaitForChild("Theme"))
local Toasts = require(script.Parent:WaitForChild("Toasts"))
local SoundController = require(script.Parent.Parent:WaitForChild("SoundController"))

local AbilityButton = {}

function AbilityButton.Init(screenGui: ScreenGui)
	local player = Players.LocalPlayer
	local useAbilityEvent = Remotes.GetEvent("UseAbility")
	local sipatEvent = Remotes.GetEvent("PamaloSipat")

	local btn = Instance.new("TextButton")
	btn.Name = "AbilityButton"
	btn.Size = UDim2.fromOffset(186, 54)
	btn.Position = UDim2.new(1, -14, 1, -14)
	btn.AnchorPoint = Vector2.new(1, 1)
	btn.BackgroundColor3 = Color3.fromRGB(24, 28, 38)
	btn.BackgroundTransparency = 0.08
	btn.BorderSizePixel = 0
	btn.Text = ""
	btn.Visible = false
	Theme.AddCorner(btn, 12)
	local cardStroke = Theme.AddStroke(btn, Theme.AccentGold, 2.5)
	btn.Parent = screenGui

	-- Keep the Active/Passive Skill Card in the Bottom-Right (cleanly between SideMenu and Mobile Jump Button on CP!)
	Theme.BindResponsiveScale(btn, 0.72, function(isCompact: boolean)
		btn.AnchorPoint = Vector2.new(1, 1)
		if isCompact then
			btn.Position = UDim2.new(1, -10, 1, -108)
		else
			btn.Position = UDim2.new(1, -14, 1, -14)
		end
	end)

	local iconHolder = Instance.new("Frame")
	iconHolder.Name = "IconHolder"
	iconHolder.Size = UDim2.fromOffset(46, 46)
	iconHolder.Position = UDim2.fromOffset(5, 6)
	iconHolder.BackgroundTransparency = 1
	iconHolder.Parent = btn

	local titleLabel = Theme.MakeLabel(
		"Title",
		"⚡ ACTIVE SKILL [Q]",
		UDim2.new(1, -58, 0, 18),
		UDim2.fromOffset(54, 4),
		Theme.FontTitle,
		Theme.AccentGold,
		btn
	)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left

	local descLabel = Theme.MakeLabel(
		"Desc",
		"Press Q or Tap to activate skill!",
		UDim2.new(1, -58, 0, 32),
		UDim2.fromOffset(54, 22),
		Theme.FontBody,
		Color3.fromRGB(225, 232, 245),
		btn
	)
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.TextWrapped = true

	local isPassive = false
	local currentPetName = ""
	local currentDesc = ""

	local function triggerAbility()
		if not btn.Visible then
			return
		end
		if isPassive then
			Toasts.Show(`✨ {currentPetName}: {currentDesc} (Always Active!)`, Theme.AccentGreen)
			return
		end
		local readyAtAttr = player:GetAttribute("AbilityReadyAt")
		local readyAt = if typeof(readyAtAttr) == "number" then readyAtAttr else 0
		if workspace:GetServerTimeNow() < readyAt then
			return
		end
		SoundController.Play("AbilityUse")
		useAbilityEvent:FireServer()
	end

	btn.Activated:Connect(triggerAbility)

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Q then
			triggerAbility()
		end
	end)

	local function refreshEquipped()
		local petId = player:GetAttribute("EquippedPetId")
		if typeof(petId) ~= "string" or petId == "" then
			btn.Visible = false
			return
		end
		local pet = PetData.Get(petId)
		if not pet or not pet.Ability then
			btn.Visible = false
			return
		end

		btn.Visible = true
		currentPetName = pet.DisplayName
		currentDesc = pet.Ability.Description

		for _, child in iconHolder:GetChildren() do
			child:Destroy()
		end
		PetVisuals.MountViewport(iconHolder, pet.Id, nil, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0))

		isPassive = pet.Ability.Duration <= 0 and pet.Ability.Cooldown <= 0
		descLabel.Text = pet.Ability.Description
		if isPassive then
			titleLabel.Text = `✨ {pet.DisplayName} [PASSIVE]`
			titleLabel.TextColor3 = Theme.AccentGreen
			cardStroke.Color = Theme.AccentGreen
		elseif pet.Ability.AbilityId == "revive" then
			isPassive = true
			titleLabel.Text = `🛡️ {pet.DisplayName} [AUTO]`
			titleLabel.TextColor3 = Color3.fromRGB(95, 220, 255)
			cardStroke.Color = Color3.fromRGB(95, 220, 255)
		else
			titleLabel.Text = `⚡ {pet.DisplayName} [Press Q]`
			titleLabel.TextColor3 = Theme.AccentGold
			cardStroke.Color = Theme.AccentGold
		end
	end

	player:GetAttributeChangedSignal("EquippedPetId"):Connect(refreshEquipped)
	refreshEquipped()

	-- SECONDARY RANGED TSINELAS THROW ("SIPAT") ACTION BUTTON + RIGHT-CLICK / R KEYBIND
	local sipatBtn = Instance.new("TextButton")
	sipatBtn.Name = "SipatThrowButton"
	sipatBtn.Size = UDim2.fromOffset(186, 44)
	sipatBtn.Position = UDim2.new(1, -14, 1, -74)
	sipatBtn.AnchorPoint = Vector2.new(1, 1)
	sipatBtn.BackgroundColor3 = Color3.fromRGB(28, 34, 48)
	sipatBtn.BackgroundTransparency = 0.08
	sipatBtn.BorderSizePixel = 0
	sipatBtn.Text = ""
	sipatBtn.Visible = false
	Theme.AddCorner(sipatBtn, 12)
	local sipatStroke = Theme.AddStroke(sipatBtn, Theme.AccentBlue, 2.2)
	sipatBtn.Parent = screenGui

	local function updateSipatLayout(isCompact: boolean)
		sipatBtn.AnchorPoint = Vector2.new(1, 1)
		local skillOffset = if btn.Visible then (if isCompact then 44 else 60) else 0
		if isCompact then
			sipatBtn.Position = UDim2.new(1, -10, 1, -108 - skillOffset)
		else
			sipatBtn.Position = UDim2.new(1, -14, 1, -14 - skillOffset)
		end
	end

	Theme.BindResponsiveScale(sipatBtn, 0.72, updateSipatLayout)
	btn:GetPropertyChangedSignal("Visible"):Connect(function()
		updateSipatLayout(Theme.IsCompactScreen())
	end)

	local sipatIconHolder = Instance.new("Frame")
	sipatIconHolder.Name = "IconHolder"
	sipatIconHolder.Size = UDim2.fromOffset(38, 38)
	sipatIconHolder.Position = UDim2.fromOffset(5, 3)
	sipatIconHolder.BackgroundTransparency = 1
	sipatIconHolder.Parent = sipatBtn

	local sipatTitleLbl = Theme.MakeLabel(
		"Title",
		"🩴 SIPAT THROW [R / RMB]",
		UDim2.new(1, -50, 0, 18),
		UDim2.fromOffset(46, 4),
		Theme.FontTitle,
		Theme.AccentGold,
		sipatBtn
	)
	sipatTitleLbl.TextXAlignment = Enum.TextXAlignment.Left

	local sipatDescLbl = Theme.MakeLabel(
		"Desc",
		"Boomerang Tsinelas stuns Bantay!",
		UDim2.new(1, -50, 0, 18),
		UDim2.fromOffset(46, 22),
		Theme.FontBody,
		Color3.fromRGB(215, 228, 245),
		sipatBtn
	)
	sipatDescLbl.TextXAlignment = Enum.TextXAlignment.Left

	local currentPamaloId = ""
	local rightMouseDownAt = 0
	local rightMouseDownPos = Vector2.zero

	local function getActiveTsinelasId(): string?
		local attrId = player:GetAttribute("EquippedPamaloId")
		if typeof(attrId) == "string" and PamaloConfig.GetSipat(attrId) ~= nil then
			return attrId
		end
		local character = player.Character
		local backpack = player:FindFirstChildOfClass("Backpack")
		for _, container in { character, backpack } do
			if container then
				for _, child in container:GetChildren() do
					if child:IsA("Tool") and child:GetAttribute("IsPamalo") == true then
						local pid = tostring(child:GetAttribute("PamaloId") or "")
						if PamaloConfig.GetSipat(pid) ~= nil then
							return pid
						end
					end
				end
			end
		end
		return nil
	end

	local function isHoldingTsinelasToolInHand(): boolean
		local character = player.Character
		if not character then
			return false
		end
		for _, child in character:GetChildren() do
			if child:IsA("Tool") and child:GetAttribute("IsPamalo") == true then
				local pid = tostring(child:GetAttribute("PamaloId") or "")
				if PamaloConfig.GetSipat(pid) ~= nil then
					return true
				end
			end
		end
		return false
	end

	local function computeAimDirection(): Vector3
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local cam = workspace.CurrentCamera
		if root and root:IsA("BasePart") then
			if cam then
				local camLook = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z)
				if camLook.Magnitude > 0.05 then
					return camLook.Unit
				end
			end
			local flat = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
			if flat.Magnitude > 0.05 then
				return flat.Unit
			end
		end
		return Vector3.new(0, 0, -1)
	end

	local function triggerSipat()
		local tsinelasId = getActiveTsinelasId()
		if not tsinelasId then
			return
		end
		local readyAtAttr = player:GetAttribute("SipatReadyAt")
		local readyAt = if typeof(readyAtAttr) == "number" then readyAtAttr else 0
		if workspace:GetServerTimeNow() < readyAt then
			return
		end
		SoundController.Play("SipatThrow")
		sipatEvent:FireServer(computeAimDirection())
	end

	sipatBtn.Activated:Connect(triggerSipat)

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			rightMouseDownAt = os.clock()
			rightMouseDownPos = Vector2.new(input.Position.X, input.Position.Y)
		end
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.R then
			triggerSipat()
		end
	end)

	UserInputService.InputEnded:Connect(function(input: InputObject, _gameProcessed: boolean)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			local heldSec = os.clock() - rightMouseDownAt
			local movedDist = (Vector2.new(input.Position.X, input.Position.Y) - rightMouseDownPos).Magnitude
			-- Quick right-click (not camera pan drag) while holding Tsinelas throws Sipat!
			if heldSec <= 0.25 and movedDist <= 8 and isHoldingTsinelasToolInHand() then
				triggerSipat()
			end
		end
	end)

	local function refreshSipatButton()
		local tsinelasId = getActiveTsinelasId()
		if not tsinelasId then
			sipatBtn.Visible = false
			currentPamaloId = ""
			return
		end
		sipatBtn.Visible = true
		updateSipatLayout(Theme.IsCompactScreen())
		if tsinelasId ~= currentPamaloId then
			currentPamaloId = tsinelasId
			for _, child in sipatIconHolder:GetChildren() do
				child:Destroy()
			end
			PamaloConfig.MountViewport(sipatIconHolder, tsinelasId, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0))
		end
	end

	player:GetAttributeChangedSignal("EquippedPamaloId"):Connect(refreshSipatButton)
	task.defer(refreshSipatButton)

	RunService.Heartbeat:Connect(function()
		refreshSipatButton()
		local now = workspace:GetServerTimeNow()

		if sipatBtn.Visible then
			local sipatReadyAttr = player:GetAttribute("SipatReadyAt")
			local sipatReadyAt = if typeof(sipatReadyAttr) == "number" then sipatReadyAttr else 0
			local info = PamaloConfig.Get(currentPamaloId)
			local isGold = currentPamaloId == "gintong_tsinelas"
			local baseColor = if isGold then Theme.AccentGold else Theme.AccentBlue
			if now < sipatReadyAt then
				sipatTitleLbl.Text = `⏳ Sipat ({math.ceil(sipatReadyAt - now)}s)`
				sipatTitleLbl.TextColor3 = Theme.TextMuted
				sipatStroke.Color = Theme.TextMuted
			else
				local shortName = if info and isGold then "Gintong Sipat" else "Sipat Tsinelas"
				sipatTitleLbl.Text = `🩴 {shortName} [R / RMB]`
				sipatTitleLbl.TextColor3 = baseColor
				sipatStroke.Color = baseColor
			end
		end

		if not btn.Visible or isPassive then
			return
		end
		local activeUntilAttr = player:GetAttribute("AbilityActiveUntil")
		local readyAtAttr = player:GetAttribute("AbilityReadyAt")
		local activeUntil = if typeof(activeUntilAttr) == "number" then activeUntilAttr else 0
		local readyAt = if typeof(readyAtAttr) == "number" then readyAtAttr else 0

		if now < activeUntil then
			titleLabel.Text = `⚡ ACTIVE ({math.ceil(activeUntil - now)}s)`
			titleLabel.TextColor3 = Theme.AccentGreen
			cardStroke.Color = Theme.AccentGreen
		elseif now < readyAt then
			titleLabel.Text = `⏳ Cooldown ({math.ceil(readyAt - now)}s)`
			titleLabel.TextColor3 = Theme.TextMuted
			cardStroke.Color = Theme.TextMuted
		else
			titleLabel.Text = `⚡ {currentPetName} [Press Q]`
			titleLabel.TextColor3 = Theme.AccentGold
			cardStroke.Color = Theme.AccentGold
		end
	end)
end

return AbilityButton
