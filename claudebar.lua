-- claudebar.lua — Claude Code usage in macOS menubar
-- Place in ~/.hammerspoon/ and add: require("claudebar") to init.lua

local M = {}

-- autosaveName gives the NSStatusItem a stable identifier so menubar
-- managers (Thaw, Bartender, etc.) remember its show/hide state across reloads.
-- Also reuse the Lua object via _G so we don't create a second item if globals persist.
if not _G.claudebar_bar then
    _G.claudebar_bar = hs.menubar.new(true, "claudebar")
    _G.claudebar_bar:setTitle("C…")
end
local bar = _G.claudebar_bar

if _G.claudebar_timer then
    _G.claudebar_timer:stop()
    _G.claudebar_timer = nil
end

local INTERVAL      = 60 -- poll interval in seconds
local MIN_CALL_GAP  = 30 -- never call API faster than this
local _lastCall     = 0
local _backoffUntil = 0

local function getToken()
    local out = hs.execute("security find-generic-password -s 'Claude Code-credentials' -w 2>/dev/null")
    out = out:gsub("%s+$", "")
    if out == "" then
        out = hs.execute("security find-generic-password -s 'Claude Code' -w 2>/dev/null")
        out = out:gsub("%s+$", "")
    end
    if out == "" then return nil end
    local ok, json = pcall(hs.json.decode, out)
    if not ok or not json then return nil end
    return json.claudeAiOauth and json.claudeAiOauth.accessToken
end

local function parseUTC(isoStr)
    if not isoStr then return nil end
    local s = isoStr:sub(1, 19)
    local ts = hs.execute(string.format(
        "date -j -u -f '%%Y-%%m-%%dT%%H:%%M:%%S' '%s' '+%%s' 2>/dev/null", s
    ))
    return tonumber(ts)
end

local function timeUntil(isoStr)
    local ts = parseUTC(isoStr)
    if not ts then return "?" end
    local diff = ts - os.time()
    if diff <= 0 then return "now" end
    local h = math.floor(diff / 3600)
    local m = math.floor((diff % 3600) / 60)
    if h > 0 then return string.format("%dh %dm", h, m) end
    return string.format("%dm", m)
end

local function isDark()
    return hs.execute("defaults read -g AppleInterfaceStyle 2>/dev/null"):gsub("%s+$", "") == "Dark"
end

local function makeTitle(pct, resetIn)
    local color = isDark() and { white = 1, alpha = 1 } or { white = 0, alpha = 1 }
    local attrs = {
        font           = { name = "Menlo", size = 9 },
        color          = color,
        baselineOffset = -4,
        paragraphStyle = { alignment = "center", lineSpacing = 0, maximumLineHeight = 11, minimumLineHeight = 11 },
    }
    return hs.styledtext.new(
        string.format("%d%%\n%s", math.floor(pct + 0.5), resetIn),
        attrs
    )
end

local function refresh()
    local now = os.time()
    if now < _backoffUntil then return end
    if now - _lastCall < MIN_CALL_GAP then return end
    _lastCall = now

    local token = getToken()
    if not token then
        bar:setTitle("C?")
        bar:setTooltip("Not logged in — run `claude` in terminal")
        return
    end

    local claudeVer = (hs.execute("claude --version 2>/dev/null") or ""):match("^(%S+)") or "2.1.0"

    local headers = {
        Accept             = "application/json",
        ["Content-Type"]   = "application/json",
        Authorization      = "Bearer " .. token,
        ["anthropic-beta"] = "oauth-2025-04-20",
        ["User-Agent"]     = "claude-code/" .. claudeVer,
    }

    hs.http.asyncGet("https://api.anthropic.com/api/oauth/usage", headers, function(code, body)
        if code ~= 200 then
            -- Show actual code so we know whether it's 401 (re-auth) or 429 (rate limit)
            bar:setTitle(string.format("C%d", code))
            if code == 401 then
                bar:setTooltip("Token expired — run `claude` in terminal to re-auth")
            elseif code == 429 then
                _backoffUntil = os.time() + 300 -- back off 5 min on rate limit
                bar:setTooltip("Rate limited — backing off 5 min")
            else
                bar:setTooltip(string.format("API error %d", code))
            end
            return
        end

        local ok, data = pcall(hs.json.decode, body)
        if not ok or not data then
            bar:setTitle("C?")
            bar:setTooltip("Failed to parse API response")
            return
        end

        local fh           = data.five_hour or {}
        local sd           = data.seven_day or {}

        local sessionPct   = fh.utilization or 0
        local weeklyPct    = sd.utilization or 0
        local sessionReset = timeUntil(fh.resets_at)
        local weeklyReset  = timeUntil(sd.resets_at)

        bar:setTitle(makeTitle(sessionPct, sessionReset))
        bar:setTooltip(string.format(
            "Session:  %d%%   resets in %s\nWeekly:   %d%%   resets in %s",
            math.floor(sessionPct + 0.5), sessionReset,
            math.floor(weeklyPct + 0.5), weeklyReset
        ))
    end)
end

_G.claudebar_timer = hs.timer.new(INTERVAL, refresh):start()
-- Fire once immediately but respect debounce on subsequent reloads
hs.timer.doAfter(0, refresh)
M.bar   = bar
M.timer = _G.claudebar_timer

return M
