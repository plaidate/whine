-- The host roster - who you feed on, each swatting differently:
--   sleeper : slow to rouse; long safe feeds, but alertness eventually wakes it
--   cow     : calm, but a rhythmic tail sweep hits its whole feed zone on a beat
--   kid     : twitchy - slap-on-landing arms the instant you start feeding
--   dog     : roams its patch; moderate alertness, quick swat
-- A swat is telegraphed (host.swat = seconds until the strike); leave its reach
-- before the strike lands or the run ends. A missed swat spooks the host (cd).

Hosts = {}

local function spawn(kind, x, y)
    local k = C.HOSTS[kind]
    return {
        kind = kind, x = x, y = y,
        alert = 0, cd = 0, swat = nil, slapT = nil,
        sweepT = k.sweep, roamT = 2, vx = 0, vy = 0,
        reach = k.reach,
    }
end

-- spawn the roster for a location screen (House/Farm) at spaced slots
function Hosts.enter(place)
    local kinds = C.PLACES[place].hosts or {}
    local slots = { { 120, 96 }, { 250, 116 }, { 330, 150 } }
    G.hosts = {}
    for i, kind in ipairs(kinds) do
        local s = slots[i] or { 60 + i * 70, 120 }
        G.hosts[i] = spawn(kind, s[1], s[2])
    end
    Hosts.active = nil
end

function Hosts.reachable(x, y)
    for _, h in ipairs(G.hosts) do
        if h.cd <= 0 and Util.near(x, y, h.x, h.y, h.reach) then return h end
    end
end

local function trigger(h)
    if not h.swat and h.cd <= 0 then
        h.swat = C.HOSTS[h.kind].tele
        Sfx.tone(200) -- swat wind-up TODO distinct
    end
end
Hosts.trigger = trigger

-- crank over a feedable host draws blood; returns belly gained this frame
function Hosts.tryFeed(a, crank, dt, bellyRoom)
    Hosts.active = nil
    if bellyRoom <= 0 or math.abs(crank) <= 2 then return 0 end
    local h = Hosts.reachable(a.x, a.y)
    if not h then return 0 end
    local k = C.HOSTS[h.kind]
    Hosts.active = h
    h.alert = h.alert + k.alertRate * dt
    if k.slap and not h.slapT then h.slapT = k.slap end -- slap-on-landing armed
    Sfx.pump()
    return math.abs(crank) * C.FEED_RATE * dt * k.feed
end

function Hosts.update(dt, a)
    for _, h in ipairs(G.hosts) do
        local k = C.HOSTS[h.kind]
        h.cd = math.max(0, h.cd - dt)
        if Hosts.active ~= h then h.alert = math.max(0, h.alert - C.ALERT_DECAY * dt) end

        if k.roams then
            h.roamT = h.roamT - dt
            if h.roamT <= 0 then
                h.roamT = 1.5 + math.random() * 2
                h.vx = (math.random() - 0.5) * 30
                h.vy = (math.random() - 0.5) * 20
            end
            h.x = Util.clamp(h.x + h.vx * dt, 30, C.W - 30)
            h.y = Util.clamp(h.y + h.vy * dt, 55, 165)
        end

        if h.slapT then
            h.slapT = h.slapT - dt
            if h.slapT <= 0 then h.slapT = nil; trigger(h) end
        end
        if k.sweep then
            h.sweepT = h.sweepT - dt
            if h.sweepT <= 0 then
                h.sweepT = k.sweep
                if Util.near(a.x, a.y, h.x, h.y, h.reach * 2) then trigger(h) end
            end
        end
        if h.alert >= C.ALERT_MAX then trigger(h) end

        if h.swat then
            h.swat = h.swat - dt
            if h.swat <= 0 then
                h.swat = nil
                if Util.near(a.x, a.y, h.x, h.y, h.reach + 4) then
                    Game.die("SWATTED - " .. k.name)
                    return
                end
                h.alert = 0
                h.cd = C.HOST_COOLDOWN
                Sfx.pop()
                Harness.count("swatsDodged")
            end
        end
    end
end
