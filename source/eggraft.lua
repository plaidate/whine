-- Stage 1: egg raft. Steer the floating clutch to stay off the drying edges
-- until it hatches. Teaches "water = life, drying = death."

EggRaft = {}

function EggRaft.reset()
    G.raft = { x = C.W / 2, hatch = 0, dryL = 30, dryR = C.W - 30 }
end

function EggRaft.update(dt, inp)
    local r = G.raft
    r.x = Util.clamp(r.x + inp.mvx * C.RAFT_SPD * dt + (inp.crank / 60) * C.RAFT_CRANK, 0, C.W)
    r.dryL = r.dryL + C.RAFT_DRY * dt
    r.dryR = r.dryR - C.RAFT_DRY * dt
    if r.x <= r.dryL or r.x >= r.dryR then
        Game.die("THE PUDDLE DRIED OUT")
        return
    end
    r.hatch = r.hatch + dt
    if r.hatch >= C.RAFT_T then Game.startStage("larva") end
end
