--!strict
-- ShopPanel.luau (CLIENT)
-- Modal panel with Speed Upgrade, Pet Slot unlock, and optional Robux passes/products (when configured > 0).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local ShopData = require(Shared:WaitForChild("ShopData"))
local Monetization = require(Shared:WaitForChild("Monetization"))
local NumberFormat = require(Shared:WaitForChild("NumberFormat"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Theme = require(script.Parent:WaitForChild("Theme"))
local Toasts = require(script.Parent:WaitForChild("Toasts"))
local SoundController = require(script.Parent.Parent:WaitForChild("SoundController"))

local ShopPanel = {}

local modalFrame: Frame

function ShopPanel.SetVisible(visible: boolean)
	if modalFrame then
		modalFrame.Visible = visible
	end
end

function ShopPanel.IsVisible(): boolean
	return if modalFrame then modalFrame.Visible else false
end

function ShopPanel.Init(screenGui: ScreenGui, onClose: () -> ())
	local player = Players.LocalPlayer
	local shopFn = Remotes.GetFunction("ShopRequest")
	local promptPurchaseEvent = Remotes.GetEvent("PromptPurchase")

	local modal, content = Theme.MakeModalShell(screenGui, "🛒 UPGRADE SHOP", onClose)
	modalFrame = modal

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Cards"
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.fromOffset(0, 0)
	scroll.Parent = content

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 12)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = scroll

	-- 1) Speed Upgrade Card
	local speedCard = Theme.MakeFrame("SpeedCard", UDim2.new(1, -8, 0, 96), UDim2.fromScale(0, 0), Theme.BgCard, 12, scroll)
	speedCard.LayoutOrder = 1
	Theme.AddStroke(speedCard, Theme.AccentBlue, 2)

	local speedTitle = Theme.MakeLabel("Title", "⚡ Walk Speed Upgrade", UDim2.new(0.62, 0, 0, 32), UDim2.fromOffset(14, 12), Theme.FontTitle, Theme.TextPrimary, speedCard)
	speedTitle.TextXAlignment = Enum.TextXAlignment.Left
	local speedDesc = Theme.MakeLabel("Desc", "", UDim2.new(0.62, 0, 0, 26), UDim2.fromOffset(14, 50), Theme.FontBody, Theme.TextMuted, speedCard)
	speedDesc.TextXAlignment = Enum.TextXAlignment.Left

	local speedBtn = Theme.MakeButton("BuySpeed", "Buy", UDim2.fromOffset(145, 50), UDim2.new(1, -160, 0.5, -25), Theme.AccentGreen, speedCard, function()
		local res = shopFn:InvokeServer("BuySpeed")
		if typeof(res) == "table" then
			if res.Ok then
				SoundController.Play("Purchase")
				Toasts.Show(tostring(res.Message), Theme.AccentGreen)
			else
				Toasts.Show(tostring(res.Message), Theme.AccentRed)
			end
		end
	end)

	-- 2) Pet Slot Card
	local slotCard = Theme.MakeFrame("SlotCard", UDim2.new(1, -8, 0, 96), UDim2.fromScale(0, 0), Theme.BgCard, 12, scroll)
	slotCard.LayoutOrder = 2
	Theme.AddStroke(slotCard, Theme.AccentPurple, 2)

	local slotTitle = Theme.MakeLabel("Title", "🏠 Extra Base Pet Slot", UDim2.new(0.62, 0, 0, 32), UDim2.fromOffset(14, 12), Theme.FontTitle, Theme.TextPrimary, slotCard)
	slotTitle.TextXAlignment = Enum.TextXAlignment.Left
	local slotDesc = Theme.MakeLabel("Desc", "", UDim2.new(0.62, 0, 0, 26), UDim2.fromOffset(14, 50), Theme.FontBody, Theme.TextMuted, slotCard)
	slotDesc.TextXAlignment = Enum.TextXAlignment.Left

	local slotBtn = Theme.MakeButton("BuySlot", "Buy", UDim2.fromOffset(145, 50), UDim2.new(1, -160, 0.5, -25), Theme.AccentGreen, slotCard, function()
		local res = shopFn:InvokeServer("BuySlot")
		if typeof(res) == "table" then
			if res.Ok then
				SoundController.Play("Purchase")
				Toasts.Show(tostring(res.Message), Theme.AccentGreen)
			else
				Toasts.Show(tostring(res.Message), Theme.AccentRed)
			end
		end
	end)

	-- Optional Robux GamePasses / Products (only shown when ID > 0)
	local orderIdx = 3
	for key, passInfo in Monetization.GamePasses do
		if passInfo.Id > 0 then
			orderIdx += 1
			local card = Theme.MakeFrame(`Pass_{key}`, UDim2.new(1, -8, 0, 86), UDim2.fromScale(0, 0), Theme.BgCard, 12, scroll)
			card.LayoutOrder = orderIdx
			Theme.AddStroke(card, Theme.AccentGold, 2)

			local t = Theme.MakeLabel("Title", `⭐ [PASS] {passInfo.Name}`, UDim2.new(0.62, 0, 0, 28), UDim2.fromOffset(14, 10), Theme.FontTitle, Theme.AccentGold, card)
			t.TextXAlignment = Enum.TextXAlignment.Left
			local d = Theme.MakeLabel("Desc", passInfo.Description, UDim2.new(0.62, 0, 0, 24), UDim2.fromOffset(14, 44), Theme.FontBody, Theme.TextMuted, card)
			d.TextXAlignment = Enum.TextXAlignment.Left

			Theme.MakeButton("Buy", "Robux", UDim2.fromOffset(145, 46), UDim2.new(1, -160, 0.5, -23), Theme.AccentGold, card, function()
				promptPurchaseEvent:FireServer("GamePass", passInfo.Id)
			end)
		end
	end

	for key, prodInfo in Monetization.Products do
		if prodInfo.Id > 0 then
			orderIdx += 1
			local card = Theme.MakeFrame(`Prod_{key}`, UDim2.new(1, -8, 0, 86), UDim2.fromScale(0, 0), Theme.BgCard, 12, scroll)
			card.LayoutOrder = orderIdx
			Theme.AddStroke(card, Theme.AccentGold, 2)

			local t = Theme.MakeLabel("Title", `💎 {prodInfo.Name}`, UDim2.new(0.62, 0, 0, 28), UDim2.fromOffset(14, 10), Theme.FontTitle, Theme.AccentGold, card)
			t.TextXAlignment = Enum.TextXAlignment.Left
			local d = Theme.MakeLabel("Desc", prodInfo.Description, UDim2.new(0.62, 0, 0, 24), UDim2.fromOffset(14, 44), Theme.FontBody, Theme.TextMuted, card)
			d.TextXAlignment = Enum.TextXAlignment.Left

			Theme.MakeButton("Buy", "Robux", UDim2.fromOffset(145, 46), UDim2.new(1, -160, 0.5, -23), Theme.AccentGold, card, function()
				promptPurchaseEvent:FireServer("Product", prodInfo.Id)
			end)
		end
	end

	local function refresh()
		local moneyAttr = player:GetAttribute("Money")
		local money = if typeof(moneyAttr) == "number" then moneyAttr else 0

		local speedLvlAttr = player:GetAttribute("SpeedLevel")
		local speedLvl = if typeof(speedLvlAttr) == "number" then speedLvlAttr else 0
		local tierInfo = ShopData.GetTreadmillTierInfo(speedLvl)
		local currentGain = ShopData.GetTrainerGainPerSec(speedLvl)
		local speedPrice = ShopData.GetSpeedPrice(speedLvl)

		speedTitle.Text = `🏃 {tierInfo.Name} (Tier {speedLvl}/{ShopData.Speed.MaxLevel})`
		speedDesc.Text = string.format("Treadmill Gain: +%.2f Speed/sec  (+%.2f/s per tier)", currentGain, ShopData.Speed.GainPerLevel)
		if not speedPrice then
			speedBtn.Text = "MAXED"
			speedBtn.BackgroundColor3 = Theme.BgHeader
			speedBtn.Active = false
		else
			speedBtn.Text = `Buy {NumberFormat.Short(speedPrice)}`
			local canAfford = money >= speedPrice
			speedBtn.BackgroundColor3 = if canAfford then Theme.AccentGreen else Theme.BgHeader
			speedBtn.Active = canAfford
		end

		local slotsAttr = player:GetAttribute("PetSlots")
		local slots = if typeof(slotsAttr) == "number" then slotsAttr else Config.StartingPetSlots
		local slotPrice = ShopData.GetSlotPrice(slots)

		slotTitle.Text = `🏠 Base Pet Slots ({slots}/{Config.MaxPetSlots})`
		slotDesc.Text = "Place more Money & Hybrid pets on your plot!"
		if not slotPrice or slots >= Config.MaxPetSlots then
			slotBtn.Text = "MAXED"
			slotBtn.BackgroundColor3 = Theme.BgHeader
			slotBtn.Active = false
		else
			slotBtn.Text = `Buy $${NumberFormat.Short(slotPrice)}`
			local canAfford = money >= slotPrice
			slotBtn.BackgroundColor3 = if canAfford then Theme.AccentGreen else Theme.BgHeader
			slotBtn.Active = canAfford
		end
	end

	player:GetAttributeChangedSignal("Money"):Connect(refresh)
	player:GetAttributeChangedSignal("SpeedLevel"):Connect(refresh)
	player:GetAttributeChangedSignal("PetSlots"):Connect(refresh)
	refresh()
end

return ShopPanel
