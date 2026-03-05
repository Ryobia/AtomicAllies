# Game Design Document: Periodic Table Monster Battler

## Overview
A mobile elemental battler game set in a ship where players synthesize atomic elements to battle an entropic enemy faction called the Void. The game emphasizes team composition, element synergies, and strategic resource management.

## Core Mechanics

### Elements & Combat System
- **6 Total Elements on Field**: 3 active, 3 benched
- **Atomic Classes** (9 types based on periodic table groups):
	- Alkali Metals: Glass Cannons (High SPD/ATK, Low HP/DEF)
	- Alkaline Earths: Sturdy Tanks (High DEF, Moderate HP)
	- Transition Metals: Bruisers (Balanced high HP/ATK)
	- Noble Gases: Guardians (Highest DEF, Lowest ATK)
	- Actinides: Nukes (Highest stats, lowest Half-Life)
	- Halogens, Nonmetals, Metalloids, Post-Transition (Support/Utility roles)

- **Half-Life System**: Heavy elements decay over turns, forcing tactical swaps
- **Active Time Battle (ATB)**: Speed stat determines turn order via charging bars
- **3v3 Battlefield**: 1 tank front, 2 damage dealers back

### Progression Systems

**Element Synthesis**
- Breeding/fusion uses arithmetic: Element A (Z) + Element B (Z) = Element (Sum)
- Success calculated by parent levels and target atomic number
- Non-destructive: Parents remain but are fatigued for cooldown period
- Failed fusions award Neutron Dust currency

**Stability/Pity Mechanics**
- Fusion success chance = Base% + (Level Sum / Z Target)
- Minimum 15% success rate, maximum capped at 100%
- Failed fusions generate Neutron Dust for shop items
- Stable Isotopes (Shinies): 0.5% + bonus from parent levels

### Campaign & Endgame

**Campaign**: 60 floors (10 per atomic class group)
- Procedural encounter generation using "Point-Buy" weight system
- 3-6 enemy encounters (3 baseline to feel intimidating)
- Enemies scale in composition, not just stats

**Endless Mode**: Unlocks after campaign
- Bottomless procedural dungeons with escalating budgets
- Glitch/chaos modifiers increase frequency at depth
- Essence rewards higher than campaign

## Game Loop

1. **Synthesis Chamber**: Breed/fuse two elements with Essence cost
2. **Stellar Cradle**: Incubate eggs on timer (longer for higher tiers)
3. **Collection/Manifest**: Track discovered elements; unlock recipes
4. **The Crucible**: 3v3 turn-based combat in portrait mode

## UI/UX Design

**Portrait Mode Battle Layout**
- Top 50%: Enemy row, reaction space, player row
- Middle 30%: Dual health/stability bars for each element
- Bottom 20%: Attack buttons, bench icons, quick-swap system

**Mobile Optimization**
- One-handed play prioritized
- CanvasLayer split for UI stability
- Responsive button sizing for various devices

## Enemies: The Void

**Three Tiers**
- **Null-Walkers** (Grunts): Smoke-like humanoids with static eyes, 1-slot weight
- **Molecular Shredders** (Assassins): Obsidian shard clusters, target Half-Life, 2-slot weight
- **Abyssal Weavers** (Commanders): Lovecraftian entities that disrupt synergies, 3-slot weight

**Vibe**: Black smoke, red/purple accents, chromatic aberration shader, asymmetrical jagged forms

## Monetization & Shop

**Neutron Dust Shop** (Currency from failed fusions):
- Magnetic Stabilizer: +10% fusion success
- Lead Vest: 50% reduced fatigue on failure
- Coolant Gel: Instant fatigue clear
- Isotope Scanner: Reveals fusion results
- Heavy Water: Permanent Level Weight increase

**Future**: Optional paid legendary (Uranium) unavailable otherwise

## MVP Scope

**Phase 1**: Database, Global State, Navigation
**Phase 2**: Breeding Logic & Timers (with cheat-prevention)
**Phase 3**: Collection Grid & Discovery Tracking
**Phase 4**: Combat HUD & Battle System

**Starting Element Set**: First 10 (Hydrogen through Neon)
**Future Expansion**: Remainder of periodic table

## Technical Stack
- **Engine**: Godot 4.6
- **Language**: GDScript
- **Target**: Mobile (iOS/Android) in portrait mode
- **Database**: Local JSON persistence with Unix timestamp anti-cheat
- **Save System**: Unique collection IDs, level data, Essence counts, active timers
