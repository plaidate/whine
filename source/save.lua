-- Persistence in the "whine" datastore:
--   { best = <most fertile eggs ever banked in one lineage>,
--     evo  = <lifetime fertile eggs, drives mutation unlocks>,
--     muts = <list of unlocked mutation keys, see mut.lua> }

Save = {}

function Save.load()
    local d = playdate.datastore.read("whine") or {}
    G.best = d.best or 0
    G.evo = d.evo or 0
    G.muts = d.muts or {}
end

function Save.store()
    playdate.datastore.write({ best = G.best or 0, evo = G.evo or 0, muts = G.muts or {} }, "whine")
end
