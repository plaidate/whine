-- Stage 4: adult female - the core loop, now spread across an overworld + the
-- locations you drop into.
--   MAP: fly between the House/Farm/Garden markers. Males drift past (reach one
--        and press A to court) and dusk bats hunt the open sky. Press A on a
--        marker to enter that place.
--   HOUSE/FARM: blood hosts to feed on, each swatting differently; the House
--        also has someone reaching for the repellent (spray clouds).
--   GARDEN: the safe hub - nectar to refuel your energy, and the rain-pond to
--        lay a fertile clutch in. B leaves a location back to the map.

Adult = {}

function Adult.reset()
    local sex = "female"
    if SMOKE_BUILD then
        if (G.generation or 1) % 2 == 0 then sex = "male" end -- alternate so smoke tests both runs
    elseif math.random() < C.MALE_CHANCE then
        sex = "male"
    end
    G.adult = { x = 200, y = 120, sex = sex, mode = "fly", belly = 0 }
    G.energy = Mut.energyMax() -- Big Reserve raises the ceiling
    G.mated = false
    G.fertility = 0
    G.maleBonus = 0  -- male bonus run: eggs sired so far
    G.maleBroods = 0
    G.maleRun = false
    G.place = "map"
    G.hosts = {}
    G.male = nil
    G.maleT = C.MALE_EVERY
    Sfx.courtStop()
    Weather.reset()
    Threats.reset()
end

-- drop from the map into a location screen
local function enter(name)
    G.place = name
    G.lastPlace = name
    G.sprays = {} -- fresh air
    local P = C.PLACES[name]
    if P.hosts then Hosts.enter(name) else G.hosts = {} end
    G.adult.x, G.adult.y = 36, 118 -- fly in from the doorway edge
end
Adult.enter = enter

-- pop back out onto the map, beside the marker you left
local function leave()
    local P = C.PLACES[G.place]
    G.place = "map"
    G.hosts = {}
    G.sprays = {}
    G.adult.x, G.adult.y = P.mx, P.my + 34
end
Adult.leave = leave

-- MAP: male fly-bys, entering a place, and the open-sky bats
local function updateMap(dt, a, inp, loud)
    if a.sex == "male" or not G.mated then -- seek a partner (male keeps going for the bonus)
        if not G.male then
            G.maleT = G.maleT - dt
            if G.maleT <= 0 then
                G.male = { x = math.random(60, C.W - 60), y = math.random(46, 140), wt = 0, dx = 0, dy = 0 }
            end
        else
            local m = G.male
            m.wt = m.wt - dt -- re-pick a wander heading every so often
            if m.wt <= 0 then
                m.wt = 0.6 + math.random()
                local ang = math.random() * 6.2832
                m.dx, m.dy = math.cos(ang), math.sin(ang)
            end
            local vx, vy = m.dx, m.dy
            local dd = Util.dist(a.x, a.y, m.x, m.y)
            if dd < C.MALE_EVADE_R then -- she's close: dart directly away
                local nx, ny = m.x - a.x, m.y - a.y
                local mm = math.max(1, math.sqrt(nx * nx + ny * ny))
                vx, vy = nx / mm, ny / mm
            end
            m.x = Util.clamp(m.x + vx * C.MALE_SPD * dt, 18, C.W - 18)
            m.y = Util.clamp(m.y + vy * C.MALE_SPD * dt, 40, 148)
            if Util.near(a.x, a.y, m.x, m.y, C.COURT_R) and inp.atap then
                Courtship.begin()
                return
            end
        end
    end

    Threats.update(dt, a, loud, { bats = true, spray = false })
    if G.state ~= "adult" then return end

    for _, name in ipairs(C.PLACE_ORDER) do
        local P = C.PLACES[name]
        if Util.near(a.x, a.y, P.mx, P.my, C.ENTER_R) and inp.atap then
            enter(name)
            return
        end
    end
end

-- INSIDE a location: feed (blood), refuel (nectar), or lay (pond); B leaves
local function updateLoc(dt, a, inp, loud)
    local P = C.PLACES[G.place]
    if inp.btap then leave(); return end

    Threats.update(dt, a, loud, { bats = false, spray = P.spray == true })
    if G.state ~= "adult" then return end

    if P.nectar and Util.near(a.x, a.y, P.nectar.x, P.nectar.y, C.NECTAR_R) then
        G.energy = math.min(Mut.energyMax(), G.energy + C.NECTAR_REFILL * dt)
    end

    if P.hosts then
        a.belly = math.min(C.BELLY_MAX, a.belly + Hosts.tryFeed(a, inp.crank, dt, C.BELLY_MAX - a.belly))
        Hosts.update(dt, a) -- telegraphs/sweeps/cooldowns; a strike ends the run
        if G.state ~= "adult" then return end
    end

    if a.sex == "female" and P.pond and a.belly > 0 and Weather.wet()
        and Util.near(a.x, a.y, P.pond.x, P.pond.y, C.PUDDLE_R) and inp.atap then
        Game.lay(a.belly)
    end
end

function Adult.update(dt, inp)
    Weather.update(dt)
    local a = G.adult

    if a.mode == "court" then
        Courtship.update(dt, inp)
        return
    end

    local loud = (inp.mvx ~= 0 or inp.mvy ~= 0)
    local spd = C.FLY_SPD * (Mut.has("fastWings") and 1.15 or 1) -- Fast Wings
    a.x = Util.clamp(a.x + inp.mvx * spd * dt, 6, C.W - 6)
    a.y = Util.clamp(a.y + inp.mvy * spd * dt, 28, 196)
    Sfx.wing(360)

    G.energy = G.energy - C.ENERGY_DRAIN * dt

    if G.place == "map" then
        updateMap(dt, a, inp, loud)
    else
        updateLoc(dt, a, inp, loud)
    end
    if G.state ~= "adult" then return end

    if G.energy <= 0 then
        if a.sex == "male" then Game.maleReturn() else Game.die("OUT OF ENERGY") end
        return
    end
end
