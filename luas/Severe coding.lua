--common issue I've had before : Forgetting to put a delay like 0.001 into the wait function as it otherwise causes the render thread to crash
local Workspace = getchildren(Game)[1] -- nuh uh
local localPlayer = getlocalplayer() -- the voices
local localPlayerChar = getcharacter(localPlayer) -- in my head
local localHrp = nil 
local players = findfirstchildofclass(Game, "Players")
local MouseService = findfirstchildofclass(Game, "MouseService")
local camera = findfirstchildofclass(Workspace, "Camera")
local lighting = findfirstchildofclass(Game, "Lighting")

local function isModel(instance)
	if getclassname(instance) == "Model" then
		return true
	end
	return false
end

local function getfullname(instance)
	local res = ""
	local currentParent = instance
	for i = 1,100 do
		local name = getname(currentParent)
		res = name == "Game" and "Game"..res or "[\""..name.."\"]"..res

		currentParent = getparent(currentParent)
		if currentParent == nil then
			break
		end
	end 
	return res
end

local function getCamPos()
	return camera ~= nil and getposition(camera)
end

local function isInPlayerList(instance)
	local players = findfirstchildofclass(Game, "Players", true)
	if players == nil then return end
	local children = getchildren(players)
	if children == nil then return end
	for i,player in pairs(children) do
		local name = getname(player)
		if name == nil then return end
		local targetName = getname(instance)
		if targetName == nil then return end
		if string.find(string.lower(targetName), string.lower(name)) then
			return true
		end
	end
	return false
end

local function dumpInstance(instance)
	local dumpSize = 1
	local totalDumpSize = 0

	
	local descendants = getdescendants(instance); wait(2); if descendants == nil then totalDumpSize = 0 else totalDumpSize = #descendants end
	
    local finalStr = "local dump = {\n"
    local recentUpdates = 0
	
    local function listChildren(instance, indent)
		if getpressedkey() == "End" then print("dump aborted") return end
        local instanceChildren = getchildren(instance, true)
        if instanceChildren ~= nil then
			
            for i,v in pairs(instanceChildren) do
                local name = getname(v)
                local className = getclassname(v)
                local indentStr = string.rep("    ", indent)
				if string.len(name) <= 0 or string.len(className) <= 0 then
					continue
				end
                finalStr = finalStr .. indentStr .. "[\"" .. name .. "\"] = {\n"
                finalStr = finalStr .. indentStr .. "    ClassName = \"" .. className .. "\",\n"
                listChildren(v, indent + 1)
                finalStr = finalStr .. indentStr .. "},\n"
            end
        end
		if recentUpdates > totalDumpSize/100 then
			print(dumpSize, totalDumpSize)
			recentUpdates = 0
		end 
		recentUpdates += 1
		dumpSize += 1
    end
    
    listChildren(instance, 1)
    finalStr = finalStr .. "}\n\nreturn dump"
	if webSocket ~= nil then
		local ws = websocket_connect(webSocket)
		if ws ~= nil then
			websocket_send(ws , finalStr)
			websocket_close(ws)
		end 
	end 
	writefile(time().."_dump.lua", finalStr)
    return finalStr
end

local function onChildAdded(instance, callback)
	local instanceEntries = {}
	local firstRun = true
	local function funiThread()
		while exitThread ~= true do
			local parent = getparent(instance); if parent == nil then break end
			for i,v in pairs(instanceEntries) do
				if i == nil or v == nil then continue end
				local parent = getparent(i); if parent == nil then instanceEntries[i] = nil end
			end
			local children = getchildren(Workspace); if children == nil then continue end
			for i,v in pairs(children) do
				if instanceEntries[v] ~= nil then continue end
				instanceEntries[v] = v
				if firstRun == true then continue end
				callback(v)
			end
			firstRun = false
			wait(.1)
		end
	end
	spawn(funiThread)
end

local function getDescendantsOfName(targetFolder, targetNames, useParentName)
	local descendants = getdescendants(targetFolder); if descendants == nil then return end;
	local nearbyInstances = {}
	local loops,maxloops = 0,200
	for i,v in pairs(descendants) do
		if loops < maxloops then loops += 1 else loops = 0 wait() end
		local className = getclassname(v); if className == nil then continue end;
		if className ~= "Part" and className ~= "MeshPart" then continue end;
		local Pos3D = getposition(v); if Pos3D == nil then continue end;
		local parent = getparent(v); if parent == nil then continue end;
		local name = useParentName == false and getname(v) or getname(parent); if name == nil then continue end;

		if not table.find(targetNames, name) then continue end;
		table.insert(nearbyInstances, not useParentName and v or useParentName and parent)
	end
	return nearbyInstances
end

local function getChildrenInDepth(parent, depth)
    local totalChildren = {}
    local function gatherChildren(instance, currentDepth)
        if currentDepth > depth then
            return
        end
        local children = getchildren(instance)
        if children ~= nil then
			local loops,maxloops = 0,250
            for i, v in pairs(children) do
				if loops < maxloops then loops += 1 else loops = 0 wait(.001) end
                table.insert(totalChildren, v)
                gatherChildren(v, currentDepth + 1)
            end
        end
    end
    gatherChildren(parent, 1)

	return totalChildren
end

local function setupESP(targetFolder, espType)
	local customESP = {
		RenderDistance = 500,
		CacheCooldown = 10,
		CacheSpeed = 100,
		DistanceScalingFactor = 100,
		BlacklistedStrings = {},
		WhitelistedStrings = {},
		CustomColors = {},
		UseBlacklist = true,
		UseParentForFilter = false,
		ScaleWithDist = false,
		BlacklistedChildren = {},
		instances = {}
	}

	function customESP:shouldExclude(instance, parent, name, parentName)
		if self.UseParentForFilter then
			return table.find(self.BlacklistedStrings, parentName)
		elseif not self.UseParentForFilter then
			return table.find(self.BlacklistedStrings, name)
		end
		return true
	end

	function customESP:getHealth(instance, parent)
		local health = {
			Current = 0,
			Max = 0
		}
		parent = parent or getparent(instance)
		local humanoid = findfirstchildofclass(parent, "Humanoid", true)
		if humanoid ~= nil then
			health.Current = gethealth(humanoid)
			health.Max = getmaxhealth(humanoid)
		else
			return false
		end
		return health
	end

	function customESP:getInstances(targetFolder)
		return getdescendants(targetFolder)
	end
	
	local exitThread = false
	
	local function keybindThread()
		while exitThread ~= true do wait()
			local currentPressedKey = getpressedkey()
			if currentPressedKey == "End" and lastPressedKey == "End" then
				exitThread = true
				break
			end
			lastPressedKey = currentPressedKey
		end
		Drawing.clear()
		print("KeybindThread stopped.")
	end
	
	if espType == "Part" then
		local function cacheThread()
			while exitThread ~= true do wait(customESP.CacheCooldown)
				--customESP.instances = {}
				local targetInstances = customESP:getInstances(targetFolder); if targetInstances == nil then continue end;
				local loops,maxloops = 0,customESP.CacheSpeed
				for i,v in pairs(targetInstances) do
					if exitThread == true then break end
					if loops < maxloops then loops += 1 else loops = 0 wait(.001) end

					local parent = getparent(v); if parent == nil then continue end;
					local className = getclassname(v); if className == nil then continue end;
					if className ~= "Part" and className ~= "MeshPart" then continue end;
					local name = getname(v); if name == nil then continue end;
					local parentName = getname(parent); if parentName == nil then continue end;
					if customESP.UseBlacklist then
						if customESP:shouldExclude(v, parent, name, parentName) then continue end;
					else
						if not customESP:shouldExclude(v, parent, name, parentName) then continue end;
					end

					local part = customESP.UseParentForFilter == false and v or parent
					if customESP.instances[part] ~= nil then continue end;
					customESP.instances[part] = {
						["Part"] = v,
						["Drawing"] = Drawing.new("Text")
					}
					--print(name, className)
				end
			end
			print("CacheThread stopped.")
		end
		
		local function renderThread()
			while exitThread ~= true do wait(.001)
				camera = findfirstchildofclass(Workspace, "Camera", true); if camera == nil then return end
				local camPos = getposition(camera); if camPos == nil then return end
				for i,v in pairs(customESP.instances) do
					if exitThread == true then break end
					if i == nil or v == nil then v.Drawing:Remove(); customESP.instances[i] = nil; continue end;
					if v.Part == nil or v.Drawing == nil then v.Drawing:Remove(); customESP.instances[i] = nil; continue end;
					local parent = getparent(v.Part); if parent == nil then v.Drawing:Remove(); customESP.instances[i] = nil; continue end;
					local Pos3D = getposition(v.Part); if Pos3D == nil then v.Drawing:Remove(); customESP.instances[i] = nil; continue end;
					local Pos2D, OnScreen = worldtoscreenpoint({Pos3D.x, Pos3D.y, Pos3D.z}); if Pos2D == nil or OnScreen == nil then v.Drawing:Remove(); continue end
					
					local direction = {x = camPos.x - Pos3D.x, y = camPos.y - Pos3D.y, z = camPos.z - Pos3D.z}; if direction == nil then continue end 
					local dist = Vector3.Magnitude(direction); if dist == nil or dist > customESP.RenderDistance then v.Drawing.Visible = false; continue end
					local name = getname(i);
					local customColor = customESP.CustomColors[name] or {255,255,255}
					local HP = customESP:getHealth(v.Part)
					
					v.Drawing.Visible = OnScreen
					v.Drawing.Center = true
					v.Drawing.Outline = true
					v.Drawing.Size = customESP.ScaleWithDist and math.max(math.min(12/(dist/customESP.DistanceScalingFactor), 12), 2) or not customESP.ScaleWithDist and 12
					v.Drawing.Color = customColor
					--v.Drawing.Font = 0
					v.Drawing.Position = {Pos2D.x, Pos2D.y}
					v.Drawing.Text = (HP ~= nil and HP ~= false) and string.format("[%s]\n[%.1f / %.1fHP]\n[%.0f]", name, HP.Current, HP.Max, dist) or string.format("[%s]\n[%.0f]", name, dist)
				end
			end
			Drawing.clear()
			print("RenderThread stopped.")
		end
		
		spawn(keybindThread)
		spawn(cacheThread)
		spawn(renderThread)
	end
	
	return customESP
end


local function getNearbyParts()
	local workspaceDescendants = getdescendants(Workspace); if workspaceDescendants == nil then return end;
	local nearbyParts = {}
	camera = findfirstchildofclass(Workspace, "Camera", true); if camera == nil then return end;
	local camPos = getposition(camera); if camPos == nil then return end;
	local loops,maxloops = 0,100
	for i,v in pairs(workspaceDescendants) do
		if loops < maxloops then loops += 1 else loops = 0 wait() end
		local className = getclassname(v); if className == nil then continue end;
		if className ~= "Part" and className ~= "MeshPart" then continue end;
		local Pos3D = getposition(v); if Pos3D == nil then continue end;
		local direction = {
			x = Pos3D.x - camPos.x,
			y = Pos3D.y - camPos.y,
			z = Pos3D.z - camPos.z
		}
		local dist = math.sqrt(direction.x^2 + direction.y^2 + direction.z^2)
		table.insert(nearbyParts, {
			Part = v,
			Dist = dist
		})

	end
	table.sort(nearbyParts, function(a,b)
		return a.Dist < b.Dist
	end)
	return nearbyParts
end

local function teleportChildrenToPos(targetFolder, targetPos, offset)
	local children = getchildren(targetFolder); if children == nil then return end;
	for i,v in pairs(children) do
		local className = getclassname(v); if className == nil then continue end;
		if className ~= "Part" and className ~= "MeshPart" then continue end;
		setposition(v, {targetPos[1], targetPos[2], targetPos[3]})
		--print(getname(v), targetPos[1], targetPos[2], targetPos[3])
	end
end

local function teleportChildrenToCF(targetFolder, targetCF, offset)
	local children = getchildren(targetFolder); if children == nil then return end;
	for i,v in pairs(children) do
		local className = getclassname(v); if className == nil then continue end;
		if className ~= "Part" and className ~= "MeshPart" then continue end;
		local newCF = targetCF
		newCF.position.x += offset[1] * i
		newCF.position.y += offset[2] * i
		newCF.position.z += offset[3] * i
		setcframe(v, targetCF)
		--print(getname(v), targetPos[1], targetPos[2], targetPos[3])
	end
end

local freeCam = {
	["State"] = false,
}

local function freeCamThread()
	local oldPos, freeCamPos = nil,nil
	oldPos, freeCamPos = getposition(camera), getposition(camera)
	local oldCameraSubject = nil
	local tpToFreeCam = false

	local function update()
		camera = findfirstchildofclass(Workspace, "Camera", true)
		local camLookVector = getlookvector(camera)
		local camRightVector = getrightvector(camera)
		if camLookVector ~= nil and camRightVector ~= nil then
			if getpressedkey() == "W" then
				freeCamPos.x += camLookVector.x*1
				freeCamPos.y += camLookVector.y*1
				freeCamPos.z += camLookVector.z*1
			end
			
			if getpressedkey() == "S" then -- maybe if multi keypress support is added then we can finally strafe around diagonally
				freeCamPos.x -= camLookVector.x*1
				freeCamPos.y -= camLookVector.y*1
				freeCamPos.z -= camLookVector.z*1
			end
			
			if getpressedkey() == "A" then
				freeCamPos.x -= camRightVector.x*1
				freeCamPos.y -= camRightVector.y*1
				freeCamPos.z -= camRightVector.z*1
			end
			
			if getpressedkey() == "D" then
				freeCamPos.x += camRightVector.x*1
				freeCamPos.y += camRightVector.y*1
				freeCamPos.z += camRightVector.z*1
			end
		
			localHrp = findfirstchild(localPlayerChar, "HumanoidRootPart", true); 
			if localHrp ~= nil then
				if tpToFreeCam == true then
					camera = findfirstchildofclass(Workspace, "Camera", true); if camera == nil then return end
					local cameraCF = getcframe(camera); if cameraCF == nil then return end
					setcframe(localHrp, cameraCF)
				end
			end
			
			if freeCamPos ~= nil then
				setposition(camera, {freeCamPos.x, freeCamPos.y, freeCamPos.z})
			end
		end
	end
	
	local lastPressedKey = "None"
	local tpKey = "XButton1" -- "PageDown"
	while getpressedkey() ~= "End" do wait()
		update()
		lastPressedKey = currentPressedKey
	end
end


--[[
	List of games to choose :
		Fallen
		Doors
		LoneSurvival
		AR2
		Oaklands
		EntryPoint
		TheSurvivalGame
		TheWildWest
--]]
local targetGame = "TheWildWest"


if targetGame == "Fallen" then
	do -- fallen survival
		local exitThread = false


		local itemESP = {
			["State"] = false,
			["IncludeDrops"] = true,
			["RenderDistance"] = 3500,
			["BlacklistedNames"] = {
				"Sleeping Bag",
				"Sleeping Bag",
				"External Stone Wall",
				"External Stone Gate",
				"External Wooden Gate",
				"External Wooden Wall",
				"Oil Barrel",
				"Trash Can",
				"Door",
				"Ladder"
			},
			["Items"] = {}
		}
		
		local npcESP = {
			["State"] = true,
			["RenderDistance"] = 5000,
			["Npcs"] = {}
		}
		
		local nodeESP = {
			["State"] = true,
			["RenderDistance"] = 500,
			["Colors"] = {
				Stone = {0.7, 0.7, 0.7},
				Metal = {0.803, 0.521, 0.247},
				Phosphate = {1,1,0}
			},
			["Nodes"] = {}
		}
		
		local function keybindThread()
			while exitThread ~= true do 
				if getpressedkey() == "End" then 
					exitThread = true 
					Drawing.clear()
				end
				wait()
			end 
			print("KeybindThread stopped")
		end

		local function cacheThread()
			local function cacheItems()
				if itemESP.State ~= true then return end
				print("started caching items")
				local bases = findfirstchild(Workspace, "Bases", true); if bases == nil then return end 
				local loners = findfirstchild(bases, "Loners", true); if loners == nil then return end 
				local drops = findfirstchild(Workspace, "Drops", true); if drops == nil then return end 
				
				local lonersChildren = getchildren(loners); if lonersChildren == nil then return end 
				local loops,maxloops = 0,200
				for i,v in pairs(lonersChildren) do
					local className = getclassname(v); if className == nil then continue end
					if className ~= "Folder" then continue end
					local items = getchildren(v); if items == nil then continue end
					for i2, item in pairs(items) do
						if loops < maxloops then loops += 1 else loops = 0 wait() end
						if itemESP.Items[item] ~= nil then continue end
						local className = getclassname(item); if className == nil then continue end 
						if className ~= "Model" then continue end
						local name = getname(item); if name == nil then continue end
						if table.find(itemESP.BlacklistedNames, name) then continue end
						local primaryPart = getprimarypart(item); if primaryPart == nil then continue end 
						local primaryPartClass = getclassname(primaryPart); if primaryPartClass ~= "Part" and primaryPartClass ~= "MeshPart" then continue end
						

						itemESP.Items[item] = {
							["Part"] = primaryPart,
							["Drawing"] = Drawing.new("Text")
						}
						--print(getname(item), getfullname(primaryPart))
					end 
				end 
				
				
				
				if itemESP.IncludeDrops == true then
					local dropsChildren = getchildren(drops); if dropsChildren == nil then return end
					local loops,maxloops = 0,30
					for i, item in pairs(dropsChildren) do 
						if loops < maxloops then loops += 1 else loops = 0 wait() end
						if itemESP.Items[item] ~= nil then continue end
						local className = getclassname(item); if className == nil then continue end 
						if className ~= "Model" then continue end
						local name = getname(item); if name == nil then continue end 
						if table.find(itemESP.BlacklistedNames, name) then continue end 
						local primaryPart = getprimarypart(item); if primaryPart == nil then continue end 
						local primaryPartClass = getclassname(primaryPart); if primaryPartClass == nil then continue end 
						if primaryPartClass ~= "Part" and primaryPartClass ~= "MeshPart" then continue end
						
						itemESP.Items[item] = {
							["Part"] = primaryPart,
							["Drawing"] = Drawing.new("Text")
						}
						--print(getname(item), getfullname(primaryPart))
					end 
				end
				print("stopped caching items")
			end 
		
			local function cacheNpcs()
				if npcESP.State ~= true then return end
				print("started caching npcs")
				local militaryFolder = findfirstchild(Workspace, "Military", true); if militaryFolder == nil then return end -- for now atleast
				local militaryPlaces = getchildren(militaryFolder); if militaryPlaces == nil then return end 
				local loops,maxloops = 0,30
				for index, place in pairs(militaryPlaces) do
					local className = getclassname(place); if className == nil then continue end 
					if className ~= "Folder" then continue end
					local placeChildren = getchildren(place); if placeChildren == nil then continue end
					for i,npc in pairs(placeChildren) do 
						if loops < maxloops then loops += 1 else loops = 0 wait() end
						if npcESP.Npcs[npc] ~= nil then continue end
						local className = getclassname(npc); if className == nil then continue end 
						if className ~= "Model" then continue end 
						local primaryPart = getprimarypart(npc); if primaryPart == nil then continue end 
						local primaryPartClass = getclassname(primaryPart); if primaryPartClass == nil then continue end 
						if primaryPartClass ~= "Part" and primaryPartClass ~= "MeshPart" then continue end
						local humanoid = findfirstchildofclass(npc, "Humanoid", true); if humanoid == nil then continue end
						
						npcESP.Npcs[npc] = {
							["Part"] = primaryPart,
							["Humanoid"] = humanoid,
							["Drawing"] = Drawing.new("Text")
						}
						--print(getname(npc), getfullname(primaryPart))
					end
				end
				print("stopped caching npcs")				
			end
			
			local function cacheNodes()
				if nodeESP.State ~= true then return end
				print("started caching nodes")
				local nodeFolder = findfirstchild(Workspace, "Nodes", true); if nodeFolder == nil then return end
				local nodes = getchildren(nodeFolder); if nodes == nil then return end
				local loops,maxloops = 0,30
				for i,node in pairs(nodes) do 
					if loops < maxloops then loops += 1 else loops = 0 wait() end
					if nodeESP.Nodes[node] ~= nil then continue end
					local className = getclassname(node); if className == nil then continue end
					if className ~= "Model" then continue end
					local primaryPart = findfirstchild(node, "Main", true); if primaryPart == nil then continue end
					local primaryPartClass = getclassname(primaryPart); if primaryPartClass == nil then continue end
					if primaryPartClass ~= "Part" and primaryPartClass ~= "MeshPart" then continue end
					
					nodeESP.Nodes[node] = {
						["Part"] = primaryPart,
						["Drawing"] = Drawing.new("Text")
					}
				end
				print("stopped caching nodes")
			end 
			
			while exitThread == false do 
				print("started caching")
				cacheItems()
				cacheNpcs()
				cacheNodes()
				print("stopped caching\n")
				wait()
			end
			print("CacheThread stopped")
		end
		
		local function renderThread()
			local function renderItems()
				if itemESP.State ~= true then return end
				camera = findfirstchildofclass(Workspace, "Camera", true); if camera == nil then return end
				local camPos = getposition(camera); if camPos == nil then return end
				for i,v in pairs(itemESP.Items) do 
					if v == nil or i == nil then continue end
					if v.Part == nil or v.Drawing == nil then continue end
					local parent = getparent(i); if parent == nil then v.Drawing:Remove(); itemESP.Items[i] = nil continue end
					local Pos3D = getposition(v.Part); if Pos3D == nil then v.Drawing:Remove(); continue end
					local Pos2D, OnScreen = worldtoscreenpoint({Pos3D.x, Pos3D.y, Pos3D.z}); if Pos2D == nil or OnScreen == nil then continue end
					
					local direction = {x = camPos.x - Pos3D.x, y = camPos.y - Pos3D.y, z = camPos.z - Pos3D.z}; if direction == nil then continue end 
					local dist = math.sqrt(direction.x^2, direction.y^2, direction.z^2); if dist == nil or dist > itemESP.RenderDistance then v.Drawing.Visible = false; continue end
					
					v.Drawing.Visible = OnScreen
					v.Drawing.Center = true
					v.Drawing.Outline = true
					v.Drawing.Size = 12
					v.Drawing.Color = {255,255,255}
					v.Drawing.Position = {Pos2D.x, Pos2D.y}
					v.Drawing.Text = string.format("[%s]\n[%.0f]", getname(i), dist)
				end 
			end 
			
			local function renderNpcs()
				if npcESP.State ~= true then return end
				camera = findfirstchildofclass(Workspace, "Camera", true); if camera == nil then return end
				local camPos = getposition(camera); if camPos == nil then return end
				for i,v in pairs(npcESP.Npcs) do 
					if i == nil or v == nil then continue end
					if v.Part == nil or v.Drawing == nil then continue end
					local parent = getparent(v.Part); if parent == nil then v.Drawing:Remove(); npcESP.Npcs[i] = nil; continue end
					local humanoidParent = getparent(v.Humanoid);
					local Pos3D = getposition(v.Part); if Pos3D == nil then continue end
					local Pos2D, OnScreen = worldtoscreenpoint({Pos3D.x, Pos3D.y, Pos3D.z}); if Pos2D == nil or OnScreen == nil then continue end
					
					local direction = {x = camPos.x - Pos3D.x, y = camPos.y - Pos3D.y, z = camPos.z - Pos3D.z}; if direction == nil then continue end 
					local dist = math.sqrt(direction.x^2, direction.y^2, direction.z^2); if dist == nil or dist > npcESP.RenderDistance then v.Drawing.Visible = false; continue end
					local humanoidHealth = humanoidParent ~= nil and gethealth(v.Humanoid) or 0; if humanoidHealth == nil then continue end

					v.Drawing.Visible = OnScreen
					v.Drawing.Center = true
					v.Drawing.Outline = true
					v.Drawing.Size = 12
					v.Drawing.Color = {255,0,0.5}
					v.Drawing.Position = {Pos2D.x, Pos2D.y}
					v.Drawing.Text = string.format("[%s]\n[%.0f Studs]\n[%.0f HP]", getname(i), dist, humanoidHealth)
				end 
			end
			
			local function renderNodes()
				if nodeESP.State ~= true then return end
				camera = findfirstchildofclass(Workspace, "Camera", true); if camera == nil then return end
				local camPos = getposition(camera); if camPos == nil then return end
				for i,v in pairs(nodeESP.Nodes) do 
					if i == nil or v == nil then continue end
					if v.Part == nil or v.Drawing == nil then continue end
					local parent = getparent(i); if parent == nil then v.Drawing:Remove(); nodeESP.Nodes[i] = nil; continue end
					local name = getname(i); if name == nil then continue end
					name = string.gsub(name, "_Node", "")
					local Pos3D = getposition(v.Part); if Pos3D == nil then v.Drawing:Remove(); continue end
					local Pos2D, OnScreen = worldtoscreenpoint({Pos3D.x, Pos3D.y, Pos3D.z}); if Pos2D == nil or OnScreen == nil then continue end
					
					local direction = {x = camPos.x - Pos3D.x, y = camPos.y - Pos3D.y, z = camPos.z - Pos3D.z}; if direction == nil then continue end 
					local dist = math.sqrt(direction.x^2, direction.y^2, direction.z^2); if dist == nil or dist > nodeESP.RenderDistance then v.Drawing.Visible = false; continue end
					
					
					local customColor = nodeESP.Colors[name]
					
					v.Drawing.Visible = OnScreen
					v.Drawing.Center = true
					v.Drawing.Outline = true
					v.Drawing.Size = 12
					v.Drawing.Color = customColor or {255,255,255}
					v.Drawing.Position = {Pos2D.x, Pos2D.y}
					v.Drawing.Text = string.format("[%s]\n[%.0f]", name, dist)
				end
			end
			
			while exitThread == false do -- render loop
				renderItems()
				renderNpcs()
				renderNodes()
				wait()
			end
			print("RenderThread stopped")
		end


		spawn(keybindThread)
		spawn(cacheThread)
		spawn(renderThread)
	end
elseif targetGame == "Doors" then 
	do -- Doors
		local exitThread = false
		local debugging = true
		
		

	
	
		local interactableESP = {
			["State"] = true,
			["RenderDistance"] = 300,
			["Interactables"] = {},
			["Blacklisted"] = {
				"Knobs",
				"Wardrobe",
				"Bed",
				"DoubleBed",
				"Typewriter",
				"Bed_Infirmary"
			}
		}
		

	
		local function cacheThread()
			local function cacheInteractables()
				local currentRoomsFolder = findfirstchild(Workspace, "CurrentRooms", true); if currentRoomsFolder == nil then return end
				local currentRoomsDescendants = getdescendants(currentRoomsFolder); if currentRoomsDescendants == nil then return end
				
				local loops,maxloops = 0,40
				for i2, v2 in pairs(currentRoomsDescendants) do
					if loops < maxloops then loops += 1 else loops = 0 wait() end
					local className = getclassname(v2); if className == nil then continue end
					if getname(v2) == "ActivateEventPrompt" then
						local parent = getparent(v2); if parent == nil then continue end
						local parentClass = getclassname(parent); if parentClass == nil then continue end
						local parentName = getname(parent); if parentName == nil then continue end
						if parentName == "Knobs" then continue end
						if parentClass == "MeshPart" and parentClass == "Part" then
							if interactableESP.Interactables[parent] ~= nil then continue end
							interactableESP.Interactables[parent] = {
								["Part"] = parent,
								["Drawing"] = Drawing.new("Text"),
								["Color"] = {255,255,255}
							}
						elseif parentClass == "Model" then
							local primaryPart = getprimarypart(parent); if primaryPart == nil then continue end
							if interactableESP.Interactables[parent] ~= nil then continue end
							interactableESP.Interactables[parent] = {
								["Part"] = primaryPart,
								["Drawing"] = Drawing.new("Text"),
								["Color"] = {255,255,255}
							}
						else
							continue
						end
					elseif getname(v2) == "RoomEntrance" or getname(v2) == "RoomeExit" then
						if interactableESP.Interactables[v2] ~= nil then continue end
						interactableESP.Interactables[v2] = {
							["Part"] = v2,
							["Drawing"] = Drawing.new("Text"),
							["Color"] = {1,1,0}
						}
					elseif className == "ProximityPrompt" then
						local parent = getparent(v2); if parent == nil then continue end
						local parentName = getname(parent); if parentName == nil then continue end
						if table.find(interactableESP.Blacklisted, parentName) then continue end
						if string.find(parentName, "Painting") or string.find(parentName, "Fireplace") then continue end
						local parentClass = getclassname(parent); if parentClass == nil then continue end
						if parentClass == "Model" then
							local primaryPart = getprimarypart(parent); if primaryPart == nil then continue end
							--print(getfullname(primaryPart))
							if interactableESP.Interactables[parent] ~= nil then continue end
							interactableESP.Interactables[parent] = {
								["Part"] = primaryPart,
								["Drawing"] = Drawing.new("Text"),
								["Color"] = {255,255,255}
							}
						else 
							continue
						end
					end 
				end
			end
			while exitThread ~= true do
				--print("started caching")
				cacheInteractables()
				--print("stopped caching")
				wait(1)
			end
			print("CacheThread stopped")
		end
		
		local function keybindThread()
			while exitThread == false do 
				if getpressedkey() == "End" then 
					exitThread = true 
					Drawing.clear()
				end
				wait()
			end 
			print("KeybindThread stopped")
		end
		
		local function renderThread()
			local function renderInteractables()
				camera = findfirstchildofclass(Workspace, "Camera", true); if camera == nil then return end
				local camPos = getposition(camera); if camPos == nil then return end
				for i,v in pairs(interactableESP.Interactables) do
					if i == nil or v == nil then continue end
					if v.Part == nil or v.Drawing == nil or v.Color == nil then continue end
					local parent = getparent(i); if parent == nil then v.Drawing.Visible = false; interactableESP.Interactables[i] = nil; continue end
					local Pos3D = getposition(v.Part); if Pos3D == nil then v.Drawing.Visible = false; continue end
					local Pos2D, OnScreen = worldtoscreenpoint({Pos3D.x, Pos3D.y, Pos3D.z}); if Pos2D == nil or OnScreen == nil then continue end
					
					local direction = {x = camPos.x - Pos3D.x, y = camPos.y - Pos3D.y, z = camPos.z - Pos3D.z}; if direction == nil then continue end 
					local dist = math.sqrt(direction.x^2, direction.y^2, direction.z^2); if dist == nil or dist > interactableESP.RenderDistance then v.Drawing.Visible = false; continue end
					local parentName = getname(i); if parentName == nil then continue end
					
					v.Drawing.Visible = OnScreen
					v.Drawing.Center = true
					v.Drawing.Outline = true
					v.Drawing.Size = 12
					v.Drawing.Color = v.Color
					v.Drawing.Position = {Pos2D.x, Pos2D.y}
					v.Drawing.Text = string.format("[%s]\n[%.0f]", parentName, dist)
					
				end
			end
		
			while exitThread ~= true do
				renderInteractables()
				wait()
			end
		end
		
		spawn(keybindThread)
		spawn(cacheThread)
		spawn(renderThread)
	end
elseif targetGame == "LoneSurvival" then 
	do -- Lone survival
		local lootCratesFolder = findfirstchild(Workspace, "LootCrates", true); if lootCratesFolder == nil then return end;
		local backpacksFolder = findfirstchild(Workspace, "DroppedPacks", true); if backpacksFolder == nil then return end;
		local droppedFolder = findfirstchild(Workspace, "Dropped", true); if droppedFolder == nil then return end;
		local resourcesFolder = findfirstchild(Workspace, "Resources", true); if resourcesFolder == nil then return end;
		local offlinePlayersFolder = findfirstchild(Workspace, "OfflinePlayers", true); if offlinePlayersFolder == nil then return end;
		--local activeRaiderXModel = findfirstchild(Workspace, "ActiveRaiderX", true); if activeRaiderXModel == nil then return end;

		local backpacksESP = setupESP(backpacksFolder, "Part")
		backpacksESP.RenderDistance = 400
		backpacksESP.UseBlacklist = true
		backpacksESP.ScaleWithDist = true
		backpacksESP.CacheCooldown = 5
		backpacksESP.CacheSpeed = 100
		backpacksESP.UseParentForFilter = true
		backpacksESP.CustomColors = {
			["Backpack"] = {1,1,0}, 
		}

		local droppedESP = setupESP(droppedFolder, "Part")
		droppedESP.RenderDistance = 100
		droppedESP.UseBlacklist = true
		droppedESP.ScaleWithDist = true
		droppedESP.CacheCooldown = 5
		droppedESP.CacheSpeed = 100
		droppedESP.UseParentForFilter = true
		
		local offlinePlayersESP = setupESP(offlinePlayersFolder, "Part")
		offlinePlayersESP.RenderDistance = 1000
		offlinePlayersESP.UseBlacklist = true
		offlinePlayersESP.ScaleWithDist = true
		offlinePlayersESP.CacheCooldown = 5
		offlinePlayersESP.CacheSpeed = 100
		offlinePlayersESP.UseParentForFilter = true

		local lootCratesESP = setupESP(lootCratesFolder, "Part")
		lootCratesESP.RenderDistance = 150
		lootCratesESP.UseBlacklist = true
		lootCratesESP.ScaleWithDist = true
		lootCratesESP.CacheCooldown = 5
		lootCratesESP.CacheSpeed = 100
		lootCratesESP.UseParentForFilter = true
		lootCratesESP.CustomColors = {
			["Military Crate"] = {0, 0.7, 0},
			["Medbag"] = {0.7, 0, 0},
			["Large Crate"] = {0.588, 0.294, 0}
		}
		
		--local activeRaiderESP = setupESP(activeRaiderXModel, "Part")
		--activeRaiderESP.RenderDistance = 15000
		--activeRaiderESP.UseBlacklist = false
		--activeRaiderESP.CacheCooldown = 30
		--activeRaiderESP.CacheSpeed = 100
		--activeRaiderESP.UseParentForFilter = true
		--activeRaiderESP.ScaleWithDist = true
		--activeRaiderESP.WhitelistedStrings = {"ActiveRaiderX"}
		
		local resourceESP = setupESP(resourcesFolder, "Part")
		resourceESP.RenderDistance = 300
		resourceESP.UseBlacklist = false
		resourceESP.CacheCooldown = 30
		resourceESP.CacheSpeed = 200
		resourceESP.UseParentForFilter = true
		resourceESP.ScaleWithDist = true
		resourceESP.WhitelistedStrings = {"Iron Ore", "Stone Ore", "Brimstone Ore"}
		resourceESP.CustomColors = {
			["Stone Ore"] = {0.7, 0.7, 0.7},
			["Iron Ore"] = {0.803, 0.521, 0.247},
			["Brimstone Ore"] = {1,1,0}
		}
	end
elseif targetGame == "Oaklands" then 
	do -- Oaklands
		local sellerPos = {x = 877.2310180664062, y = 0, z = -56.57161331176758}
		local basePos = {x = 697.0997924804688, y = 2.9413490295410156, z = -422.564208984375}

		local function teleportThread()
			local lastPressedKey = "None"
			while true do
				if getpressedkey() == "End" then print("Stopping teleport thread"); break end
				if getpressedkey() == "Delete" and lastPressedKey ~= "Delete" then
					local camCF = getcframe(camera)
					if camCF ~= nil then print(camCF.position.x, camCF.position.y, camCF.position.z) end 
				end
				
				if getpressedkey() == "Home" and lastPressedKey ~= "Home" then
					wait(1)
					local WorldFolder = findfirstchild(Workspace, "World", true)
					if WorldFolder == nil then return end
					local LooseItemsFolder = findfirstchild(WorldFolder, "LooseItems", true)
					if LooseItemsFolder == nil then return end
					
					
					local workspaceDescendants = getdescendants(LooseItemsFolder)
					if workspaceDescendants ~= nil then
						for i,v in pairs(workspaceDescendants) do
							local name = getname(v)
							if name == nil or name ~= nil and name ~= "Highlight" then continue end 
							local item = findfirstancestorofclass(v, "Model", true); if item == nil then continue end 
							local primaryPart = getprimarypart(item); if primaryPart == nil then continue end 
							local targetPos = sellerPos
							local function tpItem()
								for i = 1,100 do
									local camCF = getcframe(camera); if camCF == nil then continue end
									local primaryPartCF = getcframe(primaryPart); if primaryPartCF == nil then continue end 
									local direction = {x = targetPos.x - primaryPartCF.position.x, y = targetPos.y - primaryPartCF.position.y, z = targetPos.z - primaryPartCF.position.z}
									setvelocity(primaryPart, {direction.x, direction.y, direction.z})
									setposition(primaryPart, {targetPos.x, targetPos.y, targetPos.z})
									--print(primaryPartCF.position.x, primaryPartCF.position.y, primaryPartCF.position.z)
								end
								setvelocity(primaryPart, {0,0,0})
							end
							spawn(tpItem)
							break
						end
						print("done")
					end
				end
				lastPressedKey = getpressedkey()
				wait()
			end 
		end
		spawn(teleportThread)
	end
elseif targetGame == "AR2" then 
	do -- Apocalypse Rising 2

		local VehiclesFolder = findfirstchild(Workspace, "Vehicles", true)
		local ZombiesFolder = findfirstchild(Workspace, "Zombies", true)
		local CorpsesFolder = findfirstchild(Workspace, "Corpses", true)
		if VehiclesFolder == nil then
			return
		end
		if ZombiesFolder == nil then
			return
		end
		if CorpsesFolder == nil then
			return
		end

		VehiclesFolder = findfirstchild(VehiclesFolder, "Spawned")
		ZombiesFolder = findfirstchild(ZombiesFolder, "Mobs")
		if VehiclesFolder == nil then
			return
		end
		if ZombiesFolder == nil then
			return
		end
		
		local startTime = tick()
		local vehicleESP = {
			["State"] = false,
			["RenderDistance"] = 7500,
			["Keybind"] = "Home",
			["Vehicles"] = {}
		}
		local zombieESP = {
			["State"] = true,
			["RenderDistance"] = 5000,
			["Keybind"] = "Home",
			["OnlyUnique"] = true,
			["Zombies"] = {}
		}
		local bodyESP = {
			["State"] = true,
			["RenderDistance"] = 50000,
			["Keybind"] = "Home",
			["Bodies"] = {}
		}
		
		local exitThread = false
		


		local function cachingThread()
			while true do
				if exitThread == true then
					Drawing.clear()
					print("Stopping caching thread")
					break
				end
				local startTime = tick()
				if vehicleESP.State == true then
					local children = getchildren(VehiclesFolder)
					if children == nil then
						return
					end
					for i,vehicle in pairs(children) do
						local name = getname(vehicle)
						local className = getclassname(vehicle)
						if className ~= "Model" then
							continue
						end
						if vehicleESP["Vehicles"][vehicle] ~= nil then
							continue
						end
						local primaryPart = getprimarypart(vehicle)
						if primaryPart == nil then
							continue
						end
						
						--print(getfullname(vehicle), primaryPart)
						vehicleESP["Vehicles"][vehicle] = {
							["Part"] = primaryPart,
							["Drawing"] = Drawing.new("Text")
						}
					end
				end
				if zombieESP.State == true then
					local children = getchildren(ZombiesFolder)
					for i, zombie in pairs(children) do
						local className = getclassname(zombie)
						if className ~= "Model" then
							continue
						end
						if zombieESP.Zombies[zombie] ~= nil then
							continue
						end
						local primaryPart = getprimarypart(zombie)
						if primaryPart == nil then
							continue
						end
						zombieESP.Zombies[zombie] = {
							["Part"] = primaryPart,
							["Drawing"] = Drawing.new("Text")
						}
					end
				end
				if bodyESP.State == true then
					local children = getchildren(CorpsesFolder)
					for i, corpse in pairs(children) do
						local className = getclassname(corpse)
						if className ~= "Model" then
							continue
						end
						if getname(corpse) == "Zombie" then
							continue
						end
						if bodyESP.Bodies[corpse] ~= nil then
							continue
						end
						local primaryPart = getprimarypart(corpse)
						if primaryPart == nil then
							continue
						end
						if not isInPlayerList(corpse) then
							continue
						end
						bodyESP.Bodies[corpse] = {
							["Part"] = primaryPart,
							["Drawing"] = Drawing.new("Text")
						}
						--print(string.format("%s was added to the list", getfullname(corpse)))
					end
				end
				--print(tick() - startTime)
				wait(3)
			end
		end
		
		local function keybindThread()
			local currentMode = 0
			
			vehicleESP.State = currentMode == 0
			zombieESP.State = currentMode == 1
			bodyESP.State = currentMode == 2
			while true do
				local currentPressedKey = getpressedkey()

				if currentPressedKey == "End" and lastPressedKey == "End" then
					exitThread = true
				end
				
				if exitThread == true then
					Drawing.clear()
					print("Stopping keybind thread")
					break
				end
			
				if currentPressedKey == "Home" and lastPressedKey ~= "Home" then
					if currentMode >= 2 then
						currentMode = 0
					else
						currentMode += 1
					end

					vehicleESP.State = currentMode == 0
					zombieESP.State = currentMode == 1
					bodyESP.State = currentMode == 2
					for i,v in pairs(vehicleESP.Vehicles) do
						if not v.Drawing then
							continue
						end
						v.Drawing.Visible = currentMode == 0
					end
					for i,v in pairs(zombieESP.Zombies) do
						if not v.Drawing then
							continue
						end
						v.Drawing.Visible = currentMode == 1
					end
					for i,v in pairs(bodyESP.Bodies) do
						if not v.Drawing then
							continue
						end
						v.Drawing.Visible = currentMode == 2
					end
				end
				lastPressedKey = currentPressedKey
				wait(.01)
			end
		end
		
		local function renderThread()
			local lastPressedKey = "None"
			local zombieESPLabel = Drawing.new("Text")
			local vehicleESPLabel = Drawing.new("Text")
			local bodyESPLabel = Drawing.new("Text")
			
			
			local function updateArraylist(screenSize)
				local yOffset = 0
				zombieESPLabel.Visible = true
				zombieESPLabel.Position = {0 + screenSize.x/20, yOffset + screenSize.y/6}
				zombieESPLabel.Text = string.format("ZombieESP [%s]", zombieESP.Keybind)
				zombieESPLabel.Size = 12
				zombieESPLabel.Center = true
				zombieESPLabel.Outline = true
				zombieESPLabel.Color = zombieESP.State == true and {0,255,0} or {255,0,0}
				yOffset += 20
				
				
				vehicleESPLabel.Visible = true
				vehicleESPLabel.Position = {0 + screenSize.x/20, yOffset + screenSize.y/6}
				vehicleESPLabel.Text = string.format("VehicleESP [%s]", vehicleESP.Keybind)
				vehicleESPLabel.Size = 12
				vehicleESPLabel.Center = true
				vehicleESPLabel.Outline = true
				vehicleESPLabel.Color = vehicleESP.State == true and {0,255,0} or {255,0,0}
				yOffset += 20
				
				
				bodyESPLabel.Visible = true
				bodyESPLabel.Position = {0 + screenSize.x/20, yOffset + screenSize.y/6}
				bodyESPLabel.Text = string.format("Body ESP [%s]", bodyESP.Keybind)
				bodyESPLabel.Size = 12
				bodyESPLabel.Center = true
				bodyESPLabel.Outline = true
				bodyESPLabel.Color = bodyESP.State == true and {0,255,0} or {255,0,0}
			end
			
			while true do
				local screenSize = getscreendimensions()
				local startTick = tick()
			
				if exitThread == true then
					Drawing.clear()
					print("Stopping rendering thread")
					break
				end
				local camPos = getCamPos()
				

				updateArraylist(screenSize)

				
				local function renderVehicles()
					if vehicleESP.State == true then
						for i,v in pairs(vehicleESP.Vehicles) do
							if v.Part == nil or v.Drawing == nil then
								v.Drawing.Visible = false
								vehicleESP.Vehicles[i] = nil
								continue
							end
							local primaryPart = getprimarypart(i)
							if primaryPart == nil then
								v.Drawing.Visible = false
								vehicleESP.Vehicles[i] = nil
								continue
							end
							if getclassname(primaryPart) ~= "Part" and getclassname(primaryPart) ~= "MeshPart" then
								v.Drawing.Visible = false
								vehicleESP.Vehicles[i] = nil
								continue
							end
							if getparent(v.Part) == nil then
								v.Drawing.Visible = false
								vehicleESP.Vehicles[i] = nil
								continue
							end
							local Pos3D = getposition(v.Part)
							if Pos3D == nil then
								v.Drawing.Visible = false
								vehicleESP.Vehicles[i] = nil
								continue
							end
							local Pos2D, OnScreen = worldtoscreenpoint({Pos3D.x, Pos3D.y, Pos3D.z})
							if Pos2D == nil then
								v.Drawing.Visible = false
								vehicleESP.Vehicles[i] = nil
								continue
							end
							local direction = {
								x = camPos.x - Pos3D.x, 
								y= camPos.y - Pos3D.y, 
								z= camPos.z - Pos3D.z
							}
							local dist = math.sqrt(direction.x^2 + direction.y^2 + direction.z^2) or 1e9
							if dist > vehicleESP.RenderDistance then
								v.Drawing.Visible = false
								continue
							end
							v.Drawing.Visible = OnScreen
							v.Drawing.Position = {Pos2D.x, Pos2D.y}
							v.Drawing.Text = string.format("[%s] [%.1f]", getname(i), dist)
							v.Drawing.Size = 12
							v.Drawing.Center = true
							v.Drawing.Outline = true
							v.Drawing.Color = {255,255,255}
						end
					end
				end

				local function renderZombies()
					if zombieESP.State == true then
						for i,v in pairs(zombieESP.Zombies) do
							if zombieESP.OnlyUnique == true and not string.find(getname(i), "Unique") then
								v.Drawing.Visible = false
								continue
							end
							if v.Part == nil or v.Drawing == nil then
								v.Drawing.Visible = false
								zombieESP.Zombies[i] = nil
								continue
							end
							local primaryPart = getprimarypart(i)
							if primaryPart == nil then
								v.Drawing.Visible = false
								zombieESP.Zombies[i] = nil
								continue
							end
							if getclassname(primaryPart) ~= "Part" and getclassname(primaryPart) ~= "MeshPart" then
								v.Drawing.Visible = false
								zombieESP.Zombies[i] = nil
								continue
							end
							if getparent(v.Part) == nil then
								v.Drawing.Visible = false
								zombieESP.Zombies[i] = nil
								continue
							end
							local Pos3D = getposition(v.Part)
							if Pos3D == nil then
								v.Drawing.Visible = false
								zombieESP.Zombies[i] = nil
								continue
							end
							local Pos2D, OnScreen = worldtoscreenpoint({Pos3D.x, Pos3D.y, Pos3D.z})
							if Pos2D == nil then
								v.Drawing.Visible = false
								zombieESP.Zombies[i] = nil
								continue
							end
							local direction = {
								x = camPos.x - Pos3D.x, 
								y= camPos.y - Pos3D.y, 
								z= camPos.z - Pos3D.z
							}
							local dist = math.sqrt(direction.x^2 + direction.y^2 + direction.z^2) or 1e9
							if dist > zombieESP.RenderDistance then
								v.Drawing.Visible = false
								continue
							end
							v.Drawing.Visible = OnScreen
							v.Drawing.Position = {Pos2D.x, Pos2D.y}
							v.Drawing.Text = string.format("[%s] [%.1f]", getname(i), dist)
							v.Drawing.Size = 12
							v.Drawing.Center = true
							v.Drawing.Outline = true
							v.Drawing.Color = {0,170,0}
						end
					end
				end
				
				local function renderBodies()
					if bodyESP.State == true then
						for i,v in pairs(bodyESP.Bodies) do
							if v.Part == nil or v.Drawing == nil then
								v.Drawing.Visible = false
								bodyESP.Bodies[i] = nil
								continue
							end
							local primaryPart = getprimarypart(i)
							if primaryPart == nil then
								v.Drawing.Visible = false
								bodyESP.Bodies[i] = nil
								continue
							end
							if getclassname(primaryPart) ~= "Part" and getclassname(primaryPart) ~= "MeshPart" then
								v.Drawing.Visible = false
								bodyESP.Bodies[i] = nil
								continue
							end
							if getparent(v.Part) == nil then
								v.Drawing.Visible = false
								bodyESP.Bodies[i] = nil
								continue
							end
							local Pos3D = getposition(v.Part)
							if Pos3D == nil then
								v.Drawing.Visible = false
								bodyESP.Bodies[i] = nil
								continue
							end
							local Pos2D, OnScreen = worldtoscreenpoint({Pos3D.x, Pos3D.y, Pos3D.z})
							if Pos2D == nil then
								v.Drawing.Visible = false
								bodyESP.Bodies[i] = nil
								continue
							end
							local direction = {
								x = camPos.x - Pos3D.x, 
								y= camPos.y - Pos3D.y, 
								z= camPos.z - Pos3D.z
							}
							local dist = math.sqrt(direction.x^2 + direction.y^2 + direction.z^2) or 1e9
							if dist > bodyESP.RenderDistance then
								v.Drawing.Visible = false
								continue
							end
							v.Drawing.Visible = OnScreen
							v.Drawing.Position = {Pos2D.x, Pos2D.y}
							v.Drawing.Text = string.format("[%s] [%.1f]", getname(i), dist)
							v.Drawing.Size = 12
							v.Drawing.Center = true
							v.Drawing.Outline = true
							v.Drawing.Color = {255,0.7,255}
						end
					end
				end
				spawn(renderVehicles)
				spawn(renderZombies)
				spawn(renderBodies)
				--print(string.format("%s seconds elapsed", tick() - startTick))
				wait()
			end
		end
		
		spawn(renderThread)
		spawn(cachingThread)
		spawn(keybindThread)
	end
elseif targetGame == "EntryPoint" then 
	do 
		local levelFolder = findfirstchild(Workspace, "Level"); if levelFolder == nil then return end;
		
		local GroundItemsFolder = findfirstchild(levelFolder, "GroundItems", true);
		local GroundWeaponsFolder = findfirstchild(levelFolder, "GroundWeps", true);
		local NpcsFolder = findfirstchild(levelFolder, "Actors", true);
		
		local npcs = getchildren(NpcsFolder);
		if npcs then
			local camPos = getposition(camera); 
			if camPos ~= nil then
				for i, npc in pairs(npcs) do
					local char = findfirstchild(npc, "Character", true); if char == nil then continue end;
					local hrp = findfirstchild(char, "HumanoidRootPart", true); if hrp == nil then continue end;

					setrightvector(hrp, {-1,0,1})
				end
			end
		end

		--local itemESP = setupESP(GroundItemsFolder, "Part")
		--itemESP.RenderDistance = 1000
		--itemESP.UseBlacklist = true
		--itemESP.ScaleWithDist = true
		--itemESP.CacheCooldown = 5
		--itemESP.CacheSpeed = 200
		--itemESP.UseParentForFilter = true
		--
		--local weaponESP = setupESP(GroundWeaponsFolder, "Part")
		--weaponESP.RenderDistance = 1000
		--weaponESP.UseBlacklist = true
		--weaponESP.ScaleWithDist = true
		--weaponESP.CacheCooldown = 5
		--weaponESP.CacheSpeed = 200
		--weaponESP.UseParentForFilter = true
	end
elseif targetGame == "TheSurvivalGame" then 
	do 
		local worldResourcesFolder = findfirstchild(Workspace, "worldResources", true); if worldResourcesFolder == nil then return end;
		local mineableFolder = findfirstchild(worldResourcesFolder, "mineable", true); if mineableFolder == nil then return end;
		
		local mineableESP = setupESP(mineableFolder, "Part")
		mineableESP.RenderDistance = 1000
		mineableESP.UseBlacklist = true
		mineableESP.ScaleWithDist = true
		mineableESP.DistanceScalingFactor = 500
		mineableESP.CacheCooldown = 4
		mineableESP.CacheSpeed = 200
		mineableESP.UseParentForFilter = true
		mineableESP.BlacklistedChildren = {}
		mineableESP.CustomColors = {
			["Stone"] = {0.7, 0.7, 0.7},
			["Boulder"] = {0.7, 0.7, 0.7},
			["Copper Ore"] = {0.803, 0.521, 0.247},
			["Iron Ore"] = {0.503, 0.321, 0.147},
			["Brimstone Ore"] = {1,1,0},
			["Coal Ore"] = {0,0,0},
			["Gold Vein"] = {1, 1, 0},
			["Ice"] = {0 ,0, 1},
			["Bluesteel"] = {0,0.6, 1},
		}
	end
elseif targetGame == "TheWildWest" then
	do -- Animals ESP
		--local entitiesFolder = findfirstchild(Workspace, "WORKSPACE_Entities", true); if entitiesFolder == nil then return end;
		--local animalsFolder = findfirstchild(entitiesFolder, "Animals", true); if animalsFolder == nil then return end;
		--local animalESP = setupESP(animalsFolder, "Part")
		--animalESP.RenderDistance = 1000
		--animalESP.UseBlacklist = true
		--animalESP.ScaleWithDist = true
		--animalESP.DistanceScalingFactor = 1200
		--animalESP.CacheCooldown = 5
		--animalESP.CacheSpeed = 200
		--animalESP.UseParentForFilter = true
		--animalESP.shouldExclude = function(self, instance, parent, name, parentName)
		--	return table.find(self.BlacklistedStrings, name)
		--end
		--animalESP.getHealth = function(self, instance, parent)
		--	local health = {
		--		Current = 0,
		--		Max = 0
		--	}
		--	parent = parent or getparent(instance)
		--	local healthValue = findfirstchild(parent, "Health", true)
		--	if healthValue ~= nil then
		--		health.Current = getvalue(healthValue)
		--	end
		--	return health
		--end
		--animalESP.getInstances = function(self, targetFolder)
		--	local objects = {}
		--	local children = getChildrenInDepth(targetFolder, 1)
		--	for i,v in pairs(children) do
		--		local className = getclassname(v); if className == nil then continue end;
		--		if className == "Model" then
		--			local part = findfirstchild(v, "HumanoidRootPart") or findfirstchildofclass(v, "MeshPart") or findfirstchildofclass(v, "Part")
		--			--print(className, getfullname(v), getfullname(part))
		--			objects[table.getn(objects)+1] = part
		--		end
		--	end
		--	return objects
		--end
	end
	do -- Drops ESP
		local ignoreFolder = findfirstchild(Workspace, "Ignore", true); if ignoreFolder == nil then return end;
		local dropsESP = setupESP(ignoreFolder, "Part")
		dropsESP.RenderDistance = 2500
		dropsESP.UseBlacklist = true
		dropsESP.ScaleWithDist = true
		dropsESP.DistanceScalingFactor = 1200
		dropsESP.CacheCooldown = 2
		dropsESP.CacheSpeed = 500
		dropsESP.UseParentForFilter = true
		dropsESP.getInstances = function(self, targetFolder)
			local objects = {}
			local children = getChildrenInDepth(targetFolder, 1)
			for i,v in pairs(children) do
				local className = getclassname(v); if className == nil then continue end;
				if className == "Model" then
					local part = findfirstchildofclass(v, "Part") or findfirstchildofclass(v, "MeshPart")
					--print(className, getfullname(v), getfullname(part))
					objects[table.getn(objects)+1] = part
				end
			end
			return objects
		end
	end
end


