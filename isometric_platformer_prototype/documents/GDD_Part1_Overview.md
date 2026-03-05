# ISOMETRIC PLATFORMER - GAME DESIGN DOCUMENT
## Part 1: Overview, Vision, and Core Pillars

**Version:** 1.0  
**Last Updated:** 2026-02-27  
**Engine:** Godot 4.5  
**Target Platforms:** PC (Steam), Console (Switch, PlayStation, Xbox)  
**Target Playtime:** 8-12 hours (main campaign)

---

## 1.1 ELEVATOR PITCH

A spiritual successor to **Snake: Rattle n' Roll** — a challenging isometric platformer with NES-era aesthetics, expanded into a full-length campaign across 9 themed worlds. Players navigate treacherous terrain, defeat enemies using Sonic-style homing attacks, and explore interconnected level segments to reach each stage's exit.

**One-Sentence Vision:**  
"Snake: Rattle n' Roll meets Sonic Adventure's homing attack, expanded into a modern 8-12 hour platforming adventure."

---

## 1.2 CORE EXPERIENCE PILLARS

### Pillar 1: Precision Isometric Platforming
- Tight, responsive controls with acceleration/deceleration curves
- Uniform screen-space movement speed (compensated for 2:1 isometric projection)
- Drop shadows for depth perception during jumps
- Wall collision that respects height differences
- Double jump for error correction and reaching high platforms

### Pillar 2: Combat Through Momentum
- Sonic-style homing attack replaces double jump when enemies are targeted
- Stomp mechanic for defeating enemies from above
- Chain attacks by bouncing between enemies without touching ground
- Combat rewards skilled movement, not button mashing

### Pillar 3: Exploration and Discovery
- Large levels composed of multiple interconnected segments
- Hidden paths, secret collectibles, and alternate routes
- Key-and-door progression within level segments
- Non-linear segment traversal within linear world progression

### Pillar 4: NES-Era Aesthetic, Modern Quality-of-Life
- 426x240 native resolution (widescreen NES)
- 16x8 pixel isometric tiles with checkerboard patterns
- Parallax scrolling backgrounds
- Unlimited continues, generous checkpoints
- Same-screen co-op with elastic tether system

---

## 1.3 TARGET AUDIENCE

**Primary:** Players aged 25-45 with nostalgia for NES/Genesis-era games  
**Secondary:** Younger players seeking challenging platformers (Celeste, Shovel Knight audience)  
**Tertiary:** Co-op players looking for couch multiplayer experiences

**Accessibility Considerations:**
- Adjustable difficulty (enemy count, damage, checkpoint frequency)
- Colorblind-friendly UI and enemy designs
- Remappable controls (two-button scheme with optional expanded controls)
- Clear visual feedback for all game states

---

## 1.4 COMPARABLE TITLES

| Title | What We Take | What We Avoid |
|-------|--------------|---------------|
| Snake: Rattle n' Roll | Isometric perspective, tile-based levels, NES aesthetic | Weight-based progression, punishing difficulty |
| Sonic Adventure | Homing attack, momentum-based combat | 3D camera issues, story bloat |
| Sonic 3D Blast | Isometric Sonic gameplay, collectible-focused design | Floaty controls, unclear depth |
| Landstalker | Isometric platforming, exploration | Sluggish movement, obtuse puzzles |
| Celeste | Tight controls, fair difficulty, hidden collectibles | Pixel-perfect precision requirements |

---

## 1.5 UNIQUE SELLING POINTS

1. **First true Snake: Rattle n' Roll successor** — No other game has captured this specific formula
2. **Homing attack in isometric perspective** — Novel combination that solves depth perception issues
3. **Full-length campaign** — 9 worlds, 117 levels, not a short retro novelty
4. **Co-op with elastic tether** — Knuckles Chaotix-inspired slingshot mechanics
5. **AI-optimized development** — Comprehensive documentation enabling rapid iteration

---

## 1.6 SCOPE SUMMARY

| Category | Count |
|----------|-------|
| Worlds | 9 |
| Levels per World | 13 |
| Total Levels | 117 |
| Boss Fights | 9 (one per world) + 1 final boss |
| Enemy Types | 27+ (3 unique per world) |
| Collectible Types | 3 (Keys, Secrets, Currency) |
| Playable Characters | 2 (for co-op, identical mechanics) |
| Estimated Dev Time | 18-24 months (solo/small team) |

---

## 1.7 DEVELOPMENT PHASES

### Phase 1: Vertical Slice (Months 1-3)
- Complete World 1 (all 13 levels + boss)
- All core mechanics finalized
- Placeholder art with consistent style
- Basic audio implementation
- **Gate:** If World 1 isn't fun, pivot core mechanics

### Phase 2: Content Production (Months 4-12)
- Worlds 2-6 developed
- Final art pipeline established
- Music and SFX production
- Regular playtesting cycles

### Phase 3: Content Completion (Months 13-18)
- Worlds 7-9 developed
- Co-op implementation and testing
- Polish pass on all content
- Localization preparation

### Phase 4: Polish and Launch (Months 19-24)
- Bug fixing and optimization
- Platform certification
- Marketing and community building
- Launch and post-launch support

---

## 1.8 RISK ASSESSMENT

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Scope creep | High | High | Strict feature freeze, cut features early |
| Isometric depth perception issues | Medium | High | Extensive drop shadow system, playtesting |
| Co-op implementation complexity | Medium | Medium | Design single-player first, add co-op layer |
| 117 levels becoming repetitive | Medium | High | Strong world theming, varied gimmicks |
| NES aesthetic limiting appeal | Low | Medium | Modern QoL features, accessibility options |

---

## 1.9 SUCCESS METRICS

**Critical (Must Achieve):**
- Core loop is fun within 5 minutes
- Controls feel responsive (input latency <100ms)
- Stable 60fps on target hardware
- No game-breaking bugs at launch

**Target:**
- 80%+ positive reviews on Steam
- Recoup development costs within 6 months
- Average playtime of 6+ hours (indicating engagement)

**Stretch:**
- 90%+ positive reviews
- Featured in platform storefronts
- Speedrunning community adoption

---

## IMPLEMENTATION NOTES FOR AI ASSISTANTS

When implementing features from this GDD:

1. **Reference the prototype** — Core systems (isometric projection, player controller, enemy, homing attack) are already implemented in `scripts/`
2. **Maintain existing architecture** — Extend existing scripts rather than creating parallel systems
3. **Follow Godot 4.5 conventions** — Use typed GDScript, signals for decoupling, @export for tunable values
4. **Test incrementally** — Each feature should be testable in isolation before integration
5. **Document changes** — Update this GDD when mechanics change during development

**Key Files:**
- `scripts/utils/iso_utils.gd` — Isometric coordinate conversion
- `scripts/player/player.gd` — Player controller with all movement mechanics
- `scripts/enemies/enemy.gd` — Base enemy class
- `scripts/level/test_level.gd` — Level structure and tile generation

---

*Continue to Part 2: Core Mechanics and Controls*
