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
local Remotes = require(Shared:WaitForChild("Remotes"))
local Theme = require(script.Parent:WaitForChild("Theme"))
local Toasts = require(script.Parent:WaitForChild("Toasts"))
local SoundController = require(script.Parent.Parent:WaitForChild("SoundController"))

local AbilityButton = {}

function AbilityButton.Init(screenGui: ScreenGui)
	local player = Players.LocalPlayer
	local useAbilityEvent = Remotes.GetEvent("UseAbility")

	local btn = Instance.new("TextButton")
	btn.Name = "AbilityButton"
	btn.Size = UDim2.fromOffset(228, 66)
	btn.Position = UDim2.new(1, -12, 1, -12)
	btn.AnchorPoint = Vector2.new(1, 1)
	btn.BackgroundColor3 = Color3.fromRGB(24, 28, 38)
	btn.BackgroundTransparency = 0.08
	btn.BorderSizePixel = 0
	btn.Text = ""
	btn.Visible = false
	Theme.AddCorner(btn, 12)
	local cardStroke = Theme.AddStroke(btn, Theme.AccentGold, 2.5)
	btn.Parent = screenGui

	local iconHolder = Instance.new("Frame")
	iconHolder.Name = "IconHolder"
	iconHolder.Size = UDim2.fromOffset(52, 52)
	iconHolder.Position = UDim2.fromOffset(6, 7)
	iconHolder.BackgroundTransparency = 1
	iconHolder.Parent = btn

	local titleLabel = Theme.MakeLabel(
		"Title",
		"⚡ ACTIVE SKILL [Q]",
		UDim2.new(1, -66, 0, 20),
		UDim2.fromOffset(62, 5),
		Theme.FontTitle,
		Theme.AccentGold,
		btn
	)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left

	local descLabel = Theme.MakeLabel(
		"Desc",
		"Press Q or Tap to activate skill!",
		UDim2.new(1, -66, 0, 34),
		UDim2.fromOffset(62, 26),
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

	RunService.Heartbeat:Connect(function()
		if not btn.Visible or isPassive then
			return
		end
		local now = workspace:GetServerTimeNow()
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
