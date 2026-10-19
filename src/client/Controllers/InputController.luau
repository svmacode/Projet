--!strict
-- Single input layer for keyboard/mouse, gamepad and touch. Gameplay
-- controllers never read raw input: they listen to InputController.Intent,
-- which fires (intentName, pressed) for every bound action.
--
-- Actions are only bound while the local player is in a match, so the keys
-- (and the touch buttons) do nothing outside of it.

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local MatchClient = require(script.Parent.MatchClient)

local InputController = {}

-- Fired with (intent, pressed). Intents:
-- "Shoot", "PassQuick", "PassHigh", "PassAimed", "Dash", "Sprint", "Stance",
-- "Primary" (dribble with the ball / block without), "Secondary" (intercept,
-- or dive for a goalkeeper), "Contact".
InputController.Intent = Signal.new() :: Signal.Signal<string, boolean>
InputController.EnabledChanged = Signal.new() :: Signal.Signal<boolean>

export type Binding = {
	Intent: string,
	Label: string,
	Keyboard: string,
	Gamepad: string,
	Touch: string?, -- touch button title, nil if no touch button
}

type ActionDef = {
	Intent: string,
	Label: string,
	KeyboardLabel: string,
	GamepadLabel: string,
	Inputs: { Enum.KeyCode | Enum.UserInputType },
	Touch: string?,
	TouchPosition: UDim2?,
	ToggleOnTouch: boolean?, -- touch press toggles instead of hold (sprint)
}

-- Touch buttons live in Roblox's ContextButtonFrame (bottom-right, next to the
-- jump button). Positions are relative to that frame.
local ACTIONS: { ActionDef } = {
	{
		Intent = "Shoot",
		Label = "Tir (appui court = rapide, maintenu = chargé)",
		KeyboardLabel = "Clic gauche",
		GamepadLabel = "R2",
		Inputs = { Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2 },
		Touch = "TIR",
		TouchPosition = UDim2.new(0.42, 0, 0.02, 0),
	},
	{
		Intent = "PassQuick",
		Label = "Passe rapide au coéquipier visé",
		KeyboardLabel = "E",
		GamepadLabel = "X",
		Inputs = { Enum.KeyCode.E, Enum.KeyCode.ButtonX },
		Touch = "PASSE",
		TouchPosition = UDim2.new(0.12, 0, 0.18, 0),
	},
	{
		Intent = "PassHigh",
		Label = "Passe haute (lob)",
		KeyboardLabel = "R",
		GamepadLabel = "Y",
		Inputs = { Enum.KeyCode.R, Enum.KeyCode.ButtonY },
		Touch = "LOB",
		TouchPosition = UDim2.new(0.12, 0, -0.18, 0),
	},
	{
		Intent = "PassAimed",
		Label = "Passe visée (dans l'axe du viseur)",
		KeyboardLabel = "T",
		GamepadLabel = "Croix haut",
		Inputs = { Enum.KeyCode.T, Enum.KeyCode.DPadUp },
		Touch = "VISÉE",
		TouchPosition = UDim2.new(-0.2, 0, -0.18, 0),
	},
	{
		Intent = "Dash",
		Label = "Dash directionnel",
		KeyboardLabel = "C",
		GamepadLabel = "B",
		Inputs = { Enum.KeyCode.C, Enum.KeyCode.ButtonB },
		Touch = "DASH",
		TouchPosition = UDim2.new(-0.2, 0, 0.5, 0),
	},
	{
		Intent = "Sprint",
		Label = "Sprint (maintenir)",
		KeyboardLabel = "Shift",
		GamepadLabel = "L3",
		Inputs = { Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3 },
		Touch = "SPRINT",
		TouchPosition = UDim2.new(-0.52, 0, 0.5, 0),
		ToggleOnTouch = true,
	},
	{
		Intent = "Primary",
		Label = "Avec le ballon : dribbler / reprendre · Sans : contre (bras levés)",
		KeyboardLabel = "F",
		GamepadLabel = "R1",
		Inputs = { Enum.KeyCode.F, Enum.KeyCode.ButtonR1 },
		Touch = "DRIB.",
		TouchPosition = UDim2.new(0.42, 0, -0.34, 0),
	},
	{
		Intent = "Secondary",
		Label = "Interception · Gardien : plongeon vers le viseur",
		KeyboardLabel = "Clic droit",
		GamepadLabel = "L2",
		Inputs = { Enum.UserInputType.MouseButton2, Enum.KeyCode.ButtonL2 },
		Touch = "INTER.",
		TouchPosition = UDim2.new(-0.52, 0, 0.18, 0),
	},
	{
		Intent = "Contact",
		Label = "Contact d'épaule",
		KeyboardLabel = "V",
		GamepadLabel = "Croix droite",
		Inputs = { Enum.KeyCode.V, Enum.KeyCode.DPadRight },
		Touch = "CONTACT",
		TouchPosition = UDim2.new(-0.52, 0, -0.18, 0),
	},
	{
		Intent = "Stance",
		Label = "Posture défensive (maintenir)",
		KeyboardLabel = "Ctrl gauche",
		GamepadLabel = "L1",
		Inputs = { Enum.KeyCode.LeftControl, Enum.KeyCode.ButtonL1 },
		Touch = "GARDE",
		TouchPosition = UDim2.new(-0.2, 0, 0.82, 0),
		ToggleOnTouch = true,
	},
}

local enabled = false
local pressed: { [string]: boolean } = {}
local touchToggled: { [string]: boolean } = {}

local function actionName(intent: string): string
	return "HL_" .. intent
end

local function emit(intent: string, isDown: boolean)
	if pressed[intent] == isDown then
		return
	end
	pressed[intent] = isDown
	InputController.Intent:Fire(intent, isDown)
end

local function bind(def: ActionDef)
	local name = actionName(def.Intent)
	ContextActionService:BindAction(name, function(_, state: Enum.UserInputState, input: InputObject)
		if state == Enum.UserInputState.Cancel then
			emit(def.Intent, false)
			return Enum.ContextActionResult.Pass
		end
		local isTouch = input.UserInputType == Enum.UserInputType.Touch
		if isTouch and def.ToggleOnTouch then
			if state == Enum.UserInputState.Begin then
				touchToggled[def.Intent] = not touchToggled[def.Intent]
				emit(def.Intent, touchToggled[def.Intent] == true)
			end
			return Enum.ContextActionResult.Sink
		end
		if state == Enum.UserInputState.Begin then
			emit(def.Intent, true)
		elseif state == Enum.UserInputState.End then
			emit(def.Intent, false)
		end
		return Enum.ContextActionResult.Sink
	end, def.Touch ~= nil, table.unpack(def.Inputs))
	if def.Touch then
		ContextActionService:SetTitle(name, def.Touch)
		if def.TouchPosition then
			ContextActionService:SetPosition(name, def.TouchPosition)
		end
	end
end

function InputController.setEnabled(value: boolean)
	if enabled == value then
		return
	end
	enabled = value
	for _, def in ACTIONS do
		if value then
			bind(def)
		else
			ContextActionService:UnbindAction(actionName(def.Intent))
			emit(def.Intent, false)
			touchToggled[def.Intent] = nil
		end
	end
	InputController.EnabledChanged:Fire(value)
end

function InputController.isEnabled(): boolean
	return enabled
end

function InputController.isDown(intent: string): boolean
	return pressed[intent] == true
end

-- Human-readable list of every binding (HUD, tutorial, settings screen).
function InputController.bindings(): { Binding }
	local list: { Binding } = {}
	for _, def in ACTIONS do
		table.insert(list, {
			Intent = def.Intent,
			Label = def.Label,
			Keyboard = def.KeyboardLabel,
			Gamepad = def.GamepadLabel,
			Touch = def.Touch,
		})
	end
	return list
end

-- Most recent input family, so the HUD can show the right prompts.
function InputController.device(): string
	local last = UserInputService:GetLastInputType()
	if last == Enum.UserInputType.Touch then
		return "Touch"
	elseif last.Name:sub(1, 7) == "Gamepad" then
		return "Gamepad"
	end
	return "Keyboard"
end

local function shouldBeEnabled(): boolean
	local match = MatchClient.Match
	if not match or not MatchClient.me() then
		return false
	end
	return match.Phase ~= "Results" and match.Phase ~= "Selection" and match.Phase ~= "Waiting"
end

function InputController.start()
	MatchClient.MatchChanged:Connect(function()
		InputController.setEnabled(shouldBeEnabled())
	end)
	InputController.setEnabled(shouldBeEnabled())
end

return InputController
