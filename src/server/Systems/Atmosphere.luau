--!strict
-- Ambiance du lobby : fin d'après-midi dans un décor d'animé de sport.
-- Soleil bas et doré, ciel orangé qui passe au bleu-violet en hauteur,
-- brume chaude qui fond l'horizon, ombres douces légèrement bleutées.
-- Couleurs naturelles : on relève à peine la saturation, sans la pousser.
-- Sur un serveur de match (gymnase), la lumière est plus haute et neutre.

local Lighting = game:GetService("Lighting")

local ServerRole = require(script.Parent.Parent.Lib.ServerRole)

local Atmosphere = {}

local rgb = Color3.fromRGB

local function ensure<T>(className: string, name: string): T
	local existing = Lighting:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing :: any
	end
	local created = Instance.new(className)
	created.Name = name
	created.Parent = Lighting
	return created :: any
end

function Atmosphere.init()
	local isMatch = ServerRole.Role == "Match"

	Lighting.ClockTime = if isMatch then 14.5 else 17.35
	Lighting.GeographicLatitude = 35
	Lighting.Brightness = if isMatch then 2.6 else 2.4
	Lighting.ExposureCompensation = if isMatch then 0.1 else 0.15
	Lighting.Ambient = if isMatch then rgb(110, 108, 116) else rgb(92, 84, 104)
	Lighting.OutdoorAmbient = if isMatch then rgb(150, 150, 156) else rgb(146, 128, 140)
	Lighting.ColorShift_Top = if isMatch then rgb(255, 246, 232) else rgb(255, 196, 140)
	Lighting.ColorShift_Bottom = rgb(90, 100, 140)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.ShadowSoftness = 0.3
	Lighting.GlobalShadows = true

	local sky = ensure("Sky", "Ciel") :: Sky
	sky.SunAngularSize = 14
	sky.MoonAngularSize = 8
	sky.StarCount = 1500
	sky.CelestialBodiesShown = true

	-- Brume chaude : l'horizon se fond dans le dégradé orangé du ciel.
	local atmosphere = ensure("Atmosphere", "Brume") :: Atmosphere
	atmosphere.Density = if isMatch then 0.2 else 0.34
	atmosphere.Offset = 0.22
	atmosphere.Color = rgb(255, 196, 160)
	atmosphere.Decay = rgb(112, 104, 150)
	atmosphere.Glare = if isMatch then 0.2 else 0.55
	atmosphere.Haze = if isMatch then 0.8 else 1.7

	local bloom = ensure("BloomEffect", "Eclat") :: BloomEffect
	bloom.Intensity = 0.45
	bloom.Size = 24
	bloom.Threshold = 1.4

	local rays = ensure("SunRaysEffect", "Rayons") :: SunRaysEffect
	rays.Intensity = if isMatch then 0.02 else 0.08
	rays.Spread = 0.6

	local grade = ensure("ColorCorrectionEffect", "Etalonnage") :: ColorCorrectionEffect
	grade.Brightness = 0.02
	grade.Contrast = 0.08
	grade.Saturation = if isMatch then 0.08 else 0.14
	grade.TintColor = if isMatch then rgb(255, 255, 255) else rgb(255, 246, 238)
end

return Atmosphere
