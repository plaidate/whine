# Whine

A 1-bit Playdate game about a mosquito trying to continue her bloodline.

You drink **nectar to survive** and **blood to reproduce**. Blood is the only
path to eggs — and every host can kill you. You can only *lay* the eggs you've
earned in **standing water, which mostly appears after rain**. Play the whole
mosquito lifecycle across four stages, then loop into the next generation.

Tone: dark-comic, tense, tactile. The crank is your proboscis.

---

## 1. Central tension (the whole game)

Real mosquito biology is the design engine:

| Resource | Gives you | Risk | Who |
|----------|-----------|------|-----|
| **Nectar** | Fuel / wingbeat energy. No eggs. | Low (flowers don't swat) | Both sexes |
| **Blood** | A clutch of eggs (score / continuation). | High — every host can swat/spray/kill | Females only |
| **Water** | The only place to *lay* the clutch you carry | Evaporates; mostly appears after rain | — |

Every moment the player chooses **survive** (nectar, safe, no progress) vs.
**progress** (blood, deadly, the only way forward). Eggs are score and the
thread of continuation. That legible risk/reward is the entire loop.

---

## 2. Structure — the lifecycle IS the stage system

Each stage is a different life form with **its own control scheme**. This is
the game's signature: variety without inventing artificial "levels."

### Stage 1 — Egg raft (intro / tutorial)
- You are a floating raft of eggs.
- Minimal control: crank/tilt to keep the raft from drifting into a **drying
  edge** before they hatch.
- Teaches the core truth: **water = life, drying = death.**

### Stage 2 — Larva, the "Wriggler" (aquatic dodge)
- Underwater larva breathing through a **siphon** at the surface.
- **Crank to surface for air** (breath meter); dive to dodge predators
  (fish, dragonfly nymph, a dipping net).
- **Filter-feed** on drifting motes to grow through instars.
- Ends when you've eaten enough to pupate.

### Stage 3 — Pupa, the "Tumbler" (tense metamorphosis)
- Comma-shaped, **cannot eat** — only tumble away from danger while a
  metamorphosis meter fills.
- Short, held-breath stage.
- Climax: **emergence** — break the surface tension without being eaten. This
  is the risky hand-off into adulthood.

### Stage 4 — Adult female (the main game)
- Free flight. Seek nectar to survive, blood to make eggs, rain-water to lay.
- This is where most playtime lives — detailed below.

### Loop — the bloodline
- Eggs you lay become the **next generation's raft** → back to Stage 1.
- Death is not a hard reset: your **lineage persists** (see Meta).

**Optional biology twist:** occasionally you're born **male** — males don't
bite, they only drink nectar and mate. A male run is a pure survival /
pollinator bonus round built around the **harmonic-convergence courtship
minigame** (§3): as a male you converge onto a female, feeding her clutch and
scoring your run.

---

## 3. Adult stage — core loop & the crank

### Flight
- D-pad (or accelerometer) to move.
- **Wingbeat/energy meter** drains as you fly, refills from nectar.
- Hovering near a host builds the host's **alertness** meter.

### The crank IS the proboscis (signature mechanic)
- Land on exposed skin, then **crank to drill and pump blood**.
- Each full rotation draws more into your **abdomen** (a filling belly gauge).
- The fuller you get, the **heavier and slower** you are (harder to escape)
  AND the higher the host's alertness climbs toward a swat.
- **Push-your-luck:** more blood = bigger clutch, but a swat mid-feed = death.
  Detach (button) to bail with what you've earned.
- Crank *speed* matters: slow crank = quiet; fast crank fills faster but spikes
  alertness — and the **whine pitch rises** with danger.

### Courtship — harmonic convergence (crank tuning minigame)
Real biology: courting mosquitoes shift their wingbeat frequencies until a
shared **harmonic** locks (female fundamental ~400 Hz, male ~600 Hz, meeting at
a common overtone ~1200 Hz). This is a signature Playdate audio minigame.

- When a **male** appears (a drifting whine on the map), approach to enter
  courtship. His tone plays; your tone plays alongside.
- **Crank changes your wingbeat pitch.** As your tone nears a shared harmonic
  with his, the two produce **beats** — an audible "wah-wah-wah" that *slows as
  you converge* and goes silent at the lock. That beat-rate is the whole HUD:
  ear-driven, minimal on-screen clutter (a thin drifting bar as backup).
- Hold inside the **lock zone** for a short window to converge. He drifts, so
  you must keep re-tuning — a moving target, not a one-shot.
- **This is the fertility gate, not a booster.** A female must converge **once**
  to fertilize her lifetime egg supply; unmated clutches are **infertile** (they
  lay, but produce no next generation — a dead-end run). How *tightly / quickly*
  you locked sets a **fertility multiplier** carried for the season.
- **Male bonus run = same minigame, other side.** As a male you're the one
  converging onto a female; success there feeds her clutch and scores your run.

### Threats (escalate by host / time of day)
- **Swat** — a growing hand shadow; telegraphed, escapable if you leave in time.
- **Slap-on-landing** — twitchy hosts slap the instant they feel you; feed in bursts.
- **Bug spray / citronella** — area denial clouds; drift through = damage/repel.
- **Bats & swallows at dusk** — moving predators that hunt your whine (louder = more attention).
- **Rain itself** — fills nurseries but a heavy downpour can knock you out of the air.

Host roster (this is the "enemy variety," cheap on art since hosts are big flat
silhouettes): sleeping person (long safe feed, but wakes), a cow's tail, a
twitchy kid, a dog. Each has a distinct swat behavior.

---

## 4. Rain / water / egg-laying system

- A **weather clock** cycles sun → clouds → rain → puddles → drying.
- Puddles (tree hole, tire, gutter, discarded cup) appear **only after rain**
  and slowly evaporate.
- To score you must be **carrying a blood-clutch** AND reach standing water
  before it dries → **crank to oviposit**.
- Pacing pressure this creates: "Rain's coming — get a blood meal *now* so
  you're loaded when puddles form." Sun-drought stretches force nectar survival
  and waiting.

---

## 5. Meta-progression — the bloodline (evolution)

- Each **fertilized** clutch laid = points + a new generation. A clutch laid
  without converging on a male (§3) is infertile: it scores nothing toward the
  next generation. The **fertility multiplier** from a tight lock scales the
  generation's size / trait pool.
- Small persistent **mutations/unlocks** across generations: quieter wings,
  faster proboscis, spray resistance, night vision for the dusk bat stage.
- Death returns you to a hatch, but lineage traits persist.
- A run is a **season**; the meta is **evolution**. "One more generation" hook.

---

## 6. Playdate fit

- **1-bit:** tiny high-contrast mosquito sprite; hosts as big flat silhouettes;
  hand-shadow swat reads beautifully in pure black; dither for skin/water.
- **Crank:** proboscis feeding (rotations = blood drawn), larva surfacing,
  oviposition, egg-raft steering. Real, tactile, thematic jobs throughout.
- **Whine audio:** synth tone whose pitch tracks wingbeat effort + danger;
  feeding = a low pulsing pump synced to crank rotations.
- **Autopilot/smoke-testing:** crank-feed and BFS-to-water are scriptable for
  the usual autopilot harness (cf. Bin Night `need(kind)`); heartbeat tracing
  on the weather clock + clutch/energy meters.

---

## 7. Build plan (v1 = full four-stage lifecycle)

Per house convention: multi-file Lua via a global namespace table, standalone
`whine/` directory, autopilot smoke test from the start.

1. **State machine skeleton** — four stage states + generation loop + transitions.
2. **Stage 4 first (the meat)** — flight, wingbeat energy, crank-feed, belly/clutch,
   host + swat, nectar, rain clock, puddle spawn, oviposition. This is the fun core;
   validate it before building the smaller stages around it.
3. **Courtship minigame** — two-oscillator beat synth + crank-to-pitch + lock
   detection + fertility multiplier. Prototype early; the beat-tuning feel is
   the make-or-break of the mechanic and drives the audio engine reused by the
   whine.
4. **Stages 1–3** — egg-raft drift, larva dive/breathe/feed, pupa tumble/emerge.
5. **Meta** — persistent lineage traits + fertility via datastore.
6. **Audio** — whine synth + crank-pump (shares the courtship oscillators).
7. **Autopilot** — per-stage scripted policy incl. a crank-tune-to-lock routine;
   full-generation-completing run.

### Open questions for later
- Accelerometer vs. D-pad for adult flight (or both, player-selectable)?
- How punishing is death — restart at Stage 1 always, or checkpoint at last stage reached?
- Courtship difficulty: fixed male frequency, or does he actively evade (shift
  his own pitch) so convergence is a two-body chase?
- Does an unmated female get a grace path (find a male later), or is a missed
  early mating a locked-in infertile season?
