-- Controls: d-pad flies/steers, A = confirm/land/emerge/oviposit, B = leave
-- courtship, crank = feed (adult) / tune wingbeat (courtship) / fine steer
-- (raft). The smoke autopilot drives a whole lifecycle and now handles Stage 4
-- threats: flee spray clouds, go still when a bat is hunting, pick the safest
-- host and bail the instant it telegraphs a swat.

Input = {}

function Input.gather()
    if Harness.enabled and Harness.autopilot then
        return Harness.autopilot()
    end
    local inp = { mvx = 0, mvy = 0, atap = false, btap = false, crank = 0 }
    if playdate.buttonIsPressed(playdate.kButtonLeft) then inp.mvx = -1 end
    if playdate.buttonIsPressed(playdate.kButtonRight) then inp.mvx = 1 end
    if playdate.buttonIsPressed(playdate.kButtonUp) then inp.mvy = -1 end
    if playdate.buttonIsPressed(playdate.kButtonDown) then inp.mvy = 1 end
    inp.atap = playdate.buttonJustPressed(playdate.kButtonA)
    inp.btap = playdate.buttonJustPressed(playdate.kButtonB)
    inp.crank = playdate.getCrankChange()
    return inp
end

function Input.confirm()
    if Harness.enabled then return G.t > 0.6 end
    return playdate.buttonJustPressed(playdate.kButtonA)
end

-- ---- autopilot ---------------------------------------------------------------

local function toward(inp, x, y, fx, fy)
    inp.mvx = Util.sign(fx - x)
    inp.mvy = Util.sign(fy - y)
end

-- safest feedable host: prefer low-alertness kinds, penalise the slapping kid,
-- skip anyone telegraphing a swat or cooling down
local function pickHost(a)
    local best, bscore
    for _, h in ipairs(G.hosts) do
        if h.cd <= 0 and not h.swat then
            local k = C.HOSTS[h.kind]
            local score = k.alertRate + Util.dist(a.x, a.y, h.x, h.y) * 0.1 + h.alert * 0.5
            if h.kind == "kid" then score = score + 40 end
            if not bscore or score < bscore then best, bscore = h, score end
        end
    end
    return best
end

-- nearest blood location (House/Farm) on the map
local function bloodPlace(a)
    local best, bd
    for _, name in ipairs(C.PLACE_ORDER) do
        local P = C.PLACES[name]
        if P.hosts then
            local d = Util.dist(a.x, a.y, P.mx, P.my)
            if not bd or d < bd then best, bd = name, d end
        end
    end
    return best
end

-- fly to a marker and press A to enter it
local function goPlace(inp, a, name)
    local P = C.PLACES[name]
    if Util.near(a.x, a.y, P.mx, P.my, C.ENTER_R - 4) then
        inp.atap = true
    else
        toward(inp, a.x, a.y, P.mx, P.my)
    end
end

local function adultAP(inp)
    local a = G.adult
    if a.mode == "court" then
        local c = G.court
        inp.crank = (c.target - c.pitch) * 180 -- proportional tune, no overshoot
        return inp
    end

    if G.place == "map" then
        -- go still to shake a close bat off the whine
        local bat, bd = Threats.nearestBat(a.x, a.y)
        if bat and bd < 52 then return inp end
        -- male bonus run: chase whatever female is up, else refuel / loiter
        if a.sex == "male" then
            if G.male then
                if Util.near(a.x, a.y, G.male.x, G.male.y, C.COURT_R - 2) then inp.atap = true
                else toward(inp, a.x, a.y, G.male.x, G.male.y) end
            elseif G.energy < 45 then goPlace(inp, a, "garden")
            else toward(inp, a.x, a.y, C.W / 2, 110) end
            return inp
        end
        -- court a present male before travelling
        if not G.mated and G.male then
            if Util.near(a.x, a.y, G.male.x, G.male.y, C.COURT_R - 2) then inp.atap = true
            else toward(inp, a.x, a.y, G.male.x, G.male.y) end
            return inp
        end
        if not G.mated then
            if a.belly < 50 then goPlace(inp, a, bloodPlace(a))     -- stock up on blood
            elseif G.energy < 45 then goPlace(inp, a, "garden")      -- refuel
            else toward(inp, a.x, a.y, C.W / 2, 110) end             -- loiter for a male
        else
            if a.belly < 60 then goPlace(inp, a, bloodPlace(a))      -- top up the clutch
            else goPlace(inp, a, "garden") end                       -- go lay / wait for rain
        end
        return inp
    end

    -- inside a location
    local P = C.PLACES[G.place]
    local s = Threats.inSpray(a.x, a.y)
    if s then toward(inp, s.x, s.y, a.x, a.y); return inp end -- dodge repellent

    if a.sex == "male" then -- males only pop in to refuel at the Garden nectar
        if P.nectar and G.energy < 80 then toward(inp, a.x, a.y, P.nectar.x, P.nectar.y)
        else inp.btap = true end
        return inp
    end

    if P.hosts then
        if a.belly >= 60 then inp.btap = true; return inp end -- full: leave
        local h = pickHost(a)
        if h then
            if Util.near(a.x, a.y, h.x, h.y, h.reach - 3) then
                if h.swat then toward(inp, h.x, h.y, a.x, a.y) -- swat incoming: bail
                else inp.crank = 120 end                       -- draw blood
            else
                toward(inp, a.x, a.y, h.x, h.y)
            end
            return inp
        end
        inp.btap = true; return inp -- nothing feedable, leave
    end

    if P.nectar then -- Garden
        if G.mated and a.belly > 0 then
            if Weather.wet() then
                if Util.near(a.x, a.y, P.pond.x, P.pond.y, C.PUDDLE_R - 3) then inp.atap = true
                else toward(inp, a.x, a.y, P.pond.x, P.pond.y) end
            else
                toward(inp, a.x, a.y, P.nectar.x, P.nectar.y) -- wait for rain, topping energy
            end
            return inp
        end
        if G.energy < 80 then toward(inp, a.x, a.y, P.nectar.x, P.nectar.y); return inp end
        inp.btap = true -- topped up, nothing to lay: back to the map
    end
    return inp
end

Harness.autopilot = function()
    local inp = { mvx = 0, mvy = 0, atap = false, btap = false, crank = 0 }
    local s = G.state
    if s == "raft" then
        local r = G.raft
        inp.mvx = Util.sign((r.dryL + r.dryR) / 2 - r.x)
    elseif s == "larva" then
        local l = G.larva
        -- surface fully before diving (hysteresis) so deep motes stay reachable
        l.needAir = l.breath < 2.0 or (l.needAir and l.breath < 4.5)
        -- nearest predator
        local px, py, pd
        for _, p in ipairs(G.preds or {}) do
            local d = Util.dist(l.x, l.y, p.x, p.y)
            if not pd or d < pd then px, py, pd = p.x, p.y, d end
        end
        if pd and pd < 48 and l.breath > 1.2 then
            toward(inp, px, py, l.x, l.y) -- a predator is closing: flee (unless suffocating)
        elseif l.needAir then
            inp.mvy = -1
        else
            local bx, by, bd
            for _, m in ipairs(G.motes) do
                local d = Util.dist(l.x, l.y, m.x, m.y)
                if not bd or d < bd then bx, by, bd = m.x, m.y, d end
            end
            if bx then toward(inp, l.x, l.y, bx, by) end
        end
    elseif s == "pupa" then
        local p = G.pupa
        if p.meta >= C.PUPA_T then
            if p.y > C.SURFACE_Y then inp.mvy = -1 else inp.atap = true end
        end
    elseif s == "adult" then
        return adultAP(inp)
    end
    return inp
end
