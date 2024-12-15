print('initializing...')

local TargetProxTime = 1/2.5

local FastWait = {
	LastHeartbeat = tick(),
	Timeout = 3
}

function FastWait.Wait(Seconds)
	local StartTime = tick()
	
	if Seconds then
		return wait(Seconds)
	else
		if tick() - FastWait.LastHeartbeat < FastWait.Timeout then
			return
		else
			FastWait.LastHeartbeat = tick()
			return wait()
		end
	end

end

local function SafeRecursiveGetChildren(Parent, MaxDepth, ClassesToRecurse)

	local Children = {}
	local function RecursiveGetChildren(Parent, Depth)

		--print("Scanning " .. Parent.Name .. " at depth " .. Depth)

		FastWait.Wait()

		if Depth >= MaxDepth then
			return
		end

		for _, Child in next, Parent:GetChildren() do
			if not ClassesToRecurse or table.find(ClassesToRecurse, Child.ClassName) then
				table.insert(Children, Child)
				RecursiveGetChildren(Child, Depth + 1)
			end
		end
	end

	RecursiveGetChildren(Parent, 0)
	--print("Done scanning " .. Parent.Name)
	return Children
end

local ScanLocations = {}

print("Waiting for grabbable items...")

table.insert(ScanLocations,
	game.Workspace:WaitForChild("ScriptableParts"):WaitForChild("Civilians"):WaitForChild("HeistStorage")
)

print("Waiting for county bank objects...")

table.insert(ScanLocations,
	game.Workspace:WaitForChild("World"):WaitForChild("Buildings"):WaitForChild("Commercial"):WaitForChild("CountyBank"):WaitForChild("ScriptableParts"):WaitForChild("CurrentModule")
)

print("Waiting for city bank objects...")

table.insert(ScanLocations,
	game.Workspace:WaitForChild("World"):WaitForChild("Buildings"):WaitForChild("Commercial"):WaitForChild("CityBank"):WaitForChild("ScriptableParts"):WaitForChild("CurrentModule")
)

print("Waiting for tech store objects...")

table.insert(ScanLocations,
	game.Workspace:WaitForChild("World"):WaitForChild("Buildings"):WaitForChild("Commercial"):WaitForChild("TCStore"):WaitForChild("ScriptableParts"):WaitForChild("DisplayTables")
)

print("All locations found! Initializing loop...")

local function IsPrompt(Object)
	if Object.Name == "PP" and Object:FindFirstChild("InteractableObject") then
		return true
	end

	return false
end

local function GetPrompts(Parent)

	local Prompts = {}

	local Children = SafeRecursiveGetChildren(Parent, 5)

	for _, Child in next, Children do
		if IsPrompt(Child) then
			table.insert(Prompts, Child)
		end
	end

	if #Prompts == 0 then
		print("No prompts found in " .. Parent.Name)
	end

	return Prompts

end

local function SetPromptTime(Prompt, TimeValue)

	if not Prompt then
		return 0
	end

	_Prompt = Prompt
	Prompt = Prompt:FindFirstChild("InteractableObject")

	if not Prompt then
		warn("[PANIC] Prompt is missing InteractableObject")
		return 0
	end

	local Percentage = Prompt:FindFirstChild("Percentage")
	if Percentage then
		local Time = Percentage:FindFirstChild("Time")
		if Time then
			setvalue(Time.Data, TimeValue)
			--print(Time.Value)
		end
	end

	return 1
end

local function GetPromptTime(Prompt)

	Prompt = Prompt:FindFirstChild("InteractableObject")

	local Percentage = Prompt:FindFirstChild("Percentage")
	if Percentage then
		local Time = Percentage:FindFirstChild("Time")
		if Time then
			return Time.Value
		end
	end

	return 0
end

-- local function SetPromptRange(Prompt, RangeValue)

-- 	Prompt = Prompt:FindFirstChild("InteractableObject")

-- 	local Range = Prompt:FindFirstChild("Range")
-- 	if Range then
-- 		local Distance = Range:FindFirstChild("Distance")
-- 		if Distance then
-- 			setvalue(Distance.Data, RangeValue)
-- 			--print(Distance.Value)
-- 		end
-- 	end
-- end

-- local function SetPromptVisibilityRequired(Prompt, VisibilityRequiredValue)
	
-- 	Prompt = Prompt:FindFirstChild("InteractableObject")

-- 	local NeedsRay = Prompt:FindFirstChild("NeedsRay")
-- 	if NeedsRay then
-- 		setvalue(NeedsRay.Data, VisibilityRequiredValue)
-- 		--print(NeedsRay.Value)
-- 	end

-- 	local NeedsTool = Prompt:FindFirstChild("RequiresTool")
-- 	if NeedsTool then
-- 		setvalue(NeedsTool.Data, VisibilityRequiredValue)
-- 		--print(NeedsTool.Value)
-- 	end

-- end


-- Main loop

local PromptCache = {}
local Loops = 0
local Done = false

spawn(function()

	while not Done do

		Loops = Loops + 1

		wait(1)

		for _, Location in next, ScanLocations do
			local Prompts = GetPrompts(Location)
			for _, Prompt in next, Prompts do
				--print("Updating prompt " .. Prompt.Name)
				if not PromptCache[Prompt] then
					PromptCache[Prompt] = {Prompt = Prompt, OriginalTime = GetPromptTime(Prompt), Modified = false}
				end
			end
		end

		if Loops > 9e9 then -- ignore, was for testing, not touching it now
			Done = true
			break
		end

	end

end)

function count(tbl)
    local elementCount = 0
    for _ in pairs(tbl) do
        elementCount = elementCount + 1
    end
    return elementCount
end

spawn(function()

	while not Done do

		if getpressedkey() == "F6" then
			Done = true
			print("[PANIC] User requested exit, closing threads...")
			break
		end

		wait()

		print("Updating " .. count(PromptCache) .. " prompts...")

		for i, PromptData in next, PromptCache do
			local StillActive = SetPromptTime(PromptData.Prompt, PromptData.OriginalTime * TargetProxTime)  
			-- SetPromptRange(Prompt, 10)
			-- SetPromptVisibilityRequired(Prompt, false)

			if StillActive == 0 then
				warn("Removing inactive prompt " .. PromptData.Prompt.Name)
				PromptCache[i] = nil
			end

		end

	end

end)