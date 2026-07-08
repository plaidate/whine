-- Stage 3: pupa (tumbler). Can't eat - just tumble while metamorphosis
-- completes, then surface and press A to emerge as an adult.
-- TODO: a predator sweep during the vulnerable emergence.

Pupa = {}

function Pupa.reset()
    G.pupa = { x = C.W / 2, y = 120, meta = 0 }
end

function Pupa.update(dt, inp)
    local p = G.pupa
    p.x = Util.clamp(p.x + inp.mvx * C.PUPA_SPD * dt, 0, C.W)
    p.y = Util.clamp(p.y + inp.mvy * C.PUPA_SPD * dt, 8, C.H - 8)
    p.meta = math.min(C.PUPA_T, p.meta + dt)
    if p.meta >= C.PUPA_T and p.y <= C.SURFACE_Y and inp.atap then
        Sfx.emerge()
        Game.startStage("adult")
    end
end
