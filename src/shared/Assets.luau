--!strict
-- External assets that the code cannot create (animations, sounds, meshes).
-- Every entry is OPTIONAL: an empty id falls back to the built-in version
-- (procedural animation, silence, parts built in code).
--
-- Animations must be R6 animations published by the experience owner (your
-- account or your group); Roblox refuses to play animations owned by others.

local Assets = {}

Assets.Animations = {
	Idle = "",
	Run = "",
	Sprint = "",
	Jump = "",
	Fall = "",
	Land = "",
	Dash = "",
	Stance = "", -- defensive shuffle
	Dribble = "",
	PassQuick = "",
	PassHigh = "",
	Catch = "",
	ShotCharge = "", -- looped while charging
	ShotQuick = "",
	ShotCharged = "",
	JumpShot = "",
	Block = "",
	Intercept = "",
	Contact = "",
	Stagger = "",
	KeeperReady = "",
	KeeperDiveLeft = "",
	KeeperDiveRight = "",
	KeeperSaveHigh = "",
	KeeperSaveLow = "",
	Celebrate = "",
} :: { [string]: string }

Assets.Sounds = {
	Whistle = "",
	WhistleLong = "",
	Goal = "",
	Crowd = "",
	Bounce = "",
	Catch = "",
	Pass = "",
	Shot = "",
	ShotCharged = "",
	Save = "",
	Post = "",
	Dash = "",
	Contact = "",
	Footstep = "",
	UiClick = "",
	UiHover = "",
	Countdown = "",
} :: { [string]: string }

function Assets.animation(name: string): string?
	local id = Assets.Animations[name]
	return if id and id ~= "" then id else nil
end

function Assets.sound(name: string): string?
	local id = Assets.Sounds[name]
	return if id and id ~= "" then id else nil
end

return Assets
