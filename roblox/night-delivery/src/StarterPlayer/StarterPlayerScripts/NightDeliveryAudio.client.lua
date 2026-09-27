-- Night Delivery audio director
-- Quiet by default. The music slowly gains presence as the shift gets later,
-- and Midnight Oddities temporarily replace that calm with an uneasy layer.

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local MAIN_TRACK_ID = "rbxassetid://1837346716"
local ODDITY_TRACK_ID = "rbxassetid://1835684820"

local PHASE_VOLUME = {
	EarlyNight = 0.035,
	MidNight = 0.055,
	LateNight = 0.075,
	FinalRun = 0.095,
}

local NORMAL_FADE_SECONDS = 1.8
local ODDITY_FADE_SECONDS = 0.9

local folder = SoundService:FindFirstChild("NightDeliveryAudio")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "NightDeliveryAudio"
	folder.Parent = SoundService
end

local function getOrCreateSound(name, soundId, playbackSpeed)
	local sound = folder:FindFirstChild(name)
	if sound and not sound:IsA("Sound") then
		sound:Destroy()
		sound = nil
	end

	if not sound then
		sound = Instance.new("Sound")
		sound.Name = name
		sound.Parent = folder
	end

	sound.SoundId = soundId
	sound.Looped = true
	sound.Volume = 0
	sound.PlaybackSpeed = playbackSpeed
	return sound
end

local mainTrack = getOrCreateSound("NightShiftBed", MAIN_TRACK_ID, 0.96)
local oddityTrack = getOrCreateSound("MidnightOddityLayer", ODDITY_TRACK_ID, 0.92)

local mainTween = nil
local oddityTween = nil

local function fade(sound, targetVolume, duration)
	if sound == mainTrack and mainTween then
		mainTween:Cancel()
	elseif sound == oddityTrack and oddityTween then
		oddityTween:Cancel()
	end

	local tween = TweenService:Create(
		sound,
		TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		{Volume = targetVolume}
	)
	tween:Play()

	if sound == mainTrack then
		mainTween = tween
	else
		oddityTween = tween
	end
end

local function ensurePlaying(sound)
	if not sound.IsPlaying then
		sound:Play()
	end
end

local function refreshAudio()
	local shiftActive = player:GetAttribute("NightShiftActive") == true
	local phase = tostring(player:GetAttribute("NightShiftPhase") or "EarlyNight")
	local oddityActive = player:GetAttribute("NightDeliveryOddityActive") == true

	if not shiftActive then
		fade(mainTrack, 0, NORMAL_FADE_SECONDS)
		fade(oddityTrack, 0, ODDITY_FADE_SECONDS)
		return
	end

	ensurePlaying(mainTrack)
	local mainVolume = PHASE_VOLUME[phase] or PHASE_VOLUME.EarlyNight

	if oddityActive then
		ensurePlaying(oddityTrack)
		fade(mainTrack, math.min(mainVolume, 0.028), ODDITY_FADE_SECONDS)
		fade(oddityTrack, 0.085, ODDITY_FADE_SECONDS)
	else
		fade(mainTrack, mainVolume, NORMAL_FADE_SECONDS)
		fade(oddityTrack, 0, ODDITY_FADE_SECONDS)
	end
end

player:GetAttributeChangedSignal("NightShiftActive"):Connect(refreshAudio)
player:GetAttributeChangedSignal("NightShiftPhase"):Connect(refreshAudio)
player:GetAttributeChangedSignal("NightDeliveryOddityActive"):Connect(refreshAudio)

task.defer(refreshAudio)

print("Night Delivery audio director loaded")
