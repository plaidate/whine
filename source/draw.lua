-- Rendering. Fully procedural 1-bit art (no bitmap assets): every creature,
-- host and backdrop is drawn from primitives so it scales and animates for
-- free. One dispatch per state. Black-on-white silhouettes with white interior
-- highlights; dither fills carry the grays (water, ground, clouds).

local gfx <const> = playdate.graphics
local DTH <const> = gfx.image.kDitherTypeBayer4x4

Draw = {}

local function T() return playdate.getCurrentTimeMilliseconds() / 1000 end
local function blk() gfx.setColor(gfx.kColorBlack) end
local function wht() gfx.setColor(gfx.kColorWhite) end
-- d is DARKNESS (0 white .. 1 black). setDitherPattern's arg is transparency
-- (low value = darker), so invert d to get the intuitive scale.
local function gray(d) gfx.setDitherPattern(1 - d, DTH) end

-- ---- shared UI ---------------------------------------------------------------

local function centered(s, y) gfx.drawTextAligned(s, C.W / 2, y, kTextAlignment.center) end

local function panel(x, y, w, h)
    wht(); gfx.fillRoundRect(x, y, w, h, 6)
    blk(); gfx.drawRoundRect(x, y, w, h, 6)
end

-- a title-style ribbon: black rounded bar with knocked-out white text
local function ribbon(text, cy)
    local tw, th = gfx.getTextSize(text)
    local pad = 12
    blk(); gfx.fillRoundRect(C.W / 2 - tw / 2 - pad, cy - th / 2 - 5, tw + pad * 2, th + 10, 5)
    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    gfx.drawTextAligned(text, C.W / 2, cy - th / 2, kTextAlignment.center)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

local function meter(x, y, w, frac, label)
    if label then gfx.drawText(label, x, y - 14) end
    blk(); gfx.drawRoundRect(x, y, w, 9, 2)
    local fw = math.max(0, (w - 4) * Util.clamp(frac, 0, 1))
    if fw > 0 then gfx.fillRoundRect(x + 2, y + 2, fw, 5, 1) end
end

local function hud()
    gfx.drawText("GEN " .. (G.generation or 1) .. "   eggs " .. (G.score or 0), 6, 4)
end

-- a soft ground shadow to sit a creature on the world
local function shadow(x, y, w)
    gray(0.4); gfx.fillEllipseInRect(x - w / 2, y - 3, w, 6); blk()
end

-- a teardrop of blood: circle bell + a peaked top, with a glint
local function drop(x, y, r)
    blk()
    gfx.fillCircleAtPoint(x, y, r)
    gfx.fillTriangle(x - r, y - r * 0.3, x + r, y - r * 0.3, x, y - r * 2.4)
    wht(); gfx.fillCircleAtPoint(x - r * 0.35, y - r * 0.2, r * 0.35); blk()
end

-- ---- the mosquito (hero sprite, scalable, side-view) -------------------------
-- body-space: +x forward (toward the head), +y down. f mirrors x for facing.
local function skeeter(cx, cy, s, f, flap)
    flap = flap or 0.5
    local function P(dx, dy) return cx + dx * s * f, cy + dy * s end
    local function rectFrom(ax, ay, bx, by)
        local x1, y1 = P(ax, ay); local x2, y2 = P(bx, by)
        return math.min(x1, x2), math.min(y1, y2), math.abs(x2 - x1), math.abs(y2 - y1)
    end

    -- legs: six long, thin, two-jointed lines (the signature)
    blk(); gfx.setLineWidth(math.max(1, s * 0.7))
    local legs = {
        { 3, 1, 9, 7, 13, 13 }, { 1, 1, 0, 8, -3, 15 }, { -2, 0, -8, 6, -13, 12 },
        { 4, 1, 9, 10, 12, 16 }, { 0, 1, -3, 10, -5, 17 }, { -3, 0, -10, 8, -15, 14 },
    }
    for _, l in ipairs(legs) do
        local x1, y1 = P(l[1], l[2]); local x2, y2 = P(l[3], l[4]); local x3, y3 = P(l[5], l[6])
        gfx.drawLine(x1, y1, x2, y2); gfx.drawLine(x2, y2, x3, y3)
    end
    gfx.setLineWidth(1)

    -- wings behind the body: outlined lenses, height opens/closes with flap
    local lift = 4 + flap * 7
    for i = 0, 1 do
        local x, y, w, h = rectFrom(-12 - i * 2, -3 - lift, 3 - i, -2)
        wht(); gfx.fillEllipseInRect(x, y, w, h)
        blk(); gfx.drawEllipseInRect(x, y, w, h)
    end

    -- abdomen: shrinking segments tapering up and back
    blk()
    for _, c in ipairs({ { -1, -2, 3 }, { -4, -3, 2.4 }, { -6.5, -4, 1.8 }, { -8.5, -4.6, 1.2 } }) do
        local x, y = P(c[1], c[2]); gfx.fillCircleAtPoint(x, y, c[3] * s)
    end
    -- thorax + head
    local tx, ty = P(2, -1); gfx.fillCircleAtPoint(tx, ty, 3.2 * s)
    local hx, hy = P(6, -1); gfx.fillCircleAtPoint(hx, hy, 2.3 * s)
    wht(); local ex, ey = P(6.7, -1.5); gfx.fillCircleAtPoint(ex, ey, math.max(1, 0.8 * s)); blk()
    -- proboscis + antennae
    gfx.setLineWidth(math.max(1, s * 0.9))
    local p1x, p1y = P(7, 0.5); local p2x, p2y = P(14, 5.5); gfx.drawLine(p1x, p1y, p2x, p2y)
    gfx.setLineWidth(math.max(1, s * 0.5))
    local a1x, a1y = P(7, -2.5)
    gfx.drawLine(a1x, a1y, P(13, -6)); gfx.drawLine(a1x, a1y, P(12, -4.5))
    gfx.setLineWidth(1)
end

-- ---- adult-stage set dressing -------------------------------------------------

local function flower(x, y)
    blk(); gfx.setLineWidth(1)
    gfx.drawLine(x, y + 3, x, y + 16)          -- stem
    gfx.drawLine(x, y + 10, x - 5, y + 8)      -- leaf
    for i = 0, 4 do
        local a = i * (math.pi * 2 / 5) + T() * 0.5
        gfx.fillCircleAtPoint(x + math.cos(a) * 5, y + math.sin(a) * 5, 3)
    end
    wht(); gfx.fillCircleAtPoint(x, y, 2.4); blk(); gfx.drawCircleAtPoint(x, y, 2.4)
end

local function puddle(p)
    local r = C.PUDDLE_R
    gray(0.4); gfx.fillEllipseInRect(p.x - r, p.y - r * 0.42, r * 2, r * 0.84); blk()
    gfx.drawEllipseInRect(p.x - r, p.y - r * 0.42, r * 2, r * 0.84)
    wht(); gfx.drawLine(p.x - 7, p.y - 2, p.x + 3, p.y - 2); blk() -- surface glint
end

local function sprayCloud(s)
    local r = s.r
    local puffs = { { -r * 0.5, 1, r * 0.6 }, { r * 0.45, -1, r * 0.55 }, { 0, -r * 0.42, r * 0.6 }, { 0, r * 0.1, r * 0.72 } }
    gray(0.3)
    for _, o in ipairs(puffs) do gfx.fillCircleAtPoint(s.x + o[1], s.y + o[2], o[3]) end
    blk()
    for _, o in ipairs(puffs) do gfx.drawCircleAtPoint(s.x + o[1], s.y + o[2], o[3]) end
    for i = 0, 3 do -- drifting droplets
        local a = i * 1.7 + T()
        gfx.fillCircleAtPoint(s.x + math.cos(a) * r * 0.5, s.y + math.sin(a) * r * 0.5, 1)
    end
end

local function batShape(x, y)
    local fl = math.sin(T() * 14) * 4
    blk()
    gfx.fillCircleAtPoint(x, y, 4)                        -- body
    gfx.fillTriangle(x, y - 1, x - 14, y - 6 - fl, x - 6, y + 4) -- left wing
    gfx.fillTriangle(x, y - 1, x + 14, y - 6 - fl, x + 6, y + 4) -- right wing
    gfx.fillTriangle(x - 2, y - 4, x - 4, y - 8, x - 1, y - 5)   -- ears
    gfx.fillTriangle(x + 2, y - 4, x + 4, y - 8, x + 1, y - 5)
    wht(); gfx.fillCircleAtPoint(x - 2, y - 1, 1); gfx.fillCircleAtPoint(x + 2, y - 1, 1); blk()
end

-- host silhouettes, each read at a glance
local HostArt = {}

function HostArt.cow(x, y)
    shadow(x, y + 15, 54); blk()
    gfx.setLineWidth(3)
    for _, lx in ipairs({ -16, -6, 8, 18 }) do gfx.drawLine(x + lx, y + 2, x + lx, y + 15) end
    gfx.setLineWidth(1)
    gfx.fillEllipseInRect(x - 22, y - 14, 44, 22)   -- barrel body
    gfx.fillEllipseInRect(x + 13, y - 17, 17, 13)   -- head
    gfx.fillRect(x + 7, y - 11, 12, 8)              -- neck
    gfx.fillEllipseInRect(x + 26, y - 11, 8, 8)     -- muzzle
    gfx.fillTriangle(x + 15, y - 17, x + 11, y - 24, x + 20, y - 19) -- horn/ear
    gfx.drawLine(x - 22, y - 6, x - 29, y + 7)      -- tail
    wht(); gfx.fillCircleAtPoint(x - 7, y - 4, 4); gfx.fillCircleAtPoint(x + 5, y - 9, 3) -- patches
    gfx.fillCircleAtPoint(x + 22, y - 14, 1.5); blk() -- eye highlight
end

function HostArt.dog(x, y)
    shadow(x, y + 12, 36); blk()
    gfx.setLineWidth(2)
    for _, lx in ipairs({ -12, -4, 6, 12 }) do gfx.drawLine(x + lx, y + 2, x + lx, y + 12) end
    gfx.setLineWidth(1)
    gfx.fillEllipseInRect(x - 15, y - 9, 28, 15)    -- body
    gfx.fillEllipseInRect(x + 9, y - 15, 13, 12)    -- head
    gfx.fillRect(x + 17, y - 10, 7, 5)              -- snout
    gfx.fillTriangle(x + 9, y - 15, x + 7, y - 22, x + 14, y - 16) -- ear
    gfx.drawLine(x - 15, y - 6, x - 23, y - 13)     -- tail up
    wht(); gfx.fillCircleAtPoint(x + 14, y - 11, 1.3); blk()
end

function HostArt.kid(x, y)
    shadow(x, y + 13, 22); blk()
    gfx.fillCircleAtPoint(x, y - 18, 6)             -- head
    gfx.fillRect(x - 5, y - 13, 10, 15)             -- torso
    gfx.setLineWidth(2)
    gfx.drawLine(x - 5, y - 9, x - 11, y - 2)       -- arms
    gfx.drawLine(x + 5, y - 9, x + 11, y - 3)
    gfx.drawLine(x - 3, y + 2, x - 4, y + 13)       -- legs
    gfx.drawLine(x + 3, y + 2, x + 4, y + 13)
    gfx.setLineWidth(1)
    wht(); gfx.fillCircleAtPoint(x + 2, y - 19, 1.3); blk()
end

function HostArt.sleeper(x, y)
    shadow(x, y + 9, 60)
    gray(0.55); gfx.fillRoundRect(x - 27, y - 2, 54, 12, 3); blk() -- mattress
    gfx.drawRoundRect(x - 27, y - 2, 54, 12, 3)
    gfx.fillEllipseInRect(x - 22, y - 10, 36, 13)   -- blanket mound
    wht(); gfx.fillRoundRect(x + 13, y - 9, 13, 8, 2); blk(); gfx.drawRoundRect(x + 13, y - 9, 13, 8, 2) -- pillow
    gfx.fillCircleAtPoint(x + 19, y - 8, 4)         -- head
    gfx.drawText("z", x - 26, y - 20)               -- snore
end

local function bgAdult()
    -- horizon + ground band
    gray(0.42); gfx.fillRect(0, 196, C.W, 16); blk()
    gfx.drawLine(0, 196, C.W, 196)
    for i = 0, C.W, 16 do -- grass tufts
        gfx.drawLine(i, 196, i - 3, 190); gfx.drawLine(i, 196, i + 3, 189); gfx.drawLine(i, 196, i, 187)
    end
    if Threats.dusk() then
        blk(); gfx.fillCircleAtPoint(352, 36, 15)
        wht(); gfx.fillCircleAtPoint(358, 32, 13); blk() -- crescent moon
        for _, st in ipairs({ { 40, 28 }, { 92, 18 }, { 150, 40 }, { 300, 24 }, { 120, 52 }, { 250, 46 } }) do
            gfx.fillCircleAtPoint(st[1], st[2], 1)
        end
    else
        blk(); gfx.drawCircleAtPoint(352, 36, 13) -- sun
        for i = 0, 7 do
            local a = i * math.pi / 4
            gfx.drawLine(352 + math.cos(a) * 16, 36 + math.sin(a) * 16, 352 + math.cos(a) * 21, 36 + math.sin(a) * 21)
        end
    end
    -- white HUD tray so meters stay legible
    wht(); gfx.fillRect(0, 212, C.W, 28); blk(); gfx.drawLine(0, 212, C.W, 212)
end

-- ---- water stages -------------------------------------------------------------

local function waterScene()
    -- light water so black creatures pop (1-bit contrast); a slightly darker
    -- "deep" band lower down hints at depth without swallowing the sprites
    gray(0.14); gfx.fillRect(0, C.SURFACE_Y, C.W, C.H - C.SURFACE_Y); blk()
    gray(0.22); gfx.fillRect(0, 150, C.W, C.H - 150); blk()
    -- wavy surface with a thin sunlit band just under it (kept clear = safe air)
    local px, py = 0, C.SURFACE_Y
    for x = 0, C.W, 8 do
        local y = C.SURFACE_Y + math.sin(x * 0.12 + T() * 2) * 2
        gfx.drawLine(px, py, x, y); px, py = x, y
    end
    wht(); gfx.fillRect(0, C.SURFACE_Y - 8, C.W, 8); blk() -- safe surface band (breathe here)
    -- a reed
    gfx.setLineWidth(2); gfx.drawLine(374, C.SURFACE_Y - 2, 370, 150); gfx.setLineWidth(1)
    gfx.fillTriangle(370, 150, 366, 158, 374, 156)
    -- rising bubbles
    for i = 0, 5 do
        local bx = 40 + i * 62
        local by = C.H - ((T() * 26 + i * 33) % (C.H - C.SURFACE_Y)) - 4
        gfx.drawCircleAtPoint(bx, by, 1 + (i % 2))
    end
    -- white HUD tray so the meters/labels stay legible over the water
    wht(); gfx.fillRect(0, 212, C.W, 28); blk(); gfx.drawLine(0, 212, C.W, 212)
end

local function larvaShape(x, y)
    wht(); gfx.fillEllipseInRect(x - 7, y - 5, 15, 38); blk() -- soft halo lifts it off the water
    local wig = math.sin(T() * 6) * 3
    local seg = { { 0, 0, 4 }, { 2, 6, 3.4 }, { -1, 12, 3 }, { 2, 18, 2.4 }, { -1, 23, 1.7 } }
    for i, c in ipairs(seg) do gfx.fillCircleAtPoint(x + c[1] + wig * (i / 5), y + c[2], c[3]) end
    gfx.setLineWidth(2); gfx.drawLine(x - 1, y + 23, x - 5, y + 30); gfx.setLineWidth(1) -- siphon
    gfx.drawLine(x - 3, y - 2, x - 7, y - 4); gfx.drawLine(x - 3, y, x - 7, y - 1)       -- mouth brushes
    wht(); gfx.fillCircleAtPoint(x + 1, y - 1, 1.1); blk()
    local ch = G.larva and G.larva.chomp or 0
    if ch > 0 then gfx.drawCircleAtPoint(x, y - 1, 3 + (0.2 - ch) * 44) end -- eat pop
end

local function pupaShape(x, y)
    local prog = math.min(1, (G.pupa and G.pupa.meta or 0) / C.PUPA_T)
    local yb = y + math.sin(T() * 3) * 1.5 -- gentle tumble-bob
    local wig = math.sin(T() * 5) * 2
    -- the adult's wings form inside the case as metamorphosis completes
    if prog > 0.35 then
        local ww = (prog - 0.35) * 16
        blk()
        gfx.drawEllipseInRect(x - 4 - ww, yb - 13, ww, 8)
        gfx.drawEllipseInRect(x + 4, yb - 13, ww, 8)
    end
    blk()
    gfx.fillCircleAtPoint(x, yb, 7)                                    -- cephalothorax
    gfx.setLineWidth(2)
    gfx.drawLine(x - 2, yb - 6, x - 3, yb - 12); gfx.drawLine(x + 2, yb - 6, x + 3, yb - 12) -- trumpets
    gfx.setLineWidth(1)
    for _, c in ipairs({ { 5, 5, 4 }, { 8, 10, 3.2 }, { 6, 15, 2.3 }, { 2, 18, 1.6 } }) do
        gfx.fillCircleAtPoint(x + c[1] + wig, yb + c[2], c[3])         -- curled tail
    end
    wht(); gfx.fillCircleAtPoint(x + 2, yb - 2, 1.6); blk()
    if prog >= 1 then gfx.drawCircleAtPoint(x, yb, 11 + math.sin(T() * 6) * 2) end -- ready-to-emerge pulse
end

-- a predatory larva: bigger, with snapping mandibles at the front
local function predShape(p)
    local x, y, f = p.x, p.y, p.face or 1
    wht(); gfx.fillEllipseInRect(x - 15, y - 8, 30, 18); blk() -- halo for contrast
    local wig = math.sin(T() * 7 + x * 0.1) * 2
    for _, c in ipairs({ { -9, 0, 3.4 }, { -4, 1, 4.2 }, { 1, 0, 4.4 } }) do
        gfx.fillCircleAtPoint(x + c[1] * f, y + c[2] + wig, c[3]) -- fat body segments
    end
    local hx = x + 6 * f
    gfx.fillCircleAtPoint(hx, y, 3.6)                            -- head
    local gape = 2 + (0.5 + 0.5 * math.sin(T() * 6)) * 3         -- mandibles snap
    gfx.setLineWidth(2)
    gfx.drawLine(hx, y - 1, hx + 7 * f, y - gape)
    gfx.drawLine(hx, y + 1, hx + 7 * f, y + gape)
    gfx.setLineWidth(1)
    gfx.drawLine(x - 11 * f, y, x - 15 * f, y - 3)               -- tail
    wht(); gfx.fillCircleAtPoint(hx - 1 * f, y - 1, 1.1); blk()  -- eye
end

local function mote(m)
    blk(); gfx.fillCircleAtPoint(m.x, m.y, 2)
    gfx.drawLine(m.x - 3, m.y, m.x - 5, m.y - 1); gfx.drawLine(m.x + 3, m.y, m.x + 5, m.y + 1)
end

-- ---- courtship overlay --------------------------------------------------------

local function drawCourt()
    local c = G.court
    panel(46, 50, 308, 128)
    centered("COURTSHIP", 58)
    -- the two wings, his fixed marker and your gliding one, on a pitch line
    local x0, x1, y = 78, 322, 104
    blk(); gfx.drawLine(x0, y, x1, y)
    local mx = x0 + (x1 - x0) * c.target
    local px = x0 + (x1 - x0) * c.pitch
    skeeter(mx, y - 14, 0.8, -1, 0.8)                        -- his wing, above the line
    gfx.drawLine(mx, y - 6, mx, y + 6)
    gfx.fillTriangle(px - 5, y + 15, px + 5, y + 15, px, y + 5) -- your pitch pointer
    -- the beat made visible: an orb pulsing at the wah rate, still at unison
    local puls = 0.5 + 0.5 * math.sin((c.beatPhase or 0) * 2 * math.pi)
    gfx.fillCircleAtPoint(322, 66, 3 + puls * 6)
    if c.diff < C.LOCK_TOL then centered("* in tune *", 124) end
    meter(78, 140, 244, c.lock / C.LOCK_T, nil)
    centered("crank to tune   -   B to leave", 158)
end

-- ---- adult ---------------------------------------------------------------------

-- current facing from last x (shared by map + location)
local function playerFace(a)
    local f = (a.x >= (Draw._px or a.x)) and 1 or -1
    Draw._px = a.x
    return f
end

local function flap() return 0.5 + 0.5 * math.sin(T() * 34) end

-- a white chip behind a label so map text reads over the ground
local function chip(text, cx, cy)
    local tw, th = gfx.getTextSize(text)
    wht(); gfx.fillRect(cx - tw / 2 - 2, cy - 1, tw + 4, th + 2)
    blk(); gfx.drawTextAligned(text, cx, cy, kTextAlignment.center)
end

local function celestial()
    if Threats.dusk() then
        blk(); gfx.fillCircleAtPoint(352, 36, 15)
        wht(); gfx.fillCircleAtPoint(358, 32, 13); blk()
        for _, st in ipairs({ { 40, 28 }, { 92, 18 }, { 150, 40 }, { 300, 24 }, { 120, 52 } }) do
            gfx.fillCircleAtPoint(st[1], st[2], 1)
        end
    else
        blk(); gfx.drawCircleAtPoint(352, 36, 13)
        for i = 0, 7 do
            local a = i * math.pi / 4
            gfx.drawLine(352 + math.cos(a) * 16, 36 + math.sin(a) * 16, 352 + math.cos(a) * 21, 36 + math.sin(a) * 21)
        end
    end
end

-- ---- overworld map markers ----------------------------------------------------

local function houseIcon(x, y)
    blk()
    gfx.fillRect(x - 14, y - 2, 28, 18)                    -- walls
    gfx.fillTriangle(x - 17, y - 2, x + 17, y - 2, x, y - 18) -- roof
    wht(); gfx.fillRect(x - 4, y + 6, 9, 10); gfx.fillRect(x - 11, y + 1, 6, 6); gfx.fillRect(x + 6, y + 1, 6, 6)
    blk(); gfx.drawRect(x - 4, y + 6, 9, 10); gfx.drawRect(x - 11, y + 1, 6, 6); gfx.drawRect(x + 6, y + 1, 6, 6)
end

local function barnIcon(x, y)
    blk()
    gfx.fillRect(x - 18, y - 2, 36, 18)
    gfx.fillTriangle(x - 20, y - 2, x + 20, y - 2, x, y - 16) -- roof
    wht(); gfx.fillRect(x - 6, y + 4, 12, 12)             -- big door
    blk(); gfx.drawRect(x - 6, y + 4, 12, 12); gfx.drawLine(x, y + 4, x, y + 16)
    wht(); gfx.fillTriangle(x - 3, y - 6, x + 3, y - 6, x, y - 12); blk() -- hay loft
end

local function gardenIcon(x, y)
    blk()
    gfx.fillRect(x + 6, y + 2, 3, 14)                      -- trunk
    gfx.fillCircleAtPoint(x + 7, y - 3, 9)                 -- canopy
    wht(); gfx.fillCircleAtPoint(x + 4, y - 5, 2); blk()
    gfx.drawLine(x - 18, y + 16, x + 2, y + 16)            -- fence rail
    for fx = -18, 2, 6 do gfx.drawLine(x + fx, y + 16, x + fx, y + 9) end
    for i = 0, 2 do -- flowers along the fence
        local fx = x - 15 + i * 6
        gfx.fillCircleAtPoint(fx, y + 8, 2); gfx.drawLine(fx, y + 10, fx, y + 15)
    end
end

local ICON = { house = houseIcon, farm = barnIcon, garden = gardenIcon }

-- the Garden pond: glinting when wet (layable), a cracked basin when dry
local function pondShape(px, py, wet)
    if wet then
        gray(0.42); gfx.fillEllipseInRect(px - 24, py - 9, 48, 18); blk()
        gfx.drawEllipseInRect(px - 24, py - 9, 48, 18)
        wht(); gfx.drawLine(px - 8, py - 2, px + 4, py - 2); blk()
    else
        blk(); gfx.drawEllipseInRect(px - 24, py - 9, 48, 18)
        gfx.drawLine(px - 6, py, px + 1, py - 3); gfx.drawLine(px + 1, py - 3, px + 8, py + 2)
    end
end

local function drawMap()
    local a = G.adult
    celestial()
    gray(0.28); gfx.fillRect(0, 136, C.W, 76); blk(); gfx.drawLine(0, 136, C.W, 136) -- ground
    for i = 0, C.W, 18 do gfx.drawLine(i, 136, i - 3, 131); gfx.drawLine(i, 136, i + 3, 130) end -- grass
    for x = 40, 300, 12 do gfx.fillRect(x, 152, 5, 2) end -- trail dots between markers

    for _, name in ipairs(C.PLACE_ORDER) do
        local P = C.PLACES[name]
        ICON[name](P.mx, P.my)
        chip(P.name, P.mx, P.my + 22)
        if Util.near(a.x, a.y, P.mx, P.my, C.ENTER_R) then
            gfx.drawTextAligned("Ⓐ", P.mx, P.my - 36, kTextAlignment.center)
        end
    end

    if G.male then
        skeeter(G.male.x, G.male.y, 0.8, -1, 0.5 + 0.5 * math.sin(T() * 30))
        blk(); gfx.drawCircleAtPoint(G.male.x, G.male.y, C.COURT_R * (0.7 + 0.3 * math.sin(T() * 4)))
    end
    for _, b in ipairs(G.bats) do batShape(b.x, b.y) end
    skeeter(a.x, a.y, 0.95, playerFace(a), flap())

    wht(); gfx.fillRect(0, 212, C.W, 28); blk(); gfx.drawLine(0, 212, C.W, 212)
    meter(6, 224, 150, G.energy / C.ENERGY_MAX, "energy")
    meter(244, 224, 150, a.belly / C.BELLY_MAX, "belly")
    local tod = Threats.dusk() and "DUSK - bats hunt!" or G.weather.phase
    gfx.drawText(tod .. (G.mated and "   mated" or "   seeking a mate"), 6, 18)
    if a.mode == "court" then drawCourt() end
end

local function drawLocation()
    local a = G.adult
    local P = C.PLACES[G.place]
    bgAdult() -- grass horizon, celestial, white HUD tray
    chip(P.name, C.W / 2, 3)

    if P.nectar then flower(P.nectar.x, P.nectar.y) end
    if P.pond then pondShape(P.pond.x, P.pond.y, Weather.wet()) end

    local topAlert = 0
    for _, h in ipairs(G.hosts) do
        local art = HostArt[h.kind]; if art then art(h.x, h.y) end
        if h.swat then
            blk(); gfx.drawCircleAtPoint(h.x, h.y, h.reach + 4)
            gfx.drawText("!", h.x - 2, h.y - 30)
        elseif h.cd > 0 then
            gfx.drawText("z", h.x - 2, h.y - 30)
        end
        if h.alert > topAlert then topAlert = h.alert end
    end
    for _, s in ipairs(G.sprays) do sprayCloud(s) end

    skeeter(a.x, a.y, 0.95, playerFace(a), flap())

    meter(6, 224, 108, G.energy / C.ENERGY_MAX, "energy")
    meter(146, 224, 108, a.belly / C.BELLY_MAX, "belly")
    if P.hosts then
        meter(286, 224, 108, topAlert / C.ALERT_MAX, "host alert")
    elseif P.pond then
        gfx.drawText(Weather.wet() and "pond ready - Ⓐ lay" or "pond dry - needs rain", 286, 210)
    end
    gfx.drawText("Ⓑ leave", 340, 18)
end

local function drawAdult()
    if G.place == "map" then drawMap() else drawLocation() end
end

-- ---- frame dispatch -----------------------------------------------------------

function Draw.frame()
    gfx.clear(gfx.kColorWhite)
    blk()
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    local s = G.state

    if s == "title" then
        skeeter(150, 104, 3.4, 1, 0.5 + 0.5 * math.sin(T() * 3))
        drop(206, 138, 5)
        ribbon("BLOOD AND WHINE", 40)
        centered("a mosquito's bloodline", 170)
        centered("Ⓐ to hatch      best " .. (G.best or 0), 190)
        -- lineage evolution: what you've unlocked, or the next mutation ahead
        local un = {}
        for _, m in ipairs(Mut.LIST) do if Mut.has(m.key) then un[#un + 1] = m.name end end
        local evoLine = "evo " .. (G.evo or 0)
        if #un > 0 then
            evoLine = evoLine .. "  |  " .. table.concat(un, ", ")
        else
            local nx = Mut.next()
            if nx then evoLine = evoLine .. "  |  next: " .. nx.name .. " @" .. nx.cost end
        end
        centered(evoLine, 214)
    elseif s == "laid" then
        panel(60, 60, 280, 120)
        if G.newMut then centered("NEW MUTATION - " .. G.newMut, 74) end
        if G.maleRun then
            if G.lastFertile then
                drop(200, 96, 8)
                centered(G.lastEggs .. " eggs sired", 122)
                centered("your genes fly on", 144)
            else
                centered("no mate won", 104)
                centered("your line ends with you", 128)
            end
        elseif G.lastFertile then
            drop(200, 96, 8)
            centered(G.lastEggs .. " eggs laid", 122)
            centered("the bloodline continues", 144)
        else
            centered("infertile clutch", 104)
            centered("(you never found a mate)", 128)
        end
        centered("Ⓐ", 164)
    elseif s == "gameover" then
        panel(50, 56, 300, 128)
        centered(G.overReason or "GAME OVER", 84)
        centered("reached generation " .. (G.generation or 1), 116)
        centered("eggs banked: " .. (G.score or 0), 138)
        centered("Ⓐ", 168)
    elseif s == "raft" then
        local r = G.raft
        -- water channel with the drying mud banks closing in
        gray(0.36); gfx.fillRect(0, 78, C.W, 96); blk()
        for x = 0, C.W, 10 do gfx.drawLine(x, 118 + math.sin(x * 0.1 + T() * 2) * 2, x + 5, 118 + math.sin((x + 5) * 0.1 + T() * 2) * 2) end
        gray(0.85); gfx.fillRect(0, 78, r.dryL, 96); gfx.fillRect(r.dryR, 78, C.W - r.dryR, 96); blk()
        gfx.drawLine(r.dryL, 78, r.dryL, 174); gfx.drawLine(r.dryR, 78, r.dryR, 174)
        -- the egg raft, gently bobbing
        local bob = math.sin(T() * 2) * 2
        for _, e in ipairs({ { -9, 0 }, { -3, -1 }, { 3, -1 }, { 9, 0 }, { -6, 3 }, { 0, 3 }, { 6, 3 }, { 0, -3 } }) do
            local ex, ey = r.x + e[1], 128 + e[2] + bob
            blk(); gfx.fillEllipseInRect(ex - 2, ey - 4, 4, 8)
            wht(); gfx.fillCircleAtPoint(ex - 0.5, ey - 2, 1); blk()
        end
        hud()
        meter(120, 208, 160, r.hatch / C.RAFT_T, "hatching")
        gfx.drawText("steer to the water's center", 6, 18)
    elseif s == "larva" then
        waterScene()
        for _, m in ipairs(G.motes) do mote(m) end
        for _, p in ipairs(G.preds or {}) do predShape(p) end
        larvaShape(G.larva.x, G.larva.y)
        hud()
        meter(6, 224, 120, G.larva.breath / C.BREATH_MAX, "air")
        meter(270, 224, 120, G.larva.eaten / C.LARVA_TARGET, "grow")
    elseif s == "pupa" then
        waterScene()
        pupaShape(G.pupa.x, G.pupa.y)
        hud()
        local done = G.pupa.meta >= C.PUPA_T
        meter(120, 224, 160, G.pupa.meta / C.PUPA_T, done and "surface + Ⓐ to emerge" or "metamorphosis")
    elseif s == "adult" then
        drawAdult()
        hud()
    end
end
