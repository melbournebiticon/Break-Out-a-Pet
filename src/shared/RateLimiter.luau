--!strict
-- RateLimiter.luau
-- Simple per-player, per-action rate limiter to prevent remote spam.

local Players = game:GetService("Players")

local RateLimiter = {}

local lastCall: { [Player]: { [string]: number } } = {}

Players.PlayerRemoving:Connect(function(player: Player)
	lastCall[player] = nil
end)

function RateLimiter.Check(player: Player, key: string, cooldownSeconds: number): boolean
	local now = os.clock()
	local bucket = lastCall[player]
	if not bucket then
		bucket = {}
		lastCall[player] = bucket
	end
	local prev = bucket[key]
	if prev and (now - prev) < cooldownSeconds then
		return false
	end
	bucket[key] = now
	return true
end

return RateLimiter
