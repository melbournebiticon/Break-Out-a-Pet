--!strict
-- DailyPanel.luau (CLIENT)
-- 7-day Daily Rewards modal panel calling the "DailyClaim" RemoteFunction.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EventData = require(Shared:WaitForChild("EventData"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Theme = require(script.Parent:WaitForChild("Theme"))
local Toasts = require(script.Parent:WaitForChild("Toasts"))
local SoundController = require(script.Parent.Parent:WaitForChild("SoundController"))

local DailyPanel = {}

local modalFrame: Frame

function DailyPanel.SetVisible(visible: boolean)
	if modalFrame then
		modalFrame.Visible = visible
	end
end

function DailyPanel.IsVisible(): boolean
	return if modalFrame then modalFrame.Visible else false
end

function DailyPanel.Init(screenGui: ScreenGui, onClose: () -> ())
	local player = Players.LocalPlayer
	local claimFn = Remotes.GetFunction("DailyClaim")

	local modal, content = Theme.MakeModalShell(screenGui, "🎁 DAILY REWARDS", onClose)
	modalFrame = modal

	local gridFrame = Instance.new("Frame")
	gridFrame.Size = UDim2.new(1, 0, 1, -66)
	gridFrame.BackgroundTransparency = 1
	gridFrame.Parent = content

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(128, 95)
	grid.CellPadding = UDim2.fromOffset(10, 10)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = gridFrame

	local claimBtn = Theme.MakeButton(
		"ClaimBtn",
		"🎁 Claim Today's Reward!",
		UDim2.fromOffset(250, 48),
		UDim2.new(0.5, -125, 1, -50),
		Theme.AccentGreen,
		content,
		function()
			local res = claimFn:InvokeServer()
			if typeof(res) == "table" then
				if res.Ok then
					SoundController.Play("Purchase")
					Toasts.Show(tostring(res.Message), Theme.AccentGold)
				else
					Toasts.Show(tostring(res.Message), Theme.AccentRed)
				end
			end
		end
	)

	local function rebuild()
		for _, child in gridFrame:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end

		local streakAttr = player:GetAttribute("DailyStreak")
		local streak = if typeof(streakAttr) == "number" then streakAttr else 0

		for _, entry in EventData.DailyRewards do
			local claimed = entry.Day <= streak
			local card = Theme.MakeFrame(`Day{entry.Day}`, UDim2.fromOffset(128, 95), UDim2.fromScale(0, 0), Theme.BgCard, 12, gridFrame)
			card.LayoutOrder = entry.Day
			Theme.AddStroke(card, if claimed then Theme.AccentGreen else Theme.AccentGold, 2)

			Theme.MakeLabel("Day", `DAY {entry.Day}`, UDim2.fromScale(0.9, 0.28), UDim2.fromScale(0.05, 0.08), Theme.FontTitle, Theme.AccentGold, card)
			Theme.MakeLabel("Reward", entry.Label, UDim2.fromScale(0.9, 0.34), UDim2.fromScale(0.05, 0.38), Theme.FontTitle, Theme.TextPrimary, card)
			Theme.MakeLabel("Status", if claimed then "✅ CLAIMED" else "🎁 READY", UDim2.fromScale(0.9, 0.22), UDim2.fromScale(0.05, 0.73), Theme.FontBody, if claimed then Theme.AccentGreen else Theme.TextMuted, card)
		end

		local lastDayAttr = player:GetAttribute("LastDailyClaimDay")
		local lastDay = if typeof(lastDayAttr) == "number" then lastDayAttr else 0
		local today = math.floor(os.time() / 86400)
		if lastDay == today then
			claimBtn.Text = "✅ Claimed Today (Come back tomorrow)"
			claimBtn.BackgroundColor3 = Theme.BgHeader
		else
			claimBtn.Text = "🎁 Claim Today's Reward!"
			claimBtn.BackgroundColor3 = Theme.AccentGreen
		end
	end

	player:GetAttributeChangedSignal("DailyStreak"):Connect(rebuild)
	player:GetAttributeChangedSignal("LastDailyClaimDay"):Connect(rebuild)
	rebuild()
end

return DailyPanel
