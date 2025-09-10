-- Onetap ReCoded — Fixed & Updated
-- WARNING: Heads up! This script has not been verified by ScriptBlox. Use at your own risk!

-- Improved / cleaned version of the user's script with bugfixes and comments.

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = workspace

-- External libs (unchanged)
local ESP = loadstring(game:HttpGet("https://raw.githubusercontent.com/KING-MONKEYreal/ESP/refs/heads/main/ESP.lua"))()
ESP.Enabled = false
ESP.ShowBox = false
ESP.ShowName = false
ESP.ShowHealth = false
ESP.ShowTracer = false
ESP.ShowDistance = false
ESP.ShowSkeletons = false

local ESP_SETTINGS = {
    BoxOutlineColor = Color3.new(1, 1, 1),
    BoxColor = Color3.new(1, 1, 1),
    NameColor = Color3.new(1, 1, 1),
    HealthOutlineColor = Color3.new(0, 0, 0),
    HealthHighColor = Color3.new(0, 1, 0),
    HealthLowColor = Color3.new(1, 0, 0),
    CharSize = Vector2.new(4, 6),
    Teamcheck = false,
    WallCheck = false,
    Enabled = false,
    ShowBox = false,
    BoxType = "2D",
    ShowName = false,
    ShowHealth = false,
    ShowDistance = false,
    ShowSkeletons = false,
    ShowTracer = false,
    TracerColor = Color3.new(1, 1, 1),
    TracerThickness = 2,
    SkeletonsColor = Color3.new(1, 1, 1),
    TracerPosition = "Bottom",
}

-- State
local aimbotEnabled = false
local aimAtPart = "HumanoidRootPart"
local wallCheckEnabled = false
local targetNPCs = false
local teamCheckEnabled = false
local headSizeEnabled = false
local espEnabled = false
local IJ = false -- Infinite Jump state

-- Utility: get local character safely
local function getLocalCharacter()
    local chr = LocalPlayer.Character
    if not chr or not chr.Parent then
        chr = LocalPlayer.CharacterAdded:Wait()
    end
    return chr
end

-- Returns the closest valid target (player model or NPC model)
local function getClosestTarget()
    local cam = Workspace.CurrentCamera
    local character = getLocalCharacter()
    local localRoot = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
    if not localRoot then return nil end

    local nearestTarget = nil
    local shortestDistance = math.huge

    local function isValidModel(model)
        if not model or not model:IsA("Model") then return false end
        if not model:FindFirstChildWhichIsA("Humanoid") then return false end
        if not model:FindFirstChild(aimAtPart) then return false end
        return true
    end

    local function checkTarget(model)
        if not isValidModel(model) then return end
        -- ignore local player's model
        if model == character then return end

        local targetRoot = model:FindFirstChild(aimAtPart)
        if not targetRoot then return end

        local distance = (targetRoot.Position - localRoot.Position).Magnitude
        if distance >= shortestDistance then return end

        if wallCheckEnabled then
            local rayDirection = (targetRoot.Position - cam.CFrame.Position).Unit * 1000
            local raycastParams = RaycastParams.new()
            raycastParams.FilterDescendantsInstances = {character}
            raycastParams.FilterType = Enum.RaycastFilterType.Blacklist

            local raycastResult = Workspace:Raycast(cam.CFrame.Position, rayDirection, raycastParams)
            if raycastResult and raycastResult.Instance and raycastResult.Instance:IsDescendantOf(model) then
                shortestDistance = distance
                nearestTarget = model
            end
        else
            shortestDistance = distance
            nearestTarget = model
        end
    end

    -- check players
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            if player.Character and (not teamCheckEnabled or player.Team ~= LocalPlayer.Team) then
                checkTarget(player.Character)
            end
        end
    end

    -- optional: check NPCs in workspace
    if targetNPCs then
        for _, descendant in pairs(Workspace:GetDescendants()) do
            if descendant:IsA("Model") then
                checkTarget(descendant)
            end
        end
    end

    return nearestTarget
end

-- Smoothly point camera at a position (instant)
local function lookAt(targetPosition)
    local cam = Workspace.CurrentCamera
    if targetPosition then
        cam.CFrame = CFrame.new(cam.CFrame.Position, targetPosition)
    end
end

-- Main aimbot loop: attaches to RenderStepped while enabled
local aimConnection = nil
local function startAimbotLoop()
    if aimConnection then return end
    aimConnection = RunService.RenderStepped:Connect(function()
        if not aimbotEnabled then return end
        local closest = getClosestTarget()
        if closest and closest:FindFirstChild(aimAtPart) and closest:FindFirstChildWhichIsA("Humanoid") and closest:FindFirstChildWhichIsA("Humanoid").Health > 0 then
            local targetPart = closest:FindFirstChild(aimAtPart)
            if targetPart then
                -- do a simple visibility check when wall check enabled
                if wallCheckEnabled then
                    local cam = Workspace.CurrentCamera
                    local rayDirection = (targetPart.Position - cam.CFrame.Position).Unit * 1000
                    local raycastParams = RaycastParams.new()
                    raycastParams.FilterDescendantsInstances = {getLocalCharacter()}
                    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
                    local raycastResult = Workspace:Raycast(cam.CFrame.Position, rayDirection, raycastParams)
                    if not (raycastResult and raycastResult.Instance and raycastResult.Instance:IsDescendantOf(closest)) then
                        return
                    end
                end

                lookAt(targetPart.Position)
            end
        end
    end)
end

local function stopAimbotLoop()
    if aimConnection then
        aimConnection:Disconnect()
        aimConnection = nil
    end
end

-- Resize heads (optional)
local function resizeHeads(size)
    size = size or Vector3.new(5,5,5)

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local head = player.Character:FindFirstChild("Head")
            if head and head:IsA("BasePart") then
                head.Size = size
                head.CanCollide = false
            end
        end
    end

    for _, descendant in pairs(Workspace:GetDescendants()) do
        if descendant:IsA("Model") then
            local head = descendant:FindFirstChild("Head")
            if head and head:IsA("BasePart") then
                head.Size = size
                head.CanCollide = false
            end
        end
    end
end

-- Simple billboard ESP (used if external ESP not available)
local function createESP()
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("Head") then
            local head = player.Character.Head
            -- avoid duplicating billboards
            if not head:FindFirstChild("_OnetapESP") then
                local billboard = Instance.new("BillboardGui")
                billboard.Name = "_OnetapESP"
                billboard.Adornee = head
                billboard.Size = UDim2.new(0, 100, 0, 40)
                billboard.StudsOffset = Vector3.new(0, 2, 0)
                billboard.AlwaysOnTop = true

                local textLabel = Instance.new("TextLabel")
                textLabel.Parent = billboard
                textLabel.Size = UDim2.new(1, 0, 1, 0)
                textLabel.Text = player.Name
                textLabel.BackgroundTransparency = 1
                textLabel.TextStrokeTransparency = 0
                textLabel.TextScaled = true
                textLabel.Name = "_OnetapESPLabel"

                if player.Team then
                    textLabel.TextColor3 = player.Team.TeamColor.Color
                else
                    textLabel.TextColor3 = Color3.new(1, 1, 1)
                end

                billboard.Parent = head
            end
        end
    end
end

local function removeESP()
    for _, player in pairs(Players:GetPlayers()) do
        if player.Character and player.Character:FindFirstChild("Head") then
            local head = player.Character.Head
            local child = head:FindFirstChild("_OnetapESP")
            if child and child:IsA("BillboardGui") then
                child:Destroy()
            end
        end
    end
end

-- Infinite jump management
local ijConnection = nil
local function setInfiniteJump(state)
    IJ = state
    if IJ then
        if ijConnection then ijConnection:Disconnect() end
        ijConnection = UserInputService.JumpRequest:Connect(function()
            local chr = LocalPlayer.Character
            if chr then
                local hum = chr:FindFirstChildOfClass('Humanoid')
                if hum and hum:GetState() ~= Enum.HumanoidStateType.Dead then
                    hum:ChangeState(Enum.HumanoidStateType.Jumping)
                end
            end
        end)
    else
        if ijConnection then
            ijConnection:Disconnect()
            ijConnection = nil
        end
    end
end

-- Speed hack utility
local walkSpeedConnection = nil
local function setWalkSpeed(speed)
    _G.WS = speed or 16
    local function applyToHumanoid(hum)
        if not hum then return end
        pcall(function() hum.WalkSpeed = _G.WS end)
    end

    local chr = LocalPlayer.Character
    if chr then
        local hum = chr:FindFirstChildWhichIsA("Humanoid")
        applyToHumanoid(hum)
    end

    -- reconnect on character respawn
    if walkSpeedConnection then walkSpeedConnection:Disconnect() end
    walkSpeedConnection = LocalPlayer.CharacterAdded:Connect(function(newChar)
        local hum = newChar:WaitForChild("Humanoid")
        applyToHumanoid(hum)
    end)
end

-- UI (Rayfield) setup (kept mostly as-is but hooked to our fixed functions)
local OrionLib = loadstring(game:HttpGet(('https://raw.githubusercontent.com/jensonhirst/Orion/main/source')))()
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "RIVALS REAL",
    Icon = 0,
    LoadingTitle = "Hello",
    LoadingSubtitle = "by Chance",
    Theme = "Ocean",
    DisableRayfieldPrompts = false,
    DisableBuildWarnings = false,
    ConfigurationSaving = { Enabled = true, FolderName = nil, FileName = "Onetap" },
    Discord = { Enabled = false, Invite = "noinvitelink", RememberJoins = true },
    KeySystem = false,
    KeySettings = { Title = "Untitled", Subtitle = "Key System", Note = "No method of obtaining the key is provided", FileName = "Key", SaveKey = true, GrabKeyFromSite = false, Key = {"Hello"} }
})

-- Aimbot Tab
local Tab = Window:CreateTab("Aimbot", 4483362458)
local Section = Tab:CreateSection("Settings")

Tab:CreateButton({
    Name = "Silent Aim by CHANCE",
    Callback = function()
        loadstring(game:HttpGet('https://raw.githubusercontent.com/KING-MONKEYreal/RIVALS-SILENT-AIM/refs/heads/main/SILENT%20AIM.lua'))();
    end,
})

Tab:CreateToggle({
    Name = "Aimbot",
    CurrentValue = false,
    Flag = "Toggle_Aimbot",
    Callback = function(Value)
        aimbotEnabled = Value
        if aimbotEnabled then
            startAimbotLoop()
        else
            stopAimbotLoop()
        end
    end,
})

Tab:CreateButton({
    Name = "Switch Aim Part",
    Callback = function()
        if aimAtPart == "HumanoidRootPart" then
            aimAtPart = "Head"
        else
            aimAtPart = "HumanoidRootPart"
        end
        OrionLib:MakeNotification({ Name = "Aim Part", Content = "Now aiming at: " .. aimAtPart, Image = "rbxassetid://4483345998", Time = 5 })
    end,
})

Tab:CreateToggle({
    Name = "Wall check",
    CurrentValue = false,
    Flag = "Toggle_WallCheck",
    Callback = function(Value)
        wallCheckEnabled = Value
    end,
})

Tab:CreateToggle({
    Name = "Team Check",
    CurrentValue = false,
    Flag = "Toggle_TeamCheck",
    Callback = function(Value)
        teamCheckEnabled = Value
    end,
})

-- ESP Tab
local ESPTab = Window:CreateTab("ESP | WALLHACK", "rewind")

ESPTab:CreateToggle({ Name = "Enable Esp", CurrentValue = false, Flag = "Toggle_ESP_Enable", Callback = function(Value)
    espEnabled = Value
    ESP.Enabled = Value
    -- also maintain simple billboard ESP as fallback
    if Value then createESP() else removeESP() end
end })

ESPTab:CreateToggle({ Name = "Esp Box", CurrentValue = false, Flag = "Toggle_ESP_Box", Callback = function(Value)
    ESP.ShowBox = Value
end })

ESPTab:CreateToggle({ Name = "Esp Name", CurrentValue = false, Flag = "Toggle_ESP_Name", Callback = function(Value)
    ESP.ShowName = Value
end })

ESPTab:CreateToggle({ Name = "Esp Tracer", CurrentValue = false, Flag = "Toggle_ESP_Tracer", Callback = function(Value)
    ESP.ShowTracer = Value
end })

ESPTab:CreateToggle({ Name = "Esp Distance", CurrentValue = false, Flag = "Toggle_ESP_Distance", Callback = function(Value)
    ESP.ShowDistance = Value
end })

ESPTab:CreateToggle({ Name = "Esp Skeleton", CurrentValue = false, Flag = "Toggle_ESP_Skeleton", Callback = function(Value)
    ESP.ShowSkeletons = Value
end })

ESPTab:CreateToggle({ Name = "Team Check", CurrentValue = false, Flag = "Toggle_ESP_TeamCheck", Callback = function(Value)
    ESP.TeamCheck = Value
end })

ESPTab:CreateDropdown({ Name = "ESP Box Type", Options = {"2D","Corner Box Esp"}, CurrentOption = {"2D"}, MultipleOptions = false, Flag = "Dropdown_ESP_BoxType", Callback = function(Value)
    ESP.BoxType = Value
end })

ESPTab:CreateDropdown({ Name = "Tracer Position", Options = {"Bottom","Top","Middle"}, CurrentOption = {"Top"}, MultipleOptions = false, Flag = "Dropdown_ESP_TracerPos", Callback = function(Value)
    ESP.TracerPosition = Value
end })

-- Misc Tab
local MiscTab = Window:CreateTab("Misc", 4483362458)

MiscTab:CreateToggle({ Name = "Infinite Jump", CurrentValue = false, Flag = "Toggle_IJ", Callback = function(Value)
    setInfiniteJump(Value)
end })

MiscTab:CreateSlider({ Name = "Speed Hack", Range = {0, 100}, Increment = 1, Suffix = "WalkSpeed", CurrentValue = 16, Flag = "Slider_WS", Callback = function(Value)
    setWalkSpeed(Value)
end })

-- Info Tab
local InfoTab = Window:CreateTab("Info | Authors", 4483362458)
InfoTab:CreateLabel("Authors: Chance.", 4483362458, Color3.fromRGB(255, 255, 255), false)
InfoTab:CreateLabel("Lib UI: Rayfield", 4483362458, Color3.fromRGB(255, 255, 255), false)

-- Cleanup on script unload (if executor supports)
local function cleanup()
    stopAimbotLoop()
    setInfiniteJump(false)
    if walkSpeedConnection then walkSpeedConnection:Disconnect() end
    removeESP()
    ESP.Enabled = false
end

-- Optional:unbind cleanup when script is disabled/killed
if syn and syn.protect_gui then
    -- executor specific handling could be added here
end

print("Onetap ReCoded — script loaded (fixed)")


