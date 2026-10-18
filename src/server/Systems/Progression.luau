--!strict
-- Récompenses de fin de match : Hand Coins, XP, niveaux, tenues, RP classé,
-- statistiques et cadeau de première partie (3 Balles).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Progression = require(ReplicatedStorage.Shared.Data.Progression)
local PlayerData = require(script.Parent.PlayerData)
local Remote = require(script.Parent.Parent.Lib.Remote)

export type MatchResult = {
	Outcome: "Win" | "Loss" | "Draw",
	Goals: number,
	Assists: number,
	Saves: number,
	Interceptions: number,
	MVP: boolean,
	Ranked: boolean,
	Training: boolean,
}

export type RewardSummary = {
	Coins: number,
	XP: number,
	LevelBefore: number,
	LevelAfter: number,
	RPChange: number,
	RPAfter: number,
	FirstMatchBalls: number,
	KitsUnlocked: { string },
}

local ProgressionSystem = {}

local function coinsFor(result: MatchResult): number
	local rewards = Config.Economy.Rewards
	if result.Training then
		return 0
	end
	local base = if result.Outcome == "Win"
		then rewards.Win
		elseif result.Outcome == "Draw" then rewards.Draw
		else rewards.Loss
	local bonus = result.Goals * rewards.Goal
		+ result.Assists * rewards.Assist
		+ result.Saves * rewards.Save
		+ result.Interceptions * rewards.Interception
	local total = base + bonus
	if result.Ranked then
		total *= rewards.RankedMultiplier
	end
	return math.floor(math.min(total, rewards.MaxPerMatch))
end

local function xpFor(result: MatchResult): number
	local xp = Config.Economy.XP
	if result.Training then
		return xp.Training
	end
	local base = if result.Outcome == "Win" then xp.Win elseif result.Outcome == "Draw" then xp.Draw else xp.Loss
	return base
		+ result.Goals * xp.Goal
		+ result.Assists * xp.Assist
		+ result.Saves * xp.Save
		+ result.Interceptions * xp.Interception
end

local function rpFor(result: MatchResult): number
	local ranked = Config.Ranked
	if result.Outcome == "Win" then
		return ranked.WinRP + (if result.MVP then ranked.MvpBonusRP else 0)
	elseif result.Outcome == "Loss" then
		return -ranked.LossRP + (if result.MVP then ranked.MvpBonusRP else 0)
	end
	return ranked.DrawRP
end

function ProgressionSystem.grantMatchRewards(player: Player, result: MatchResult): RewardSummary?
	local summary: RewardSummary? = nil
	PlayerData.update(player, function(profile)
		local coins = coinsFor(result)
		local xp = xpFor(result)
		local levelBefore = profile.Level
		local newLevel, newXP = Progression.applyXP(profile.Level, profile.XP, xp)
		profile.Level = newLevel
		profile.XP = newXP
		profile.Coins += coins

		local kitsUnlocked = {}
		for _, kit in Progression.Kits do
			if kit.Level > levelBefore and kit.Level <= newLevel then
				table.insert(kitsUnlocked, kit.Name)
			end
		end

		local rpChange = 0
		if result.Ranked then
			rpChange = rpFor(result)
			profile.RP = math.max(0, profile.RP + rpChange)
			profile.PeakRP = math.max(profile.PeakRP, profile.RP)
			profile.RankedMatches += 1
		end

		local firstMatchBalls = 0
		if not result.Training then
			local stats = profile.Stats
			stats.Matches += 1
			if result.Outcome == "Win" then
				stats.Wins += 1
			elseif result.Outcome == "Loss" then
				stats.Losses += 1
			else
				stats.Draws += 1
			end
			stats.Goals += result.Goals
			stats.Assists += result.Assists
			stats.Saves += result.Saves
			stats.Interceptions += result.Interceptions
			if result.MVP then
				stats.MVPs += 1
			end
			if not profile.FirstMatchRewarded then
				profile.FirstMatchRewarded = true
				firstMatchBalls = Config.Economy.FirstMatchBalls
				local ballId = Config.Economy.FirstMatchBallId
				profile.Balls[ballId] = (profile.Balls[ballId] or 0) + firstMatchBalls
			end
		end

		summary = {
			Coins = coins,
			XP = xp,
			LevelBefore = levelBefore,
			LevelAfter = newLevel,
			RPChange = rpChange,
			RPAfter = profile.RP,
			FirstMatchBalls = firstMatchBalls,
			KitsUnlocked = kitsUnlocked,
		}
	end)

	local final = summary :: RewardSummary?
	if final then
		if final.LevelAfter > final.LevelBefore then
			Remote.notify(player, `NIVEAU {final.LevelAfter} !`, "Level")
			if final.LevelBefore < Config.RankedUnlockLevel and final.LevelAfter >= Config.RankedUnlockLevel then
				Remote.notify(player, "Le mode CLASSÉ est débloqué !", "Gold")
			end
		end
		for _, kitName in final.KitsUnlocked do
			Remote.notify(player, `Nouvelle tenue débloquée : {kitName}`, "Gold")
		end
		if final.FirstMatchBalls > 0 then
			Remote.notify(player, `Cadeau de bienvenue : {final.FirstMatchBalls} Balles Classiques !`, "Gold")
		end
	end
	return final
end

return ProgressionSystem
