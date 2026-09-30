--[[
    PAINEL AIMBOT + ESP - DuzinKX
    Feito para Luau 5.1 (Roblox)
    Configurações ajustáveis via painel
]]

-- Serviços
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")

-- Variáveis do jogador local
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Configurações padrão (podem ser alteradas no painel)
local Settings = {
    Aimbot = {
        Enabled = false,
        FOV = 120,           -- Raio do FOV em pixels
        Smoothness = 0.5,    -- Suavização (0 = instantâneo, 1 = lento)
        ShowFOV = true,      -- Mostrar círculo do FOV
        TeamCheck = false,   -- Ignorar companheiros de equipe
        VisibleCheck = true  -- Só mira se o alvo estiver visível
    },
    ESP = {
        Enabled = false,
        Boxes = true,
        Names = true,
        Health = true,
        Skeleton = true,
        TeamColor = true
    }
}

-- Tabela para armazenar objetos ESP
local ESPObjects = {}

-- Função para criar elementos ESP
local function CreateESP(player)
    if player == LocalPlayer then return end
    
    local esp = {
        Box = Drawing.new("Square"),
        Name = Drawing.new("Text"),
        Health = Drawing.new("Text"),
        Skeleton = {}
    }
    
    -- Configuração dos desenhos
    esp.Box.Thickness = 1
    esp.Box.Color = Color3.new(1, 1, 1)
    esp.Box.Filled = false
    
    esp.Name.Size = 13
    esp.Name.Center = true
    esp.Name.Outline = true
    esp.Name.OutlineColor = Color3.new(0, 0, 0)
    
    esp.Health.Size = 12
    esp.Health.Center = true
    esp.Health.Outline = true
    esp.Health.OutlineColor = Color3.new(0, 0, 0)
    
    -- Criar linhas do esqueleto
    local bonePairs = {
        {"Head", "Torso"},
        {"Torso", "Left Arm"},
        {"Torso", "Right Arm"},
        {"Torso", "Left Leg"},
        {"Torso", "Right Leg"},
        {"Left Arm", "Left Hand"},
        {"Right Arm", "Right Hand"},
        {"Left Leg", "Left Foot"},
        {"Right Leg", "Right Foot"}
    }
    
    for _, pair in ipairs(bonePairs) do
        local line = Drawing.new("Line")
        line.Thickness = 1
        line.Color = Color3.new(1, 0, 0)
        line.Visible = false
        esp.Skeleton[#esp.Skeleton + 1] = {line = line, part1 = pair[1], part2 = pair[2]}
    end
    
    ESPObjects[player] = esp
    
    -- Remover quando o jogador sair
    player.AncestryChanged:Connect(function()
        if not player.Parent then
            if ESPObjects[player] then
                ESPObjects[player].Box:Remove()
                ESPObjects[player].Name:Remove()
                ESPObjects[player].Health:Remove()
                for _, bone in ipairs(ESPObjects[player].Skeleton) do
                    bone.line:Remove()
                end
                ESPObjects[player] = nil
            end
        end
    end)
end

-- Criar ESP para todos os jogadores existentes
for _, player in ipairs(Players:GetPlayers()) do
    CreateESP(player)
end

-- Detectar novos jogadores
Players.PlayerAdded:Connect(function(player)
    CreateESP(player)
end)

-- Função para verificar visibilidade
local function IsVisible(character)
    if not Settings.Aimbot.VisibleCheck then return true end
    
    local origin = Camera.CFrame.Position
    local target = character.Head.Position
    
    local ray = Ray.new(origin, (target - origin).Unit * (target - origin).Magnitude)
    local hit, _ = workspace:FindPartOnRayWithIgnoreList(ray, {LocalPlayer.Character, Camera})
    
    return hit == nil or hit:IsDescendantOf(character)
end

-- Função para obter o melhor alvo
local function GetBestTarget()
    local bestTarget = nil
    local bestScore = math.huge
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        
        local character = player.Character
        if not character or not character:FindFirstChild("Humanoid") then continue end
        if character.Humanoid.Health <= 0 then continue end
        
        -- Team check
        if Settings.Aimbot.TeamCheck and player.Team == LocalPlayer.Team then continue end
        
        local head = character:FindFirstChild("Head")
        if not head then continue end
        
        -- Verificar se está na tela
        local screenPos, onScreen = Camera:WorldToScreenPoint(head.Position)
        if not onScreen then continue end
        
        -- Calcular distância do centro da tela
        local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        local distance = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
        
        -- Verificar FOV
        if distance <= Settings.Aimbot.FOV then
            -- Verificar visibilidade
            if IsVisible(character) then
                -- Pontuação baseada em distância e saúde
                local score = distance + character.Humanoid.Health * 0.1
                if score < bestScore then
                    bestScore = score
                    bestTarget = character
                end
            end
        end
    end
    
    return bestTarget
end

-- Função para atualizar o ESP
local function UpdateESP()
    if not Settings.ESP.Enabled then
        for _, esp in pairs(ESPObjects) do
            esp.Box.Visible = false
            esp.Name.Visible = false
            esp.Health.Visible = false
            for _, bone in ipairs(esp.Skeleton) do
                bone.line.Visible = false
            end
        end
        return
    end
    
    for player, esp in pairs(ESPObjects) do
        local character = player.Character
        if not character or not character:FindFirstChild("Humanoid") then
            esp.Box.Visible = false
            esp.Name.Visible = false
            esp.Health.Visible = false
            for _, bone in ipairs(esp.Skeleton) do
                bone.line.Visible = false
            end
            continue
        end
        
        local humanoid = character.Humanoid
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        local head = character:FindFirstChild("Head")
        
        if not rootPart or not head then continue end
        
        -- Verificar se está na tela
        local screenPos, onScreen = Camera:WorldToScreenPoint(rootPart.Position)
        if not onScreen then
            esp.Box.Visible = false
            esp.Name.Visible = false
            esp.Health.Visible = false
            for _, bone in ipairs(esp.Skeleton) do
                bone.line.Visible = false
            end
            continue
        end
        
        -- Cor baseada no time ou vermelho
        local color = Settings.ESP.TeamColor and player.TeamColor.Color or Color3.new(1, 0, 0)
        
        -- Atualizar caixa
        if Settings.ESP.Boxes then
            local size = Vector2.new(100, 200) -- Tamanho aproximado
            esp.Box.Position = Vector2.new(screenPos.X - size.X / 2, screenPos.Y - size.Y / 2)
            esp.Box.Size = size
            esp.Box.Color = color
            esp.Box.Visible = true
        else
            esp.Box.Visible = false
        end
        
        -- Atualizar nome
        if Settings.ESP.Names then
            esp.Name.Position = Vector2.new(screenPos.X, screenPos.Y - 110)
            esp.Name.Text = player.Name
            esp.Name.Color = color
            esp.Name.Visible = true
        else
            esp.Name.Visible = false
        end
        
        -- Atualizar vida
        if Settings.ESP.Health then
            local healthPercent = math.clamp(humanoid.Health / humanoid.MaxHealth * 100, 0, 100)
            esp.Health.Position = Vector2.new(screenPos.X, screenPos.Y - 95)
            esp.Health.Text = string.format("%.0f%%", healthPercent)
            esp.Health.Color = healthPercent > 50 and Color3.new(0, 1, 0) or 
                             (healthPercent > 25 and Color3.new(1, 1, 0) or Color3.new(1, 0, 0))
            esp.Health.Visible = true
        else
            esp.Health.Visible = false
        end
        
        -- Atualizar esqueleto
        if Settings.ESP.Skeleton then
            for _, bone in ipairs(esp.Skeleton) do
                local part1 = character:FindFirstChild(bone.part1)
                local part2 = character:FindFirstChild(bone.part2)
                
                if part1 and part2 then
                    local pos1, onScreen1 = Camera:WorldToScreenPoint(part1.Position)
                    local pos2, onScreen2 = Camera:WorldToScreenPoint(part2.Position)
                    
                    if onScreen1 and onScreen2 then
                        bone.line.From = Vector2.new(pos1.X, pos1.Y)
                        bone.line.To = Vector2.new(pos2.X, pos2.Y)
                        bone.line.Color = color
                        bone.line.Visible = true
                    else
                        bone.line.Visible = false
                    end
                else
                    bone.line.Visible = false
                end
            end
        else
            for _, bone in ipairs(esp.Skeleton) do
                bone.line.Visible = false
            end
        end
    end
end

-- Criação do círculo FOV
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 1
FOVCircle.Color = Color3.new(0, 1, 0)
FOVCircle.Radius = Settings.Aimbot.FOV
FOVCircle.Transparency = 1
FOVCircle.Visible = Settings.Aimbot.ShowFOV

-- Criação do painel
local function CreatePanel()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "DuzinKX Panel"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    
    -- Fundo do painel
    local panel = Instance.new("Frame")
    panel.Name = "MainPanel"
    panel.Size = UDim2.new(0, 300, 0, 400)
    panel.Position = UDim2.new(0.5, -150, 0.5, -200)
    panel.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    panel.BackgroundTransparency = 0.2
    panel.BorderSizePixel = 0
    panel.Active = true
    panel.Draggable = true
    panel.Parent = screenGui
    
    -- Título
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, 0, 0, 40)
    title.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    title.Text = "DuzinKX - Painel"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 18
    title.Parent = panel
    
    -- Botão de fechar
    local closeButton = Instance.new("TextButton")
    closeButton.Name = "CloseButton"
    closeButton.Size = UDim2.new(0, 30, 0, 30)
    closeButton.Position = UDim2.new(1, -35, 0, 5)
    closeButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    closeButton.Text = "X"
    closeButton.TextColor3 = Color3.new(1, 1, 1)
    closeButton.Font = Enum.Font.GothamBold
    closeButton.TextSize = 16
    closeButton.Parent = panel
    
    closeButton.MouseButton1Click:Connect(function()
        panel.Visible = false
    end)
    
    -- Criar seções do painel
    local yOffset = 50
    local spacing = 35
    
    -- Função para criar toggle
    local function CreateToggle(name, default, yPos, callback)
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0, 150, 0, 25)
        label.Position = UDim2.new(0, 10, 0, yPos)
        label.BackgroundTransparency = 1
        label.Text = name
        label.TextColor3 = Color3.new(1, 1, 1)
        label.Font = Enum.Font.Gotham
        label.TextSize = 14
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = panel
        
        local toggle = Instance.new("TextButton")
        toggle.Size = UDim2.new(0, 40, 0, 25)
        toggle.Position = UDim2.new(1, -50, 0, yPos)
        toggle.BackgroundColor3 = default and Color3.fromRGB(0, 170, 0) or Color3.fromRGB(170, 0, 0)
        toggle.Text = default and "ON" or "OFF"
        toggle.TextColor3 = Color3.new(1, 1, 1)
        toggle.Font = Enum.Font.GothamBold
        toggle.TextSize = 12
        toggle.Parent = panel
        
        toggle.MouseButton1Click:Connect(function()
            local newValue = not callback()
            toggle.BackgroundColor3 = newValue and Color3.fromRGB(0, 170, 0) or Color3.fromRGB(170, 0, 0)
            toggle.Text = newValue and "ON" or "OFF"
        end)
        
        return toggle
    end
    
    -- Criar slider
    local function CreateSlider(name, min, max, default, yPos, callback)
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0, 150, 0, 25)
        label.Position = UDim2.new(0, 10, 0, yPos)
        label.BackgroundTransparency = 1
        label.Text = name .. ": " .. default
        label.TextColor3 = Color3.new(1, 1, 1)
        label.Font = Enum.Font.Gotham
        label.TextSize = 14
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = panel
        
        local slider = Instance.new("TextButton")
        slider.Size = UDim2.new(0, 80, 0, 25)
        slider.Position = UDim2.new(1, -90, 0, yPos)
        slider.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
        slider.Text = tostring(default)
        slider.TextColor3 = Color3.new(1, 1, 1)
        slider.Font = Enum.Font.Gotham
        slider.TextSize = 12
        slider.Parent = panel
        
        slider.MouseButton1Click:Connect(function()
            local current = callback()
            local step = (max - min) / 10
            local newValue = math.clamp(current + step, min, max)
            callback(newValue)
            label.Text = name .. ": " .. string.format("%.1f", newValue)
            slider.Text = string.format("%.1f", newValue)
        end)
        
        slider.MouseButton2Click:Connect(function()
            local current = callback()
            local step = (max - min) / 10
            local newValue = math.clamp(current - step, min, max)
            callback(newValue)
            label.Text = name .. ": " .. string.format("%.1f", newValue)
            slider.Text = string.format("%.1f", newValue)
        end)
    end
    
    -- Seção Aimbot
    local aimbotTitle = Instance.new("TextLabel")
    aimbotTitle.Size = UDim2.new(1, 0, 0, 20)
    aimbotTitle.Position = UDim2.new(0, 10, 0, yOffset)
    aimbotTitle.BackgroundTransparency = 1
    aimbotTitle.Text = "=== AIMBOT ==="
    aimbotTitle.TextColor3 = Color3.fromRGB(255, 170, 0)
    aimbotTitle.Font = Enum.Font.GothamBold
    aimbotTitle.TextSize = 14
    aimbotTitle.TextXAlignment = Enum.TextXAlignment.Left
    aimbotTitle.Parent = panel
    yOffset = yOffset + 30
    
    CreateToggle("Ativar Aimbot", Settings.Aimbot.Enabled, yOffset, function()
        Settings.Aimbot.Enabled = not Settings.Aimbot.Enabled
        return Settings.Aimbot.Enabled
    end)
    yOffset = yOffset + spacing
    
    CreateToggle("Mostrar FOV", Settings.Aimbot.ShowFOV, yOffset, function()
        Settings.Aimbot.ShowFOV = not Settings.Aimbot.ShowFOV
        FOVCircle.Visible = Settings.Aimbot.ShowFOV
        return Settings.Aimbot.ShowFOV
    end)
    yOffset = yOffset + spacing
    
    CreateToggle("Team Check", Settings.Aimbot.TeamCheck, yOffset, function()
        Settings.Aimbot.TeamCheck = not Settings.Aimbot.TeamCheck
        return Settings.Aimbot.TeamCheck
    end)
    yOffset = yOffset + spacing
    
    CreateToggle("Visibilidade", Settings.Aimbot.VisibleCheck, yOffset, function()
        Settings.Aimbot.VisibleCheck = not Settings.Aimbot.VisibleCheck
        return Settings.Aimbot.VisibleCheck
    end)
    yOffset = yOffset + spacing
    
    CreateSlider("FOV", 50, 300, Settings.Aimbot.FOV, yOffset, function(value)
        if value then
            Settings.Aimbot.FOV = value
            FOVCircle.Radius = value
        end
        return Settings.Aimbot.FOV
    end)
    yOffset = yOffset + spacing
    
    CreateSlider("Suavidade", 0, 1, Settings.Aimbot.Smoothness, yOffset, function(value)
        if value then
            Settings.Aimbot.Smoothness = value
        end
        return Settings.Aimbot.Smoothness
    end)
    yOffset = yOffset + spacing + 10
    
    -- Seção ESP
    local espTitle = Instance.new("TextLabel")
    espTitle.Size = UDim2.new(1, 0, 0, 20)
    espTitle.Position = UDim2.new(0, 10, 0, yOffset)
    espTitle.BackgroundTransparency = 1
    espTitle.Text = "=== ESP ==="
    espTitle.TextColor3 = Color3.fromRGB(0, 170, 255)
    espTitle.Font = Enum.Font.GothamBold
    espTitle.TextSize = 14
    espTitle.TextXAlignment = Enum.TextXAlignment.Left
    espTitle.Parent = panel
    yOffset = yOffset + 30
    
    CreateToggle("Ativar ESP", Settings.ESP.Enabled, yOffset, function()
        Settings.ESP.Enabled = not Settings.ESP.Enabled
        return Settings.ESP.Enabled
    end)
    yOffset = yOffset + spacing
    
    CreateToggle("Caixas", Settings.ESP.Boxes, yOffset, function()
        Settings.ESP.Boxes = not Settings.ESP.Boxes
        return Settings.ESP.Boxes
    end)
    yOffset = yOffset + spacing
    
    CreateToggle("Nomes", Settings.ESP.Names, yOffset, function()
        Settings.ESP.Names = not Settings.ESP.Names
        return Settings.ESP.Names
    end)
    yOffset = yOffset + spacing
    
    CreateToggle("Vida", Settings.ESP.Health, yOffset, function()
        Settings.ESP.Health = not Settings.ESP.Health
        return Settings.ESP.Health
    end)
    yOffset = yOffset + spacing
    
    CreateToggle("Esqueleto", Settings.ESP.Skeleton, yOffset, function()
        Settings.ESP.Skeleton = not Settings.ESP.Skeleton
        return Settings.ESP.Skeleton
    end)
    yOffset = yOffset + spacing
    
    CreateToggle("Cor do Time", Settings.ESP.TeamColor, yOffset, function()
        Settings.ESP.TeamColor = not Settings.ESP.TeamColor
        return Settings.ESP.TeamColor
    end)
    
    -- Ajustar tamanho do painel
    panel.Size = UDim2.new(0, 300, 0, yOffset + 50)
    
    -- Tecla para abrir/fechar painel (F)
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode.F then
            panel.Visible = not panel.Visible
        end
    end)
end

-- Loop principal
RunService.RenderStepped:Connect(function()
    -- Atualizar FOV
    FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    FOVCircle.Visible = Settings.Aimbot.ShowFOV and Settings.Aimbot.Enabled
    
    -- Aimbot
    if Settings.Aimbot.Enabled then
        local target = GetBestTarget()
        if target and target:FindFirstChild("Head") and target:FindFirstChild("HumanoidRootPart") then
            local headPos = target.Head.Position
            local screenPos = Camera:WorldToScreenPoint(headPos)
            
            -- Suavização
            local currentPos = Camera.CFrame.Position
            local targetCFrame = CFrame.lookAt(currentPos, headPos)
            local lerpAlpha = 1 - Settings.Aimbot.Smoothness
            Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, lerpAlpha)
        end
    end
    
    -- ESP
    UpdateESP()
end)

-- Criar painel
CreatePanel()

-- Mensagem inicial
print("DuzinKX Painel carregado! Pressione F para abrir/fechar o painel.")
