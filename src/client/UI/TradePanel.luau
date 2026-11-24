--!strict
-- TradePanel.luau (CLIENT)
-- Player list for sending trade invites + 2-column live trade session window with 3s anti-scam countdown.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PetData = require(Shared:WaitForChild("PetData"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Theme = require(script.Parent:WaitForChild("Theme"))
local Toasts = require(script.Parent:WaitForChild("Toasts"))
local InventoryPanel = require(script.Parent:WaitForChild("InventoryPanel"))

local TradePanel = {}

local modalFrame: Frame
local activeSession: any = nil
local pendingInviteFrom: { UserId: number, Name: string }? = nil
local renderFn: (() -> ())? = nil

function TradePanel.SetVisible(visible: boolean)
	if modalFrame then
		modalFrame.Visible = visible
		if visible and renderFn then
			renderFn()
		end
	end
end

function TradePanel.IsVisible(): boolean
	return if modalFrame then modalFrame.Visible else false
end

function TradePanel.Init(screenGui: ScreenGui, onClose: () -> (), onOpenRequest: () -> ())
	local localPlayer = Players.LocalPlayer
	local tradeFn = Remotes.GetFunction("TradeRequest")
	local tradeUpdate = Remotes.GetEvent("TradeUpdate")

	local modal, content = Theme.MakeModalShell(screenGui, "🤝 PET TRADING", function()
		if activeSession then
			tradeFn:InvokeServer("Cancel")
			activeSession = nil
		end
		onClose()
	end)
	modalFrame = modal

	local confirmBtnRef: TextButton? = nil

	local function render()
		content:ClearAllChildren()
		confirmBtnRef = nil

		-- 1) Active Trade Session View
		if activeSession then
			Theme.MakeLabel(
				"Header",
				`Trading with {activeSession.PartnerName}`,
				UDim2.new(1, 0, 0, 26),
				UDim2.fromOffset(0, 0),
				Theme.FontTitle,
				Theme.AccentGold,
				content
			)

			local myBox = Theme.MakeFrame("MyOffer", UDim2.new(0.48, 0, 0, 105), UDim2.fromOffset(0, 30), Theme.BgCard, 10, content)
			Theme.AddStroke(myBox, if activeSession.MyAccepted then Theme.AccentGreen else Theme.BgHeader, 2)
			Theme.MakeLabel("Title", if activeSession.MyAccepted then "YOUR OFFER (✅ READY)" else "YOUR OFFER", UDim2.new(1, 0, 0, 22), UDim2.fromOffset(0, 2), Theme.FontTitle, Theme.TextPrimary, myBox)

			local theirBox = Theme.MakeFrame("TheirOffer", UDim2.new(0.48, 0, 0, 105), UDim2.new(0.52, 0, 0, 30), Theme.BgCard, 10, content)
			Theme.AddStroke(theirBox, if activeSession.TheirAccepted then Theme.AccentGreen else Theme.BgHeader, 2)
			Theme.MakeLabel("Title", if activeSession.TheirAccepted then "THEIR OFFER (✅ READY)" else "THEIR OFFER", UDim2.new(1, 0, 0, 22), UDim2.fromOffset(0, 2), Theme.FontTitle, Theme.TextPrimary, theirBox)

			local function populateOfferBox(box: Frame, list: { any })
				local textParts = {}
				for _, item in list do
					local info = PetData.Get(item.PetId)
					if info then
						local mut = if item.Mutation then `[{item.Mutation}] ` else ""
						table.insert(textParts, `{info.Emoji} {mut}{info.DisplayName}`)
					end
				end
				local str = if #textParts > 0 then table.concat(textParts, "\n") else "(No pets added)"
				Theme.MakeLabel("Items", str, UDim2.new(0.92, 0, 0, 74), UDim2.fromOffset(8, 26), Theme.FontBody, Theme.TextPrimary, box)
			end

			populateOfferBox(myBox, activeSession.MyOffer or {})
			populateOfferBox(theirBox, activeSession.TheirOffer or {})

			-- Stored inventory picker
			local invScroll = Instance.new("ScrollingFrame")
			invScroll.Size = UDim2.new(1, 0, 1, -195)
			invScroll.Position = UDim2.fromOffset(0, 142)
			invScroll.BackgroundTransparency = 1
			invScroll.BorderSizePixel = 0
			invScroll.ScrollBarThickness = 5
			invScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
			invScroll.CanvasSize = UDim2.fromOffset(0, 0)
			invScroll.Parent = content

			local grid = Instance.new("UIGridLayout")
			grid.CellSize = UDim2.fromOffset(125, 44)
			grid.CellPadding = UDim2.fromOffset(6, 6)
			grid.Parent = invScroll

			local offeredMap: { [string]: boolean } = {}
			for _, o in activeSession.MyOffer or {} do
				offeredMap[o.Uid] = true
			end

			for _, pet in InventoryPanel.GetPets() do
				if pet.State == "Stored" and not pet.Equipped then
					local info = PetData.Get(pet.PetId)
					if info then
						local inOffer = offeredMap[pet.Uid] == true
						Theme.MakeButton(
							pet.Uid,
							`{info.Emoji} {info.DisplayName}`,
							UDim2.fromOffset(125, 44),
							UDim2.fromScale(0, 0),
							if inOffer then Theme.AccentPurple else Theme.BgCard,
							invScroll,
							function()
								local res = tradeFn:InvokeServer("TogglePet", pet.Uid)
								if typeof(res) == "table" and not res.Ok then
									Toasts.Show(tostring(res.Message), Theme.AccentRed)
								end
							end
						)
					end
				end
			end

			if not (activeSession.MyAccepted and activeSession.TheirAccepted) then
				Theme.MakeButton(
					"AcceptBtn",
					if activeSession.MyAccepted then "Waiting for Partner..." else "✅ Accept Offer",
					UDim2.fromOffset(180, 42),
					UDim2.new(0.25, -90, 1, -44),
					Theme.AccentGreen,
					content,
					function()
						local res = tradeFn:InvokeServer("AcceptOffer")
						if typeof(res) == "table" and not res.Ok then
							Toasts.Show(tostring(res.Message), Theme.AccentRed)
						end
					end
				)
			else
				confirmBtnRef = Theme.MakeButton(
					"ConfirmBtn",
					if activeSession.MyConfirmed then "Confirmed!" else "🤝 Confirm Trade",
					UDim2.fromOffset(180, 42),
					UDim2.new(0.25, -90, 1, -44),
					Theme.AccentGold,
					content,
					function()
						local res = tradeFn:InvokeServer("ConfirmTrade")
						if typeof(res) == "table" and not res.Ok then
							Toasts.Show(tostring(res.Message), Theme.AccentRed)
						end
					end
				)
			end

			Theme.MakeButton("CancelBtn", "Cancel Trade", UDim2.fromOffset(150, 42), UDim2.new(0.75, -75, 1, -44), Theme.AccentRed, content, function()
				tradeFn:InvokeServer("Cancel")
			end)
			return
		end

		-- 2) Pending Invite Prompt + Player List
		local topOffset = 0
		if pendingInviteFrom then
			local inv = pendingInviteFrom
			local banner = Theme.MakeFrame("InviteBox", UDim2.new(1, 0, 0, 52), UDim2.fromOffset(0, 0), Theme.BgCard, 10, content)
			Theme.AddStroke(banner, Theme.AccentGold, 2)
			Theme.MakeLabel("Text", `🤝 {inv.Name} invited you to trade!`, UDim2.new(0.6, 0, 0.8, 0), UDim2.fromOffset(12, 5), Theme.FontTitle, Theme.AccentGold, banner)
			Theme.MakeButton("Accept", "Accept", UDim2.fromOffset(110, 38), UDim2.new(1, -120, 0, 7), Theme.AccentGreen, banner, function()
				pendingInviteFrom = nil
				local res = tradeFn:InvokeServer("AcceptInvite", inv.UserId)
				if typeof(res) == "table" and not res.Ok then
					Toasts.Show(tostring(res.Message), Theme.AccentRed)
					render()
				end
			end)
			topOffset = 60
		end

		local listScroll = Instance.new("ScrollingFrame")
		listScroll.Size = UDim2.new(1, 0, 1, -topOffset)
		listScroll.Position = UDim2.fromOffset(0, topOffset)
		listScroll.BackgroundTransparency = 1
		listScroll.BorderSizePixel = 0
		listScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		listScroll.CanvasSize = UDim2.fromOffset(0, 0)
		listScroll.Parent = content

		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 8)
		layout.Parent = listScroll

		local others = 0
		for _, other in Players:GetPlayers() do
			if other ~= localPlayer then
				others += 1
				local row = Theme.MakeFrame(other.Name, UDim2.new(1, -6, 0, 50), UDim2.fromScale(0, 0), Theme.BgCard, 10, listScroll)
				local lbl = Theme.MakeLabel("Name", `👤 {other.DisplayName} (@{other.Name})`, UDim2.new(0.65, 0, 0.8, 0), UDim2.fromOffset(12, 5), Theme.FontTitle, Theme.TextPrimary, row)
				lbl.TextXAlignment = Enum.TextXAlignment.Left
				Theme.MakeButton("Invite", "Send Trade", UDim2.fromOffset(130, 38), UDim2.new(1, -140, 0, 6), Theme.AccentBlue, row, function()
					local res = tradeFn:InvokeServer("SendInvite", other.UserId)
					if typeof(res) == "table" then
						Toasts.Show(tostring(res.Message), if res.Ok then Theme.AccentGreen else Theme.AccentRed)
					end
				end)
			end
		end

		if others == 0 then
			Theme.MakeLabel("Empty", "No other players in the server yet.\nUse Roblox Studio 'Test > 2 Players' to test trading!", UDim2.fromScale(0.9, 0.4), UDim2.fromScale(0.05, 0.25), Theme.FontBody, Theme.TextMuted, listScroll)
		end
	end

	renderFn = render

	tradeUpdate.OnClientEvent:Connect(function(payload: any)
		if typeof(payload) ~= "table" then
			return
		end
		if payload.Type == "Invite" then
			pendingInviteFrom = { UserId = payload.FromUserId, Name = payload.FromName }
			Toasts.Show(`🤝 Trade invite from {payload.FromName}! Open Trade to accept.`, Theme.AccentGold)
			if modalFrame.Visible then
				render()
			end
		elseif payload.Type == "Session" then
			activeSession = payload
			onOpenRequest()
			render()
		elseif payload.Type == "Closed" then
			activeSession = nil
			if typeof(payload.Reason) == "string" and payload.Reason ~= "" then
				Toasts.Show(payload.Reason, Theme.AccentGold)
			end
			if modalFrame.Visible then
				render()
			end
		end
	end)

	Players.PlayerAdded:Connect(function()
		if modalFrame.Visible and not activeSession then
			render()
		end
	end)
	Players.PlayerRemoving:Connect(function()
		if modalFrame.Visible and not activeSession then
			render()
		end
	end)

	RunService.Heartbeat:Connect(function()
		if activeSession and confirmBtnRef and confirmBtnRef.Parent then
			local rem = math.ceil((activeSession.CountdownEndsAt or 0) - workspace:GetServerTimeNow())
			if rem > 0 then
				confirmBtnRef.Text = `Wait ({rem}s)...`
			elseif activeSession.MyConfirmed then
				confirmBtnRef.Text = "Confirmed! Waiting..."
			else
				confirmBtnRef.Text = "🤝 Confirm Trade!"
			end
		end
	end)
end

return TradePanel
