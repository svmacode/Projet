--!strict
-- Ambiance « coucher de soleil » : lumière dorée, ciel rosé, brume d'horizon
-- qui fond les lointains, léger bloom et rayons du soleil.

local Lighting = game:GetService("Lighting")

local Atmosphere = {}

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
	Lighting.ClockTime = 17.55
	Lighting.GeographicLatitude = 35
	Lighting.Brightness = 2.6
	Lighting.ExposureCompensation = 0.15
	Lighting.Ambient = Color3.fromRGB(78, 62, 84)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 116, 128)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 196, 150)
	Lighting.ColorShift_Bottom = Color3.fromRGB(96, 70, 120)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.ShadowSoftness = 0.12
	Lighting.GlobalShadows = true

	local sky = ensure("Sky", "Ciel") :: Sky
	sky.SunAngularSize = 14
	sky.MoonAngularSize = 8
	sky.StarCount = 1500

	local atmosphere = ensure("Atmosphere", "Brume") :: Atmosphere
	atmosphere.Density = 0.34
	atmosphere.Offset = 0.12
	atmosphere.Color = Color3.fromRGB(255, 196, 168)
	atmosphere.Decay = Color3.fromRGB(122, 84, 140)
	atmosphere.Glare = 0.55
	atmosphere.Haze = 1.9

	local bloom = ensure("BloomEffect", "Eclat") :: BloomEffect
	bloom.Intensity = 0.55
	bloom.Size = 26
	bloom.Threshold = 1.35

	local rays = ensure("SunRaysEffect", "Rayons") :: SunRaysEffect
	rays.Intensity = 0.07
	rays.Spread = 0.75

	local grade = ensure("ColorCorrectionEffect", "Etalonnage") :: ColorCorrectionEffect
	grade.Brightness = 0.02
	grade.Contrast = 0.1
	grade.Saturation = 0.12
	grade.TintColor = Color3.fromRGB(255, 244, 236)
end

return Atmosphere
