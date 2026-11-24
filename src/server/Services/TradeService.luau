--!strict
-- TradeService.luau (SERVER)
-- Secure player-to-player pet trading with anti-scam offer reset and 3-second final confirm countdown.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local RateLimiter = require(Shared:WaitForChild("RateLimiter"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local InventoryService = require(script.Parent:WaitForChild("InventoryService"))
local ClientSyncService = require(script.Parent:WaitForChild("ClientSyncService"))

export type OfferPet = {
	Uid: string,
	PetId: string,
	Mutation: string?,
}

type TradeSession = {
	Id: string,
	PlayerA: Player,
	PlayerB: Player,
	OfferA: { string },
	OfferB: { string },
	AcceptedA: boolean,
	AcceptedB: boolean,
	ConfirmedA: boolean,
	ConfirmedB: boolean,
	CountdownEndsAt: number,
	StateVersion: number,
}

local TradeService = {}

local tradeUpdateEvent: RemoteEvent
local activeSessionByPlayer: { [Player]: TradeSession } = {}
local pendingInviteTarget: { [Player]: Player } = {}

local function buildOfferView(owner: Player, uids: { string }): { OfferPet }
	local list: { OfferPet } = {}
	for _, uid in uids do
		local owned = InventoryService.GetPetByUid(owner, uid)
		if owned then
			table.insert(list, {
				Uid = owned.Uid,
				PetId = owned.PetId,
				Mutation = owned.Mutation,
			})
		end
	end
	return list
end

local function broadcastSession(session: TradeSession)
	local offerAView = buildOfferView(session.PlayerA, session.OfferA)
	local offerBView = buildOfferView(session.PlayerB, session.OfferB)

	local payloadA = {
		Type = "Session",
		PartnerName = session.PlayerB.DisplayName,
		MyOffer = offerAView,
		TheirOffer = offerBView,
		MyAccepted = session.AcceptedA,
		TheirAccepted = session.AcceptedB,
		MyConfirmed = session.ConfirmedA,
		TheirConfirmed = session.ConfirmedB,
		CountdownEndsAt = session.CountdownEndsAt,
	}
	local payloadB = {
		Type = "Session",
		PartnerName = session.PlayerA.DisplayName,
		MyOffer = offerBView,
		TheirOffer = offerAView,
		MyAccepted = session.AcceptedB,
		TheirAccepted = session.AcceptedA,
		MyConfirmed = session.ConfirmedB,
		TheirConfirmed = session.ConfirmedA,
		CountdownEndsAt = session.CountdownEndsAt,
	}

	if session.PlayerA.Parent then
		tradeUpdateEvent:FireClient(session.PlayerA, payloadA)
	end
	if session.PlayerB.Parent then
		tradeUpdateEvent:FireClient(session.PlayerB, payloadB)
	end
end

local function cancelSession(session: TradeSession, reason: string)
	activeSessionByPlayer[session.PlayerA] = nil
	activeSessionByPlayer[session.PlayerB] = nil

	if session.PlayerA.Parent then
		tradeUpdateEvent:FireClient(session.PlayerA, { Type = "Closed", Reason = reason })
	end
	if session.PlayerB.Parent then
		tradeUpdateEvent:FireClient(session.PlayerB, { Type = "Closed", Reason = reason })
	end
end

local function resetAcceptances(session: TradeSession)
	session.AcceptedA = false
	session.AcceptedB = false
	session.ConfirmedA = false
	session.ConfirmedB = false
	session.CountdownEndsAt = 0
	session.StateVersion += 1
end

local function validateOfferList(player: Player, uids: { string }): (boolean, string)
	if #uids > Config.TradeMaxPets then
		return false, `Max {Config.TradeMaxPets} pets per trade.`
	end
	local seen: { [string]: boolean } = {}
	for _, uid in uids do
		if seen[uid] then
			return false, "Duplicate pet in trade offer."
		end
		seen[uid] = true
		local owned = InventoryService.GetPetByUid(player, uid)
		if not owned then
			return false, "One of the offered pets is no longer owned."
		end
		if owned.Equipped then
			return false, "Unequip a pet before trading it."
		end
		if owned.State == "Placed" then
			return false, "Unplace a pet from your plot before trading it."
		end
		if owned.InTransit then
			return false, "Cannot trade a pet that is being stolen."
		end
	end
	return true, "OK"
end

local function executeAtomicSwap(session: TradeSession): (boolean, string)
	local pA = session.PlayerA
	local pB = session.PlayerB
	if not pA.Parent or not pB.Parent or not DataService.IsLoaded(pA) or not DataService.IsLoaded(pB) then
		return false, "A player left the game."
	end

	local okA, msgA = validateOfferList(pA, session.OfferA)
	if not okA then
		return false, `{pA.DisplayName}: {msgA}`
	end
	local okB, msgB = validateOfferList(pB, session.OfferB)
	if not okB then
		return false, `{pB.DisplayName}: {msgB}`
	end

	local petsFromA: { OfferPet } = buildOfferView(pA, session.OfferA)
	local petsFromB: { OfferPet } = buildOfferView(pB, session.OfferB)

	for _, item in petsFromA do
		InventoryService.RemovePet(pA, item.Uid)
	end
	for _, item in petsFromB do
		InventoryService.RemovePet(pB, item.Uid)
	end

	for _, item in petsFromA do
		InventoryService.AddPet(pB, item.PetId, item.Mutation)
	end
	for _, item in petsFromB do
		InventoryService.AddPet(pA, item.PetId, item.Mutation)
	end

	DataService.MarkDirty(pA)
	DataService.MarkDirty(pB)
	task.spawn(DataService.SavePlayer, pA, true)
	task.spawn(DataService.SavePlayer, pB, true)

	print(`[TradeService] Completed trade {session.Id} between {pA.Name} ({#petsFromA} pets) and {pB.Name} ({#petsFromB} pets)`)
	return true, "Trade completed!"
end

function TradeService.HandleRequest(player: Player, action: any, arg: any): { Ok: boolean, Message: string }
	if not DataService.IsLoaded(player) then
		return { Ok = false, Message = "Data is still loading." }
	end
	if typeof(action) ~= "string" then
		return { Ok = false, Message = "Invalid action." }
	end

	if action == "SendInvite" then
		if activeSessionByPlayer[player] then
			return { Ok = false, Message = "You are already in a trade." }
		end
		local targetUserId = if typeof(arg) == "number" then arg else nil
		if not targetUserId or targetUserId == player.UserId then
			return { Ok = false, Message = "Invalid target player." }
		end
		local target = Players:GetPlayerByUserId(targetUserId)
		if not target or not DataService.IsLoaded(target) then
			return { Ok = false, Message = "Player is not available." }
		end
		if activeSessionByPlayer[target] then
			return { Ok = false, Message = `{target.DisplayName} is already in another trade.` }
		end

		pendingInviteTarget[player] = target
		tradeUpdateEvent:FireClient(target, {
			Type = "Invite",
			FromUserId = player.UserId,
			FromName = player.DisplayName,
		})
		return { Ok = true, Message = `Sent trade invite to {target.DisplayName}!` }

	elseif action == "AcceptInvite" then
		if activeSessionByPlayer[player] then
			return { Ok = false, Message = "You are already in a trade." }
		end
		local senderUserId = if typeof(arg) == "number" then arg else nil
		local sender = if senderUserId then Players:GetPlayerByUserId(senderUserId) else nil
		if not sender or pendingInviteTarget[sender] ~= player then
			return { Ok = false, Message = "Trade invite expired." }
		end
		if activeSessionByPlayer[sender] then
			return { Ok = false, Message = "Player is already in another trade." }
		end

		pendingInviteTarget[sender] = nil
		local session: TradeSession = {
			Id = HttpService:GenerateGUID(false),
			PlayerA = sender,
			PlayerB = player,
			OfferA = {},
			OfferB = {},
			AcceptedA = false,
			AcceptedB = false,
			ConfirmedA = false,
			ConfirmedB = false,
			CountdownEndsAt = 0,
			StateVersion = 1,
		}
		activeSessionByPlayer[sender] = session
		activeSessionByPlayer[player] = session
		broadcastSession(session)
		return { Ok = true, Message = "Trade started!" }

	elseif action == "TogglePet" then
		local session = activeSessionByPlayer[player]
		if not session then
			return { Ok = false, Message = "Not in a trade." }
		end
		if typeof(arg) ~= "string" or arg == "" then
			return { Ok = false, Message = "Invalid pet." }
		end

		local offer = if session.PlayerA == player then session.OfferA else session.OfferB
		local existingIdx: number? = nil
		for i, uid in offer do
			if uid == arg then
				existingIdx = i
				break
			end
		end

		if existingIdx then
			table.remove(offer, existingIdx)
		else
			if #offer >= Config.TradeMaxPets then
				return { Ok = false, Message = `Max {Config.TradeMaxPets} pets per trade.` }
			end
			local owned = InventoryService.GetPetByUid(player, arg)
			if not owned then
				return { Ok = false, Message = "Pet not found." }
			end
			if owned.Equipped then
				return { Ok = false, Message = "Unequip this pet before trading it." }
			end
			if owned.State == "Placed" then
				return { Ok = false, Message = "Unplace this pet from your plot before trading it." }
			end
			if owned.InTransit then
				return { Ok = false, Message = "This pet is currently being stolen!" }
			end
			table.insert(offer, arg)
		end

		resetAcceptances(session)
		broadcastSession(session)
		return { Ok = true, Message = "Offer updated." }

	elseif action == "AcceptOffer" then
		local session = activeSessionByPlayer[player]
		if not session then
			return { Ok = false, Message = "Not in a trade." }
		end
		local okA, msgA = validateOfferList(session.PlayerA, session.OfferA)
		if not okA then
			return { Ok = false, Message = msgA }
		end
		local okB, msgB = validateOfferList(session.PlayerB, session.OfferB)
		if not okB then
			return { Ok = false, Message = msgB }
		end

		if session.PlayerA == player then
			session.AcceptedA = true
		else
			session.AcceptedB = true
		end

		if session.AcceptedA and session.AcceptedB and session.CountdownEndsAt == 0 then
			session.CountdownEndsAt = workspace:GetServerTimeNow() + Config.TradeConfirmCountdownSeconds
		end

		broadcastSession(session)
		return { Ok = true, Message = "Accepted!" }

	elseif action == "ConfirmTrade" then
		local session = activeSessionByPlayer[player]
		if not session then
			return { Ok = false, Message = "Not in a trade." }
		end
		if not (session.AcceptedA and session.AcceptedB) then
			return { Ok = false, Message = "Both players must accept first." }
		end
		if workspace:GetServerTimeNow() < session.CountdownEndsAt - 0.1 then
			return { Ok = false, Message = "Wait for the 3-second countdown!" }
		end

		if session.PlayerA == player then
			session.ConfirmedA = true
		else
			session.ConfirmedB = true
		end

		if session.ConfirmedA and session.ConfirmedB then
			local ok, msg = executeAtomicSwap(session)
			if ok then
				ClientSyncService.Notify(session.PlayerA, "🤝 Trade completed!", Color3.fromRGB(100, 255, 130))
				ClientSyncService.Notify(session.PlayerB, "🤝 Trade completed!", Color3.fromRGB(100, 255, 130))
				cancelSession(session, "Trade completed!")
				return { Ok = true, Message = msg }
			else
				cancelSession(session, msg)
				return { Ok = false, Message = msg }
			end
		end

		broadcastSession(session)
		return { Ok = true, Message = "Confirmed! Waiting for partner." }

	elseif action == "Cancel" then
		local session = activeSessionByPlayer[player]
		if session then
			cancelSession(session, `{player.DisplayName} cancelled the trade.`)
		end
		return { Ok = true, Message = "Trade cancelled." }
	end

	return { Ok = false, Message = "Unknown trade action." }
end

function TradeService.Init()
	tradeUpdateEvent = Remotes.GetEvent("TradeUpdate")
	local fn = Remotes.GetFunction("TradeRequest")

	fn.OnServerInvoke = function(player: Player, action: any, arg: any)
		if not RateLimiter.Check(player, "TradeRequest", 0.2) then
			return { Ok = false, Message = "Too fast!" }
		end
		return TradeService.HandleRequest(player, action, arg)
	end

	Players.PlayerRemoving:Connect(function(player: Player)
		pendingInviteTarget[player] = nil
		local session = activeSessionByPlayer[player]
		if session then
			cancelSession(session, `{player.DisplayName} left the game.`)
		end
	end)
end

return TradeService
