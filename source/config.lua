import "smokeflag" -- must precede the SMOKE_BUILD block below (config imports first)

-- Whine - tunables (C) and live state (G). Fixed 30fps step.
-- 400x240 1-bit. One mosquito lifecycle per "generation": egg raft -> larva
-- -> pupa -> adult female -> lay a fertilised clutch -> next generation.
--
-- G is populated by each stage's reset(); the fields the modules agree on:
--   G.state       current stage: title|raft|larva|pupa|adult|laid|gameover
--   G.t           seconds in the current state
--   G.generation  lineage depth (score is total fertile eggs laid)
--   G.score       total fertile eggs banked
--   G.mated       has this adult female converged on a male yet
--   G.fertility   multiplier from courtship lock quality (0 if never mated)
--   G.raft/larva/pupa/adult  per-stage tables (see each module's reset)
--   G.weather, G.puddles      the rain clock and standing water (Weather)
--   G.hosts                   the feed roster (Hosts)
--   G.sprays, G.bats, G.tod   threats + time-of-day (Threats)

C = {
    DT = 1 / 30,
    W = 400,
    H = 240,

    -- shared
    SURFACE_Y = 40,   -- water surface line (larva/pupa breathe here)

    -- Stage 1: egg raft
    RAFT_T = 6,       -- seconds to hatch
    RAFT_SPD = 70,    -- d-pad steer
    RAFT_CRANK = 40,  -- fine crank steer
    RAFT_DRY = 14,    -- px/s each drying edge creeps inward

    -- Stage 2: larva (wriggler)
    LARVA_SPD = 80,
    BREATH_MAX = 5,
    BREATH_DRAIN = 0.7,  -- per second while submerged
    BREATH_REFILL = 3,   -- per second at the surface
    MOTE_R = 12,         -- eat radius
    LARVA_TARGET = 6,    -- motes to eat to pupate
    -- predatory larvae (e.g. Toxorhynchites): they hunt you in the water
    PRED_COUNT = 2,
    PRED_SPD = 58,       -- chase speed; slower than you (LARVA_SPD 80) so you can flee
    PRED_HUNT = 80,      -- within this range they lock on and chase
    PRED_WANDER = 26,    -- idle drift speed when they haven't seen you
    PRED_TURN = 1.6,     -- seconds between idle heading changes
    PRED_R = 9,          -- jaws reach you = death (the top of the water is safe from them)

    -- Stage 3: pupa (tumbler)
    PUPA_T = 5,       -- metamorphosis seconds
    PUPA_SPD = 90,

    -- Stage 4: adult female
    FLY_SPD = 110,
    ENERGY_MAX = 100,
    ENERGY_DRAIN = 4,     -- per second in flight (nectar refills it)
    NECTAR_REFILL = 55,   -- per second over a flower
    NECTAR_R = 18,
    FEED_RATE = 0.6,      -- belly per unit crank change
    BELLY_MAX = 100,
    ALERT_DECAY = 12,     -- host alertness cooldown per second when not fed
    ALERT_MAX = 100,      -- a host at max alertness swats
    MALE_CHANCE = 0.15,   -- chance an emerging adult is male (a bonus run)
    MALE_EVERY = 7,       -- seconds between courtship-partner fly-bys
    MALE_BONUS = 18,      -- eggs a male sires per female (x lock fertility)
    MALE_TARGET = 4,      -- a male's bonus run ends after siring this many broods
    COURT_R = 22,         -- reach to enter courtship with a male

    -- the overworld: fly the map between locations, then enter one to feed.
    -- Blood hosts live inside House/Farm (each swats); Garden is the safe hub
    -- (nectar to refuel + the rain-pond to lay in). Males + dusk bats are on the
    -- open map only; a location is shelter.
    ENTER_R = 26,         -- how near a map marker you must be to enter it
    PLACE_ORDER = { "house", "farm", "garden" },
    PLACES = {
        house  = { name = "House", mx = 84, my = 118, hosts = { "sleeper", "kid", "dog" }, spray = true },
        farm   = { name = "Farm", mx = 200, my = 118, hosts = { "cow", "dog" } },
        garden = { name = "Garden", mx = 316, my = 118, nectar = { x = 110, y = 120 }, pond = { x = 290, y = 138 } },
    },

    -- host roster: each kind swats differently (see hosts.lua)
    HOSTS = {
        sleeper = { name = "sleeper", alertRate = 9,  tele = 1.0, reach = 26, feed = 1.0 },
        cow     = { name = "cow",     alertRate = 7,  tele = 0.7, reach = 34, feed = 1.2, sweep = 3.2 },
        kid     = { name = "kid",     alertRate = 30, tele = 0.5, reach = 22, feed = 1.0, slap = 0.9 },
        dog     = { name = "dog",     alertRate = 20, tele = 0.7, reach = 22, feed = 1.0, roams = true },
    },
    HOST_COOLDOWN = 1.6,  -- a missed swat spooks the host this long

    -- threats (see threats.lua)
    SPRAY_EVERY = 9,      -- seconds between repellent sprays
    SPRAY_GROW = 40,      -- cloud radius growth px/s
    SPRAY_RMAX = 55,
    SPRAY_LIFE = 4,       -- seconds at full size before it clears
    SPRAY_DRAIN = 40,     -- energy/s while inside a cloud
    DUSK_T = 22,          -- seconds into an adult's life when bats come out
    BAT_EVERY = 6,        -- seconds between bat spawns after dusk
    BAT_MAX = 3,
    BAT_SPD = 95,         -- homing speed when it has your whine
    BAT_WANDER = 35,      -- drift speed once it has lost you
    BAT_R = 12,           -- contact = death
    BAT_HEAR = 130,       -- how close a bat locks onto a moving mosquito

    -- an evasive male: drifts the overworld and flees when you close in, but
    -- slower than you so he's catchable
    MALE_SPD = 34,        -- overworld drift / flee speed (< FLY_SPD 110)
    MALE_EVADE_R = 44,    -- overworld: within this he darts away from you

    -- courtship (harmonic convergence) minigame
    PITCH_SENS = 0.9,     -- how fast crank moves your wingbeat pitch (0..1)
    MALE_DRIFT = 0.05,    -- how much the male's target pitch wanders
    LOCK_TOL = 0.06,      -- |pitch-target| under this = converging
    LOCK_T = 1.2,         -- seconds held in tolerance to converge
    EVADE_R = 0.14,       -- courtship: pitch gap under which he edges his wingbeat away
    EVADE_SPD = 0.34,     -- courtship: how fast he flees your pitch (fades as your lock builds)

    -- weather clock -> puddles
    SUN_T = 8,
    CLOUD_T = 3,
    RAIN_T = 4,
    PUDDLE_R = 22,
    PUDDLE_LIFE = 12,     -- seconds a puddle lasts before drying
}

-- smoke builds run faster and tighter so a full lifecycle verifies quickly
if SMOKE_BUILD then
    C.RAFT_T = 3
    C.PUPA_T = 2.5
    C.MALE_EVERY = 3
    C.PUDDLE_LIFE = 20
    C.DUSK_T = 4
    C.BAT_EVERY = 4
    C.BAT_MAX = 1
    C.PRED_COUNT = 1     -- one predator so the autopilot can still finish the stage
    C.PRED_SPD = 46
    C.PRED_HUNT = 62
    C.MALE_TARGET = 2    -- short male run so smoke verifies it end-to-end quickly
end

G = {}
