-- Stage 2: larva (wriggler). Dive to eat drifting motes, but surface to
-- refill the breath meter through your siphon. Eat enough to pupate - while
-- predatory larvae (Toxorhynchites-style cannibals) hunt you in the deep. The
-- top of the water is safe from them, but that's not where the food is.

Larva = {}

local function spawnMote()
    return {
        x = 20 + math.random(0, C.W - 40),
        y = C.SURFACE_Y + 20 + math.random(0, C.H - C.SURFACE_Y - 40),
        gone = false,
    }
end

-- a predator larva enters from a side wall, down in the water column
local function spawnPred()
    return {
        x = math.random() < 0.5 and 20 or C.W - 20,
        y = C.SURFACE_Y + 40 + math.random(0, C.H - C.SURFACE_Y - 70),
        hx = 0, hy = 0, turn = 0, face = 1,
    }
end

function Larva.reset()
    G.larva = { x = C.W / 2, y = 140, breath = C.BREATH_MAX, eaten = 0 }
    G.motes = {}
    for i = 1, 5 do G.motes[i] = spawnMote() end
    G.preds = {}
    for i = 1, C.PRED_COUNT do
        G.preds[i] = spawnPred()
        Harness.count("predSpawns")
    end
end

-- move the predators: lock on and chase within PRED_HUNT, else drift and turn
local function updatePreds(dt, l)
    for _, p in ipairs(G.preds) do
        local dx, dy = l.x - p.x, l.y - p.y
        local d = math.sqrt(dx * dx + dy * dy)
        if d < C.PRED_HUNT then
            local m = math.max(1, d)
            p.x = p.x + dx / m * C.PRED_SPD * dt
            p.y = p.y + dy / m * C.PRED_SPD * dt
            p.face = dx >= 0 and 1 or -1
        else
            p.turn = p.turn - dt
            if p.turn <= 0 then
                local a = math.random() * math.pi * 2
                p.hx, p.hy = math.cos(a), math.sin(a)
                p.turn = C.PRED_TURN
                p.face = p.hx >= 0 and 1 or -1
            end
            p.x = p.x + p.hx * C.PRED_WANDER * dt
            p.y = p.y + p.hy * C.PRED_WANDER * dt
        end
        p.x = Util.clamp(p.x, 6, C.W - 6)
        p.y = Util.clamp(p.y, C.SURFACE_Y + 12, C.H - 6) -- can't reach the safe surface band
        if Util.near(p.x, p.y, l.x, l.y, C.PRED_R) then
            Game.die("DEVOURED BY A PREDATOR")
            return true
        end
    end
    return false
end

function Larva.update(dt, inp)
    local l = G.larva
    l.x = Util.clamp(l.x + inp.mvx * C.LARVA_SPD * dt, 0, C.W)
    l.y = Util.clamp(l.y + inp.mvy * C.LARVA_SPD * dt, 8, C.H - 8)
    l.chomp = math.max(0, (l.chomp or 0) - dt) -- eat-flash timer

    if l.y <= C.SURFACE_Y then
        l.breath = math.min(C.BREATH_MAX, l.breath + C.BREATH_REFILL * dt)
    else
        l.breath = l.breath - C.BREATH_DRAIN * dt
        if l.breath <= 0 then
            Game.die("DROWNED - NO AIR")
            return
        end
    end

    if updatePreds(dt, l) then return end -- a predator caught you

    for _, m in ipairs(G.motes) do
        if not m.gone and Util.near(l.x, l.y, m.x, m.y, C.MOTE_R) then
            l.eaten = l.eaten + 1
            l.chomp = 0.2
            Sfx.gulp()
            local nm = spawnMote()
            m.x, m.y = nm.x, nm.y
        end
    end

    if l.eaten >= C.LARVA_TARGET then Game.startStage("pupa") end
end
