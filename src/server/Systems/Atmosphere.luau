--!strict
-- Ambiance « coucher de soleil d'animé » : ciel rose-orangé qui vire au
-- violet, lumière dorée rasante, couleurs très saturées, bloom marqué et
-- rayons du soleil. Sur un serveur de match, la lumière est un peu plus
-- haute et plus franche pour que le gymnase reste lumineux et coloré.

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

	Lighting.ClockTime = if isMatch then 16.9 else 17.6
	Lighting.GeographicLatitude = 35
	Lighting.Brightness = if isMatch then 3.2 else 3
	Lighting.ExposureCompensation = if isMatch then 0.25 else 0.2
	-- Ombres teintées violet (jamais grises) : signature des décors d'animé.
	Lighting.Ambient = if isMatch then rgb(120, 100, 150) else rgb(104, 72, 132)
	Lighting.OutdoorAmbient = if isMatch then rgb(190, 160, 200) else rgb(186, 120, 168)
	Lighting.ColorShift_Top = rgb(255, 170, 120)
	Lighting.ColorShift_Bottom = rgb(130, 70, 200)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.ShadowSoftness = 0.05 -- ombres nettes, façon cel-shading
	Lighting.GlobalShadows = true

	local sky = ensure("Sky", "Ciel") :: Sky
	sky.SunAngularSize = 18
	sky.MoonAngularSize = 9
	sky.StarCount = 2500
	sky.CelestialBodiesShown = true

	-- Brume rose-violet : fond les lointains dans le dégradé du ciel.
	local atmosphere = ensure("Atmosphere", "Brume") :: Atmosphere
	atmosphere.Density = if isMatch then 0.28 else 0.36
	atmosphere.Offset = 0.18
	atmosphere.Color = rgb(255, 150, 170)
	atmosphere.Decay = rgb(120, 60, 190)
	atmosphere.Glare = 0.9
	atmosphere.Haze = 2.2

	local bloom = ensure("BloomEffect", "Eclat") :: BloomEffect
	bloom.Intensity = 0.9
	bloom.Size = 30
	bloom.Threshold = 1.1

	local rays = ensure("SunRaysEffect", "Rayons") :: SunRaysEffect
	rays.Intensity = 0.12
	rays.Spread = 0.8

	-- Étalonnage : couleurs poussées et contraste franc.
	local grade = ensure("ColorCorrectionEffect", "Etalonnage") :: ColorCorrectionEffect
	grade.Brightness = 0.03
	grade.Contrast = 0.22
	grade.Saturation = 0.42
	grade.TintColor = rgb(255, 240, 248)
end

return Atmosphere
