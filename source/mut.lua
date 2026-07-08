-- Persistent lineage mutations - the evolution meta-layer. Every fertile egg
-- your bloodline ever banks adds to a lifetime "evo" score saved in the
-- datastore (via Save). Cross a mutation's cost and it unlocks PERMANENTLY,
-- across generations AND play sessions, subtly buffing the whole species.
-- Systems query Mut.has(key); the title screen shows what you've evolved.

Mut = {}

-- unlocked in this order as lifetime evo accrues
Mut.LIST = {
    { key = "quietWings",  name = "Quiet Wings",  cost = 40,  desc = "bats hear you less" },
    { key = "sprayResist", name = "Spray Gland",  cost = 120, desc = "shrug off repellent" },
    { key = "fastWings",   name = "Fast Wings",   cost = 240, desc = "fly faster" },
    { key = "bigReserve",  name = "Big Reserve",  cost = 400, desc = "more energy to burn" },
}

Mut.set = {} -- key -> true (loaded from datastore)

function Mut.load()
    G.evo = G.evo or 0
    Mut.set = {}
    for _, k in ipairs(G.muts or {}) do Mut.set[k] = true end
end

function Mut.has(key) return Mut.set[key] == true end

-- effective energy ceiling (Big Reserve raises it)
function Mut.energyMax() return C.ENERGY_MAX + (Mut.has("bigReserve") and 30 or 0) end

-- the next locked mutation (for the title screen's "next" hint), or nil
function Mut.next()
    for _, m in ipairs(Mut.LIST) do
        if not Mut.set[m.key] then return m end
    end
end

-- bank eggs into lifetime evo, unlock any now-affordable mutations in order,
-- persist, and flag the first new one for a title/laid banner
function Mut.gain(eggs)
    G.evo = (G.evo or 0) + (eggs or 0)
    local newly
    for _, m in ipairs(Mut.LIST) do
        if not Mut.set[m.key] and G.evo >= m.cost then
            Mut.set[m.key] = true
            newly = newly or m
        end
    end
    if newly then
        G.muts = {}
        for _, m in ipairs(Mut.LIST) do
            if Mut.set[m.key] then G.muts[#G.muts + 1] = m.key end
        end
        Save.store()
        G.newMut = newly.name
    end
    return newly
end
