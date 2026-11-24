--!strict
-- AbilityButton.luau (CLIENT)
-- Bottom-right circular ability button + Q shortcut with server-synced cooldown countdown.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PetData = require(Shared:WaitForChild("PetData"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Theme = require(script.Parent:WaitForChild("Theme"))
local SoundController = require(script.Parent.Parent:WaitForChild("SoundController"))

local AbilityButton = {}

function AbilityButton.Init(screenGui: ScreenGui)
	local player = Players.LocalPlayer
	local useAbilityEvent = Remotes.GetEvent("UseAbility")

	local btn = Instance.new("TextButton")
	btn.Name = "AbilityButton"
	btn.Size = UDim2.fromOffset(68, 68)
	btn.Position = UDim2.new(1, -126, 1, -18)
	btn.AnchorPoint = Vector2.new(1, 1)
	btn.BackgroundColor3 = Theme.BgCard
	btn.BorderSizePixel = 0
	btn.Text = ""
	btn.Visible = false
	Theme.AddCorner(btn, 34)
	Theme.AddStroke(btn, Theme.AccentGold, 3)
	btn.Parent = screenGui

	local emojiLabel = Theme.MakeLabel("Emoji", "🦊", UDim2.fromScale(0.75, 0.55), UDim2.fromScale(0.125, 0.08), Theme.FontTitle, Theme.TextPrimary, btn)
	local stateLabel = Theme.MakeLabel("State", "Q / TAP", UDim2.fromScale(0.86, 0.28), UDim2.fromScale(0.07, 0.64), Theme.FontTitle, Theme.AccentGold, btn)

	local isPassive = false

	local function triggerAbility()
		if not btn.Visible or isPassive then
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
		emojiLabel.Text = pet.Emoji
		isPassive = pet.Ability.Duration <= 0 and pet.Ability.Cooldown <= 0
		if isPassive then
			stateLabel.Text = "PASSIVE"
			stateLabel.TextColor3 = Theme.AccentGreen
		else
			stateLabel.Text = "Q / TAP"
			stateLabel.TextColor3 = Theme.AccentGold
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
			stateLabel.Text = `ACTIVE {math.ceil(activeUntil - now)}s`
			stateLabel.TextColor3 = Theme.AccentGreen
		elseif now < readyAt then
			stateLabel.Text = `{math.ceil(readyAt - now)}s`
			stateLabel.TextColor3 = Theme.TextMuted
		else
			stateLabel.Text = "Q / TAP"
			stateLabel.TextColor3 = Theme.AccentGold
		end
	end)
end

return AbilityButton
