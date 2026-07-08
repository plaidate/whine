-- Environmental threats in the adult stage:
--   spray  : repellent clouds expand from a host (someone reaching for the can)
--            and drain energy fast while you are inside - a moving no-go zone.
--   bats   : after dusk, bats swoop in and home on your WHINE. They only lock
--            on while you are moving (loud); go still and they lose you and
--            coast off. Hunting-the-whine tension: stop flying to hide.

Threats = {}

function Threats.reset()
    G.tod = 0
    G.sprays = {}
    G.bats = {}
    G.sprayT = C.SPRAY_EVERY
    G.batT = C.BAT_EVERY
end

local function addSpray()
    local x, y = C.W * math.random(), 60 + math.random() * 110
    if #G.hosts > 0 and math.random() < 0.7 then
        local h = G.hosts[math.random(#G.hosts)]
        x, y = h.x, h.y
    end
    G.sprays[#G.sprays + 1] = { x = x, y = y, r = 0, life = C.SPRAY_LIFE }
    Sfx.rain() -- hiss stand-in TODO distinct spray hiss
end

local function addBat()
    if #G.bats >= C.BAT_MAX then return end
    local side = math.random(4)
    local x, y
    if side == 1 then x, y = -10, math.random(0, C.H)
    elseif side == 2 then x, y = C.W + 10, math.random(0, C.H)
    elseif side == 3 then x, y = math.random(0, C.W), -10
    else x, y = math.random(0, C.W), C.H + 10 end
    G.bats[#G.bats + 1] = { x = x, y = y, vx = 0, vy = 0 }
    Harness.count("batSpawns")
end

function Threats.inSpray(x, y)
    for _, s in ipairs(G.sprays) do
        if Util.near(x, y, s.x, s.y, s.r) then return s end
    end
end

function Threats.nearestBat(x, y)
    local best, bd
    for _, b in ipairs(G.bats) do
        local d = Util.dist(x, y, b.x, b.y)
        if not bd or d < bd then best, bd = b, d end
    end
    return best, bd
end

function Threats.dusk() return (G.tod or 0) >= C.DUSK_T end

-- ctx.spray: this screen has repellent (House). ctx.bats: this is the open map,
-- where dusk bats spawn and can catch you. Time-of-day always advances so dusk
-- arrives no matter where you are. In a sheltered location bats still drift (and
-- lose you) but cannot strike, so ducking indoors is a safe escape.
function Threats.update(dt, a, loud, ctx)
    ctx = ctx or { bats = true, spray = true }
    G.tod = G.tod + dt

    -- spray clouds (House only)
    if ctx.spray then
        G.sprayT = G.sprayT - dt
        if G.sprayT <= 0 then G.sprayT = C.SPRAY_EVERY; addSpray() end
    end
    for i = #G.sprays, 1, -1 do
        local s = G.sprays[i]
        s.r = math.min(C.SPRAY_RMAX, s.r + C.SPRAY_GROW * dt)
        if s.r >= C.SPRAY_RMAX then s.life = s.life - dt end
        if s.life <= 0 then table.remove(G.sprays, i) end
    end
    if Threats.inSpray(a.x, a.y) then
        G.energy = G.energy - C.SPRAY_DRAIN * (Mut.has("sprayResist") and 0.55 or 1) * dt -- Spray Gland
        Harness.count("sprayTicks")
    end

    -- dusk bats (open map only can spawn/strike; elsewhere they just drift off)
    if ctx.bats and Threats.dusk() then
        G.batT = G.batT - dt
        if G.batT <= 0 then G.batT = C.BAT_EVERY; addBat() end
    end
    for i = #G.bats, 1, -1 do
        local b = G.bats[i]
        local d = Util.dist(b.x, b.y, a.x, a.y)
        local hear = C.BAT_HEAR * (Mut.has("quietWings") and 0.7 or 1) -- Quiet Wings
        if ctx.bats and loud and d < hear then -- locked onto the whine
            local nx, ny = a.x - b.x, a.y - b.y
            local m = math.max(0.001, math.sqrt(nx * nx + ny * ny))
            b.vx, b.vy = nx / m * C.BAT_SPD, ny / m * C.BAT_SPD
        else -- lost you: bleed off speed and drift
            b.vx, b.vy = b.vx * 0.85, b.vy * 0.85
            if math.random() < 0.05 then
                local ang = math.random() * 6.2832
                b.vx = b.vx + math.cos(ang) * C.BAT_WANDER
                b.vy = b.vy + math.sin(ang) * C.BAT_WANDER
            end
        end
        b.x = b.x + b.vx * dt
        b.y = b.y + b.vy * dt
        if ctx.bats and Util.near(b.x, b.y, a.x, a.y, C.BAT_R) then
            Game.die("EATEN BY A BAT")
            return
        end
        if b.x < -40 or b.x > C.W + 40 or b.y < -40 or b.y > C.H + 40 then
            table.remove(G.bats, i)
        end
    end
end
