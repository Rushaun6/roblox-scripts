-- Smallest Server Joiner
-- Client-side script (run via an executor). Works in most public Roblox games.
-- Finds public servers with the fewest players and teleports you into one.
-- If a teleport fails (e.g. "Server is full"), it automatically tries the next smallest.

local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")

local placeId = game.PlaceId
local currentJob = game.JobId
local player = Players.LocalPlayer

local MAX_PAGES = 5       -- how many pages of 100 servers to scan at most
local RETRIES = 3         -- retries per page if the list request fails
local WANTED = 20         -- stop scanning once this many candidates are found
local MAX_ATTEMPTS = 10   -- how many servers to try before giving up

-- Fetch a URL, falling back to the executor's request function if HttpGet fails
local function fetch(url)
    local ok, body = pcall(function()
        return game:HttpGet(url)
    end)
    if ok and body then
        return body
    end

    local req = request or http_request or (syn and syn.request)
    if req then
        local ok2, res = pcall(req, { Url = url, Method = "GET" })
        if ok2 and res and res.StatusCode == 200 then
            return res.Body
        end
    end
    return nil
end

-- Returns a list of open servers, fewest players first (excluding the current one)
local function findServers()
    local list = {}
    local cursor = ""

    for _ = 1, MAX_PAGES do
        local url = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100"):format(placeId)
        if cursor ~= "" then
            url = url .. "&cursor=" .. cursor
        end

        local data
        for attempt = 1, RETRIES do
            local body = fetch(url)
            if body then
                local ok, decoded = pcall(function()
                    return HttpService:JSONDecode(body)
                end)
                if ok and decoded and decoded.data then
                    data = decoded
                    break
                end
            end
            task.wait(2 * attempt) -- back off if rate-limited
        end

        if not data then
            break
        end

        for _, s in ipairs(data.data) do
            if s.id ~= currentJob and s.playing < s.maxPlayers then
                table.insert(list, s)
            end
        end

        if #list >= WANTED then
            break
        end

        cursor = data.nextPageCursor
        if not cursor then
            break
        end
        task.wait(0.5)
    end

    table.sort(list, function(a, b)
        return a.playing < b.playing
    end)
    return list
end

-- Remove any previous copy of the GUI if the script is run again
local function getGuiParent()
    local ok, ui = pcall(function()
        return gethui()
    end)
    if ok and ui then
        return ui
    end
    return game:GetService("CoreGui")
end

local parent = getGuiParent()
local old = parent:FindFirstChild("SmallestServerJoiner")
if old then
    old:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "SmallestServerJoiner"
gui.ResetOnSpawn = false
gui.Parent = parent

local button = Instance.new("TextButton")
button.Size = UDim2.new(0, 220, 0, 50)
button.Position = UDim2.new(0.5, -110, 0, 20)
button.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
button.TextColor3 = Color3.new(1, 1, 1)
button.Font = Enum.Font.GothamBold
button.TextSize = 16
button.Text = "Join Smallest Server"
button.Active = true
button.Draggable = true
button.Parent = gui
Instance.new("UICorner", button).CornerRadius = UDim.new(0, 10)

local busy = false
local active = false
local candidates = {}
local index = 0

local function resetButton(delay)
    task.delay(delay or 3, function()
        busy = false
        button.Text = "Join Smallest Server"
    end)
end

local function teleportToNext()
    index = index + 1
    local server = candidates[index]

    if not server or index > MAX_ATTEMPTS then
        active = false
        button.Text = "No server worked - retry"
        resetButton(3)
        return
    end

    button.Text = ("Joining (%d players) try %d..."):format(server.playing, index)
    local ok = pcall(function()
        TeleportService:TeleportToPlaceInstance(placeId, server.id, player)
    end)
    if not ok then
        task.wait(1)
        teleportToNext()
    end
end

-- If a teleport fails (full server, etc.), move on to the next smallest server
TeleportService.TeleportInitFailed:Connect(function(plr)
    if plr ~= player or not active then
        return
    end
    task.wait(1.5)
    teleportToNext()
end)

button.MouseButton1Click:Connect(function()
    if busy then
        return
    end
    busy = true
    button.Text = "Scanning..."

    candidates = findServers()
    index = 0

    if #candidates == 0 then
        button.Text = "No server found - retry"
        resetButton(3)
        return
    end

    active = true
    teleportToNext()
end)
