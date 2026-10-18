--!strict
-- Écran ENTRAÎNEMENT : partie temporaire avec les membres du groupe, sans
-- récompenses ni impact sur le classement. Option : compléter avec des bots.

local Players = game:GetService("Players")

local Kit = require(script.Parent.Parent.UI.Kit)
local ScreenFrame = require(script.Parent.Parent.UI.ScreenFrame)
local SearchScreen = require(script.Parent.SearchScreen)
local State = require(script.Parent.Parent.Controllers.State)
local Theme = require(script.Parent.Parent.UI.Theme)

local C = Theme.Colors

local TrainingScreen = {}

function TrainingScreen.create(parent: Instance, close: () -> ()): ScreenFrame.Screen
	local screen = ScreenFrame.new(parent, "ENTRAÎNEMENT", "練習試合", C.Blue, close)
	local content = screen.Content
	local fillBots = true

	local picker = SearchScreen.modePicker(content, function() end)
	local _ = picker

	local explanation = Kit.text({
		Text = "Joue une partie amicale avec ton groupe : les membres sont répartis entre ROUGE et BLEU. "
			.. "Aucune récompense, aucun RP : parfait pour s'entraîner aux combos et aux pouvoirs !",
		Font = Theme.Fonts.Body,
		Size = UDim2.new(1, -20, 0, 60),
		Position = UDim2.fromOffset(10, 276),
		AlignX = Enum.TextXAlignment.Left,
		MaxSize = 22,
		ZIndex = 22,
		Parent = content,
	})
	local _2 = explanation

	local membersLabel = Kit.text({
		Text = "",
		Color = C.Blue,
		Size = UDim2.new(1, -20, 0, 36),
		Position = UDim2.fromOffset(10, 346),
		AlignX = Enum.TextXAlignment.Left,
		ZIndex = 22,
		Parent = content,
	})

	local botsButton: Kit.Button
	botsButton = Kit.button({
		Text = "BOTS : OUI",
		Color = C.Green,
		Size = UDim2.fromOffset(280, 56),
		Position = UDim2.fromOffset(10, 400),
		ZIndex = 23,
		Parent = content,
		OnClick = function()
			fillBots = not fillBots
			botsButton.SetText(if fillBots then "BOTS : OUI" else "BOTS : NON")
			botsButton.SetColor(if fillBots then C.Green else C.PaperDark)
		end,
	})

	local launch = Kit.button({
		Text = "LANCER L'ENTRAÎNEMENT",
		Color = C.Blue,
		TextColor = C.Paper,
		TextStroke = C.Ink,
		Size = UDim2.fromOffset(500, 90),
		Position = UDim2.new(0.5, 0, 1, -50),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = -2,
		ShadowOffset = 8,
		StrokeThickness = 5,
		ZIndex = 23,
		Parent = content,
		OnClick = function()
			local ok = State.request("QueueAction", "Training", picker.Selected(), fillBots)
			if ok then
				close()
			end
		end,
	})

	local function refresh()
		local party = State.Party
		if party then
			local names = {}
			for _, member in party.Members do
				table.insert(names, member.Name)
			end
			membersLabel.Text = `GROUPE : {table.concat(names, " · ")}`
			launch.SetEnabled(party.LeaderId == Players.LocalPlayer.UserId)
		else
			membersLabel.Text = "SEUL : invite des amis depuis le panneau GROUPE, ou joue avec des bots."
			launch.SetEnabled(true)
		end
	end
	State.PartyChanged:Connect(refresh)
	local open = screen.Open
	screen.Open = function()
		refresh()
		open()
	end
	refresh()
	return screen
end

return TrainingScreen
