--!strict
-- Per-player token buckets: every remote handler spends a token first.

local Players = game:GetService("Players")

local RateLimit = {}

type Bucket = { Tokens: number, Last: number }

local buckets: { [Player]: { [string]: Bucket } } = {}

function RateLimit.allow(player: Player, key: string, ratePerSecond: number, burst: number): boolean
	local now = os.clock()
	local perPlayer = buckets[player]
	if not perPlayer then
		perPlayer = {}
		buckets[player] = perPlayer
	end
	local bucket = perPlayer[key]
	if not bucket then
		bucket = { Tokens = burst, Last = now }
		perPlayer[key] = bucket
	end
	bucket.Tokens = math.min(burst, bucket.Tokens + (now - bucket.Last) * ratePerSecond)
	bucket.Last = now
	if bucket.Tokens < 1 then
		return false
	end
	bucket.Tokens -= 1
	return true
end

Players.PlayerRemoving:Connect(function(player)
	buckets[player] = nil
end)

return RateLimit
