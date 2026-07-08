-- Whine - a mosquito's bloodline for Playdate.
-- Live the full mosquito lifecycle: egg raft -> larva -> pupa -> adult female.
-- Drink nectar to survive and blood to breed, tune your wingbeat to a mate,
-- and lay a fertilised clutch in a rain-puddle before it dries. Each fertile
-- clutch is the next generation; each generation is worth its egg count.

import "CoreLibs/graphics"

import "config"
import "util"
import "harness"
import "save"
import "mut"
import "sfx"
import "weather"
import "hosts"
import "threats"
import "eggraft"
import "larva"
import "pupa"
import "courtship"
import "adult"
import "draw"
import "input"

Game = {}

local STAGES = { raft = EggRaft, larva = Larva, pupa = Pupa, adult = Adult }

Save.load()
Mut.load()
math.randomseed(playdate.getSecondsSinceEpoch())
playdate.display.setRefreshRate(SMOKE_BUILD and 0 or 30)
Harness.shotPath = SHOT_PATH -- absolute host path, injected by `make smoke`

G.state = "title"
G.t = 0
G.generation = 1
G.score = 0

function Game.startStage(name)
    G.state = name
    G.t = 0
    local m = STAGES[name]
    if m and m.reset then m.reset() end
end

function Game.newLineage()
    G.generation = 1
    G.score = 0
    Game.startStage("raft")
end

local function recordBest()
    if (G.score or 0) > (G.best or 0) then
        G.best = G.score
        Save.store()
    end
end

function Game.die(reason)
    G.overReason = reason
    G.state = "gameover"
    G.t = 0
    Sfx.splat()
    Harness.count("deaths")
    recordBest()
end

function Game.over(reason)
    G.overReason = reason
    G.state = "gameover"
    G.t = 0
    Harness.count("endings")
    recordBest()
end

function Game.lay(amount)
    local fertile = G.mated and G.fertility > 0
    local eggs = math.floor(amount * (fertile and G.fertility or 0))
    G.lastEggs = eggs
    G.lastFertile = fertile
    if fertile then G.score = G.score + eggs; Mut.gain(eggs) end
    G.state = "laid"
    G.t = 0
    Sfx.lay()
    Harness.count("clutches")
end

-- a male's bonus run is over: bank the eggs he sired and (if any) carry the
-- line to the next generation via the shared laid -> raft flow
function Game.maleReturn()
    local eggs = G.maleBonus or 0
    G.lastEggs = eggs
    G.lastFertile = eggs > 0
    G.maleRun = true
    if eggs > 0 then G.score = G.score + eggs; Mut.gain(eggs) end
    G.state = "laid"
    G.t = 0
    Sfx.lay()
    Harness.count("maleRuns")
end

local function tick()
    local dt = C.DT
    G.t = G.t + dt
    Util.runPending(dt)
    Sfx.music(dt) -- per-stage ambient bed + motif
    local inp = Input.gather()
    local s = G.state

    if s == "title" then
        if Input.confirm() then
            Sfx.chime()
            Game.newLineage()
        end
    elseif s == "laid" then
        if G.t > 1.0 and Input.confirm() then
            G.newMut = nil
            if G.lastFertile then
                G.generation = G.generation + 1
                Game.startStage("raft")
            else
                Game.over("INFERTILE - THE LINEAGE ENDS")
            end
        end
    elseif s == "gameover" then
        if G.t > 1.0 and Input.confirm() then
            G.state = "title"
            G.t = 0
        end
    else
        local m = STAGES[s]
        if m then m.update(dt, inp) end
    end

    Draw.frame()
end

Harness.extra = function(t)
    t.state = G.state
    t.gen = G.generation
    t.score = G.score
    t.mated = G.mated and 1 or 0
    if G.place then t.place = G.place end
    t.evo = G.evo or 0
    t.muts = G.muts and #G.muts or 0
    if G.maleBonus then t.bonus = G.maleBonus end
    if G.preds then t.preds = #G.preds end
    if G.court then t.beat = math.floor(G.court.beat or 0) end
    if G.lockBeat then t.lockbeat = math.floor(G.lockBeat) end
    if G.adult then
        t.sex = G.adult.sex
        t.belly = math.floor(G.adult.belly)
        t.energy = math.floor(G.energy or 0)
        t.tod = math.floor(G.tod or 0)
        t.bats = G.bats and #G.bats or 0
        t.sprays = G.sprays and #G.sprays or 0
    end
    t.reason = G.overReason
end

local frame = 0
function playdate.update()
    frame = frame + 1
    Harness.frame(frame, tick)
end
