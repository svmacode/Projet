--!strict
-- Handball Legends design tokens.
--
-- Identity: anime sports broadcast. Solid ink-navy surfaces, bold condensed
-- display type, one hot amber accent for "your action", and two high-contrast
-- team colours that are ALWAYS paired with a shape (Red = triangle, Blue =
-- circle) so teams never rely on colour alone.

local Theme = {}

local rgb = Color3.fromRGB

Theme.Colors = {
	Ink = rgb(11, 13, 24), -- deepest surface
	Surface = rgb(20, 23, 38),
	Raised = rgb(31, 35, 56),
	Line = rgb(52, 58, 88),

	Text = rgb(246, 247, 252),
	TextDim = rgb(160, 166, 196),
	TextFaint = rgb(104, 110, 140),
	TextOnAccent = rgb(20, 14, 4),

	Accent = rgb(255, 186, 30), -- amber: your actions, highlights
	AccentHot = rgb(255, 210, 90),
	Danger = rgb(255, 72, 88),
	Success = rgb(70, 224, 140),
	Warning = rgb(255, 150, 40),
	Info = rgb(90, 190, 255),
	White = rgb(255, 255, 255),
	Black = rgb(0, 0, 0),
}

export type TeamStyle = { Main: Color3, Dark: Color3, Name: string, Symbol: string }

Theme.Teams = {
	Red = { Main = rgb(240, 48, 66), Dark = rgb(120, 16, 30), Name = "ROUGE", Symbol = "▲" },
	Blue = { Main = rgb(40, 128, 255), Dark = rgb(14, 44, 120), Name = "BLEU", Symbol = "●" },
} :: { [string]: TeamStyle }

function Theme.team(teamId: string?): TeamStyle
	return Theme.Teams[teamId or ""]
		or { Main = Theme.Colors.TextDim, Dark = Theme.Colors.Raised, Name = "—", Symbol = "■" }
end

local function face(enum: Enum.Font, weight: Enum.FontWeight?, italic: boolean?): Font
	local base = Font.fromEnum(enum)
	return Font.new(base.Family, weight or base.Weight, if italic then Enum.FontStyle.Italic else Enum.FontStyle.Normal)
end

Theme.Fonts = {
	Display = face(Enum.Font.GothamBlack),
	Heavy = face(Enum.Font.BuilderSansExtraBold),
	Bold = face(Enum.Font.BuilderSansBold),
	Body = face(Enum.Font.BuilderSansMedium),
	Mono = face(Enum.Font.RobotoMono, Enum.FontWeight.Bold),
}

-- Fixed sizes at the 1600×900 reference resolution (scaled by UIScale).
Theme.Text = {
	Giant = 140,
	Hero = 72,
	Title = 40,
	Heading = 26,
	Large = 20,
	Body = 17,
	Small = 14,
	Tiny = 12,
}

Theme.Space = { XS = 4, S = 8, M = 12, L = 20, XL = 32 }
Theme.Radius = 6

Theme.Motion = {
	Fast = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Base = TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	Slow = TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	Snap = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
}

return Theme
