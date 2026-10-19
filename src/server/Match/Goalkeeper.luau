--!strict
-- Goalkeeper save geometry. Saves are decided only by where the keeper is,
-- where their hands are (standing or diving towards the point the player
-- chose) and where the ball travels: never by a random roll.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BallPhysics = require(ReplicatedStorage.Shared.BallPhysics)
local Config = require(ReplicatedStorage.Shared.Config)
local MatchTypes = require(script.Parent.MatchTypes)

local Goalkeeper = {}

local function easeOut(t: number): number
	return 1 - (1 - t) * (1 - t)
end

-- Current hand position during a dive (world space), or nil if not diving.
function Goalkeeper.diveHands(keeper: MatchTypes.Participant, now: number): Vector3?
	if now >= keeper.DiveUntil or now < keeper.DiveStart then
		return nil
	end
	local progress = math.clamp((now - keeper.DiveStart) / Config.Keeper.DiveDuration, 0, 1)
	return keeper.DiveFrom:Lerp(keeper.DiveEnd, easeOut(progress))
end

-- Does the ball segment a → b touch the keeper this step?
function Goalkeeper.touches(
	keeper: MatchTypes.Participant,
	a: Vector3,
	b: Vector3,
	now: number,
	floorY: number
): boolean
	local root = keeper.Root
	if not root then
		return false
	end
	local hands = Goalkeeper.diveHands(keeper, now)
	if hands then
		return BallPhysics.segmentDistance(a, b, hands) < Config.Keeper.SaveReachDive
	end
	if now < keeper.DiveRecoveryUntil then
		-- Lying on the floor after a dive: only the body blocks, low.
		local body = Vector3.new(keeper.DiveEnd.X, floorY + 1, keeper.DiveEnd.Z)
		return BallPhysics.segmentDistance(a, b, body) < 2.2
	end
	-- Standing: hands and body along a vertical capsule.
	local position = root.Position
	local reach = Config.Keeper.SaveReachStanding
	for _, height in { 1.2, 3.4, 5.6 } do
		local point = Vector3.new(position.X, floorY + height, position.Z)
		if BallPhysics.segmentDistance(a, b, point) < reach then
			return true
		end
	end
	return false
end

return Goalkeeper
