-- Night Delivery bike riding pose and pedal animation.
-- Supports standard R6 and R15 character joints without external animation assets.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local characterStates = {}

local function cacheCharacter(player, character)
	task.spawn(function()
		local humanoid = character:WaitForChild("Humanoid", 10)
		if not humanoid then
			return
		end
		task.wait()

		local joints = {}
		for _, object in ipairs(character:GetDescendants()) do
			if object:IsA("Motor6D") or object:IsA("AnimationConstraint") then
				joints[object.Name] = object
			end
		end

		characterStates[player] = {
			character = character,
			humanoid = humanoid,
			joints = joints,
			phase = 0,
			wasBikeActive = false,
		}
	end)
end

local function watchPlayer(player)
	player.CharacterAdded:Connect(function(character)
		cacheCharacter(player, character)
	end)
	player.CharacterRemoving:Connect(function(character)
		local state = characterStates[player]
		if state and state.character == character then
			characterStates[player] = nil
		end
	end)

	if player.Character then
		cacheCharacter(player, player.Character)
	end
end

for _, player in ipairs(Players:GetPlayers()) do
	watchPlayer(player)
end
Players.PlayerAdded:Connect(watchPlayer)
Players.PlayerRemoving:Connect(function(player)
	characterStates[player] = nil
end)

local function poseJoint(joints, name, pitch, yaw, roll)
	local joint = joints[name]
	if joint and joint.Parent then
		joint.Transform = CFrame.Angles(math.rad(pitch), math.rad(yaw or 0), math.rad(roll or 0))
	end
end

local function resetBikePose(state)
	for _, joint in pairs(state.joints) do
		if joint and joint.Parent and joint:IsA("Motor6D") then
			joint.Transform = CFrame.identity
		end
	end
end

RunService.PreSimulation:Connect(function(deltaTime)
	for player, state in pairs(characterStates) do
		if not state.character.Parent or not state.humanoid.Parent then
			characterStates[player] = nil
			continue
		end
		local bikeActive = player:GetAttribute("BikeActive") == true
		if not bikeActive then
			if state.wasBikeActive then
				resetBikePose(state)
				state.wasBikeActive = false
			end
			continue
		end
		state.wasBikeActive = true

		local isMoving = state.humanoid.MoveDirection.Magnitude > 0.05
		state.phase += deltaTime * (isMoving and 9 or 0.25)
		local pedal = math.sin(state.phase) * (isMoving and 18 or 2)
		local leftHip = 52 + pedal
		local rightHip = 52 - pedal

		-- Lean over the handlebars and reach forward.
		if state.joints.Waist then
			poseJoint(state.joints, "Waist", 9, 0, 0)
		else
			poseJoint(state.joints, "RootJoint", 7, 0, 0)
		end

		poseJoint(state.joints, "RightShoulder", 72, 0, -10)
		poseJoint(state.joints, "LeftShoulder", 72, 0, 10)
		poseJoint(state.joints, "Right Shoulder", 72, 0, -10)
		poseJoint(state.joints, "Left Shoulder", 72, 0, 10)

		-- R15 knees bend and alternate; R6 legs pedal from the hips.
		poseJoint(state.joints, "RightHip", rightHip, 0, 0)
		poseJoint(state.joints, "LeftHip", leftHip, 0, 0)
		poseJoint(state.joints, "Right Hip", rightHip, 0, 0)
		poseJoint(state.joints, "Left Hip", leftHip, 0, 0)
		poseJoint(state.joints, "RightKnee", -48 + pedal * 0.55, 0, 0)
		poseJoint(state.joints, "LeftKnee", -48 - pedal * 0.55, 0, 0)
		poseJoint(state.joints, "RightAnkle", 12 - pedal * 0.2, 0, 0)
		poseJoint(state.joints, "LeftAnkle", 12 + pedal * 0.2, 0, 0)
		poseJoint(state.joints, "RightElbow", -18, 0, 0)
		poseJoint(state.joints, "LeftElbow", -18, 0, 0)
	end
end)
