--========================================
-- ARK HUB ADVANCED ESP (One-Press Auto-Run)
-- Auto-runs when loadstring() is executed
--========================================

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- Config
local CONFIG = {
    BoxWidth = 60,
    BoxHeight = 100,
    SkeletonThickness = 1.5,
    LineThickness = 2,
    NameSize = 15,
    InfoSize = 12,
    HealthBarWidth = 6,
    Rainbow = true,
    RainbowSpeed = 1.2,
    AlwaysShow = true -- show regardless of distance / offscreen
}

-- helpers
local function RainbowColor(speed)
    local t = tick() * (speed or CONFIG.RainbowSpeed)
    return Color3.fromHSV(t % 1, 1, 1)
end

local function NewDrawing(kind)
    local ok, obj = pcall(function() return Drawing.new(kind) end)
    if not ok then return nil end
    return obj
end

-- reuse drawing objects per player
local PlayerDraws = {} -- [player] = {box,text,name,skelLines{},dirLine,healthBar,infoText...}

local function MakePlayerDraws(plr)
    if PlayerDraws[plr] then return PlayerDraws[plr] end
    local d = {}

    d.Name = NewDrawing("Text")
    d.Name.Center = true
    d.Name.Size = CONFIG.NameSize
    d.Name.Font = 2
    d.Name.Outline = true

    d.Box = NewDrawing("Square")
    d.Box.Filled = false
    d.Box.Thickness = 2

    d.Skeleton = {}
    -- We'll allocate 6 lines for a simple R15-ish skeleton: head, torso, left arm, right arm, left leg, right leg
    for i=1,6 do
        local ln = NewDrawing("Line")
        ln.Thickness = CONFIG.SkeletonThickness
        table.insert(d.Skeleton, ln)
    end

    d.DirLine = NewDrawing("Line")
    d.DirLine.Thickness = CONFIG.LineThickness

    d.HealthBarBG = NewDrawing("Square")
    d.HealthBarBG.Filled = true
    d.HealthBarBG.Thickness = 1
    d.HealthBarBG.Transparency = 1

    d.HealthBar = NewDrawing("Square")
    d.HealthBar.Filled = true
    d.HealthBar.Thickness = 1
    d.HealthBar.Transparency = 1

    d.InfoText = NewDrawing("Text")
    d.InfoText.Left = true
    d.InfoText.Size = CONFIG.InfoSize
    d.InfoText.Outline = true
    d.InfoText.Font = 2

    d.DistanceText = NewDrawing("Text")
    d.DistanceText.Center = true
    d.DistanceText.Size = CONFIG.InfoSize
    d.DistanceText.Outline = true
    d.DistanceText.Font = 2

    PlayerDraws[plr] = d
    return d
end

local function RemovePlayerDraws(plr)
    local d = PlayerDraws[plr]
    if not d then return end
    for k,v in pairs(d) do
        if type(v) == "table" then
            for _,obj in pairs(v) do
                if obj and obj.Remove then pcall(obj.Remove, obj) end
            end
        else
            if v and v.Remove then pcall(v.Remove, v) end
        end
    end
    PlayerDraws[plr] = nil
end

-- utility: project and optionally clamp on-screen
local function ProjectPoint(pos)
    local screenPos, onScreen = Camera:WorldToViewportPoint(pos)
    local viewSize = Camera.ViewportSize
    local sx, sy = screenPos.X, screenPos.Y

    -- clamp if offscreen but AlwaysShow true
    if CONFIG.AlwaysShow then
        if sx < 0 then sx = 2 elseif sx > viewSize.X then sx = viewSize.X - 2 end
        if sy < 0 then sy = 2 elseif sy > viewSize.Y then sy = viewSize.Y - 2 end
        return Vector2.new(sx, sy), onScreen
    end
    return Vector2.new(sx, sy), onScreen
end

-- platform name
local function GetPlatform()
    local pf = UserInputService:GetPlatform()
    if pf then
        return tostring(pf)
    end
    return "Unknown"
end

-- Main update loop
local function UpdateESP()
    if not Camera then return end
    local viewSize = Camera.ViewportSize
    local bottomCenter = Vector2.new(viewSize.X/2, viewSize.Y - 10)
    local localChar = LocalPlayer.Character
    local localRoot = localChar and localChar:FindFirstChild("HumanoidRootPart")

    for _,plr in pairs(Players:GetPlayers()) do
        if plr == LocalPlayer then
            RemovePlayerDraws(plr)
            continue
        end

        local char = plr.Character
        if not char then RemovePlayerDraws(plr); continue end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum then RemovePlayerDraws(plr); continue end

        local draws = MakePlayerDraws(plr)

        -- team color
        local teamColor = Color3.new(1,0,0) -- default red
        if LocalPlayer.Team and plr.Team and LocalPlayer.Team == plr.Team and LocalPlayer.Team ~= nil then
            teamColor = Color3.fromRGB(50,150,255) -- blue for same team
        elseif CONFIG.Rainbow then
            teamColor = RainbowColor(CONFIG.RainbowSpeed)
        end

        -- positions
        local rootPos = hrp.Position
        local head = char:FindFirstChild("Head")
        local headPos = head and head.Position or (rootPos + Vector3.new(0,2,0))
        local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or hrp

        -- project main points
        local screenRoot, onScreenRoot = ProjectPoint(rootPos)
        local screenHead, onScreenHead = ProjectPoint(headPos)
        local screenTorso, _ = ProjectPoint(torso and torso.Position or rootPos)
        local dist = math.floor((localRoot and (localRoot.Position - rootPos).Magnitude) or (workspace.CurrentCamera and (workspace.CurrentCamera.CFrame.Position - rootPos).Magnitude or 0))

        -- box size scaling by distance (optional: keeps box readable)
        local scale = 1
        if localRoot then
            localDistance = (localRoot.Position - rootPos).Magnitude
            scale = math.clamp(150 / (localDistance + 1), 0.6, 1.6)
        end
        local boxW = CONFIG.BoxWidth * scale
        local boxH = CONFIG.BoxHeight * scale

        -- set box
        draws.Box.Color = teamColor
        draws.Box.Position = Vector2.new(screenRoot.X - boxW/2, screenRoot.Y - boxH/2)
        draws.Box.Size = Vector2.new(boxW, boxH)
        draws.Box.Visible = true

        -- name (top)
        draws.Name.Text = plr.Name
        draws.Name.Color = teamColor
        draws.Name.Position = Vector2.new(screenRoot.X, screenRoot.Y - boxH/2 - 18)
        draws.Name.Visible = true

        -- health bar (left)
        local healthPct = math.clamp((hum.Health / (hum.MaxHealth > 0 and hum.MaxHealth or 100)), 0, 1)
        local hbX = draws.Box.Position.X - (CONFIG.HealthBarWidth + 6)
        local hbY = draws.Box.Position.Y
        draws.HealthBarBG.Position = Vector2.new(hbX, hbY)
        draws.HealthBarBG.Size = Vector2.new(CONFIG.HealthBarWidth, boxH)
        draws.HealthBarBG.Color = Color3.fromRGB(30,30,30)
        draws.HealthBarBG.Visible = true

        draws.HealthBar.Position = Vector2.new(hbX, hbY + (1 - healthPct) * boxH)
        draws.HealthBar.Size = Vector2.new(CONFIG.HealthBarWidth, boxH * healthPct)
        -- health color gradient red->green
        draws.HealthBar.Color = Color3.new(1 - healthPct, healthPct, 0)
        draws.HealthBar.Visible = true

        -- info text (right side) - distance, platform, xyz, health%
        local platformName = GetPlatform()
        local xyzStr = ("X: %d Y: %d Z: %d"):format(math.floor(rootPos.X), math.floor(rootPos.Y), math.floor(rootPos.Z))
        local infoLines = {
            ("Dist: %d studs"):format(dist),
            ("Platform: %s"):format(platformName),
            xyzStr,
            ("HP: %d%%"):format(math.floor(healthPct * 100))
        }
        draws.InfoText.Text = table.concat(infoLines, "\n")
        draws.InfoText.Color = teamColor
        draws.InfoText.Position = Vector2.new(draws.Box.Position.X + boxW + 8, draws.Box.Position.Y)
        draws.InfoText.Visible = true
        draws.InfoText.TextXAlignment = Enum.TextXAlignment.Left

        -- distance text bottom-center of box
        draws.DistanceText.Text = ("%d studs"):format(dist)
        draws.DistanceText.Color = teamColor
        draws.DistanceText.Position = Vector2.new(screenRoot.X, screenRoot.Y + boxH/2 + 6)
        draws.DistanceText.Visible = true

        -- skeleton: simple lines connecting torso->head, torso->left/right arm, torso->left/right leg
        -- attempt to find limb positions for R15 or fallback to approximations
        local function projPart(p)
            if not p then return screenRoot end
            local s,_ = ProjectPoint(p.Position)
            return s
        end

        local headS = projPart(char:FindFirstChild("Head"))
        local neck = char:FindFirstChild("Neck") or char:FindFirstChild("UpperTorso")
        local upperTorso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("HumanoidRootPart")
        local leftArm = char:FindFirstChild("LeftUpperArm") or char:FindFirstChild("Left Arm")
        local rightArm = char:FindFirstChild("RightUpperArm") or char:FindFirstChild("Right Arm")
        local leftLeg = char:FindFirstChild("LeftUpperLeg") or char:FindFirstChild("Left Leg")
        local rightLeg = char:FindFirstChild("RightUpperLeg") or char:FindFirstChild("Right Leg")

        local torsoS = projPart(upperTorso)
        local leftArmS = projPart(leftArm)
        local rightArmS = projPart(rightArm)
        local leftLegS = projPart(leftLeg)
        local rightLegS = projPart(rightLeg)

        local sk = draws.Skeleton
        -- head <- torso
        if sk[1] then
            sk[1].From = headS
            sk[1].To = torsoS
            sk[1].Color = teamColor
            sk[1].Visible = true
        end
        -- torso -> left arm
        if sk[2] then
            sk[2].From = torsoS
            sk[2].To = leftArmS
            sk[2].Color = teamColor
            sk[2].Visible = true
        end
        -- torso -> right arm
        if sk[3] then
            sk[3].From = torsoS
            sk[3].To = rightArmS
            sk[3].Color = teamColor
            sk[3].Visible = true
        end
        -- torso -> left leg
        if sk[4] then
            sk[4].From = torsoS
            sk[4].To = leftLegS
            sk[4].Color = teamColor
            sk[4].Visible = true
        end
        -- torso -> right leg
        if sk[5] then
            sk[5].From = torsoS
            sk[5].To = rightLegS
            sk[5].Color = teamColor
            sk[5].Visible = true
        end
        -- extra small line center (optional)
        if sk[6] then
            sk[6].From = Vector2.new(torsoS.X, torsoS.Y - 4)
            sk[6].To = Vector2.new(torsoS.X, torsoS.Y + 4)
            sk[6].Color = teamColor
            sk[6].Visible = true
        end

        -- center-bottom connector line
        draws.DirLine.From = bottomCenter
        draws.DirLine.To = Vector2.new(screenRoot.X, screenRoot.Y)
        draws.DirLine.Color = teamColor
        draws.DirLine.Visible = true
    end
end

-- cleanup on player leave/join
Players.PlayerRemoving:Connect(function(plr)
    RemovePlayerDraws(plr)
end)
Players.PlayerAdded:Connect(function(plr)
    -- nothing to create until character exists; drawings are created lazily
end)

-- main render stepped connection
local RenderConn
RenderConn = RunService.RenderStepped:Connect(function()
    pcall(UpdateESP)
end)

-- safety: remove drawings if script is re-run (avoid duplicates)
if _G.__ARK_ESP_RUNNING then
    -- do nothing; already running
else
    _G.__ARK_ESP_RUNNING = true
end

-- End of script (no return - auto run)
