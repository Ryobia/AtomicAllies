# Valence Interaction Engine (V.I.E.) - Elemental Class Roles

## System Overview

The Valence Interaction Engine transforms Atomic Allies from a burst-damage meta into a combo-driven, chemistry-inspired tactical system. Every element falls into one of two core roles: **Metals (Blue)** as Electron Donors and **Nonmetals (Red)** as Electron Acceptors. Beyond this binary, specialized classes add depth and strategic flexibility.

---

## Core Mechanics

### Binary Role System

**Metals (Blue) - "Electron Donors"**
- Every successful hit applies 1 Reduced [R] stack to enemies
- Function as "Primers" that set up high-damage payoffs
- Include: Alkali Metals, Alkaline Earth, Transition Metals, Lanthanides, and Actinides (91 total elements)

**Nonmetals (Red) - "Electron Acceptors"**
- Every hit checks target for [R] stacks and triggers Oxidation Burst if present
- Function as "Detonators" that consume stacked charges for massive multiplied damage
- Include: Halogens, Noble Gases, Chalcogens, Pnictogens, and Metalloids (27 total elements)

---

## Elemental Class Roles

### 1. **Alkali Metals (Group 1) - The Fast Primers**

**Combat Role:** High-speed stack applicators

**Core Mechanic:** Kinetic Excitation
- Apply [R] stacks consistently with every attack
- Gain 5% Action Gauge when applying [R] stacks (reinforces their "fast primer" identity)
- Ignore armor when delivering hits

**Vanguard Specialization:**
- Can serve as the center "Nucleus" unit
- Force enemies to attack them, building entropy stacks on the attacker through counterplay

**Strategic Value:**
- Go first and build pressure immediately
- Enable follow-up Nonmetal detonations with pre-stacked charges
- Ideal for aggressive, momentum-based playstyles

---

### 2. **Alkaline Earth Metals (Group 2) - The Sturdy Tanks**

**Combat Role:** Defensive Vanguard specialists

**Core Mechanic:** Crystalline Lattice
- Reduce incoming damage by 1% for every [R] stack on the attacker
- Apply 1 [R] stack to attackers when taking damage (25% chance)
- Generate charges defensively rather than offensively

**Vanguard Specialization:**
- Excel as the center "Nucleus" unit
- Enemies that attack them become progressively more vulnerable to Oxidation Bursts
- Scale defenses with the battle's ongoing reaction state

**Strategic Value:**
- Perfect for controlling the battle pace
- Create setup turns where enemies prime themselves
- Enable slower, more calculated team compositions

---

### 3. **Transition Metals (Groups 3-12) - The Catalytic Converters**

**Combat Role:** Reaction accelerators and utility specialists

**Core Mechanic:** Surface Catalysis
- Enemies with [R] stacks take 3% Max HP damage at the start of their turn
- Allow status effects (Poison, Burn) to trigger instantly
- Lower the "activation energy" for other reactions to occur

**Synergies:**
- Enhance debuff-heavy team compositions
- Accelerate damage-over-time stacking
- Provide consistent pressure without needing direct Oxidation Bursts

**Strategic Value:**
- Enable control-focused strategies
- Create win conditions through attrition
- Bridge Metal and Nonmetal phases of combat

---

### 4. **Lanthanides (Elements 57-71) - The Magnetic Amplifiers**

**Combat Role:** Debuff consolidation and boost multipliers

**Core Mechanic:** Magnetic Pull
- Condense all debuffs from the enemy team onto a single "Magnetized" target
- Increase status effect success rates by 2% per [R] stack on target
- Act as "Status Magnets" that concentrate pressure onto one enemy

**Advanced Mechanic (3+ Lanthanides):** Atomic Compression
- Apply passive "Gravity" effect that pulls all enemies into tight clustering
- Perfect setup for Alkali Metal area-of-effect Enthalpy Bursts

**Strategic Value:**
- Transform distributed damage into massive single-target hits
- Enable coordinated multi-element attacks
- Create "burst windows" for high-damage finishers

---

### 5. **Actinides (Elements 89-103) - The Critical Mass Nukes**

**Combat Role:** Heavy hitters with exponential scaling

**Core Mechanic:** Chain Decay
- If an Oxidation Burst kills an enemy, 50% of their [R] stacks jump to nearby allies
- Global "Radiation Field" ticks damage each turn, doubling when other reactions trigger
- Deal multiplicative damage based on battle chaos and reaction frequency

**Entropy Trade-off:**
- Generate significant Entropy (measured by D_n = D_0 · 2^n formula)
- Lower team Stability by 1% per turn while active
- Risk/reward dynamic for aggressive plays

**Strategic Value:**
- Serve as late-game finishers when momentum is established
- Chain reactions across enemy formations
- Require Noble Gas support to manage Entropy safely

---

### 6. **Halogens (Group 17) - The Reactive Detonators**

**Combat Role:** Rapid-fire Oxidation specialists

**Core Mechanic:** Reactive Hunger
- Electronegativity Delta (Δχ) multiplier increases by 0.1 per Halogen in party
- Benefit from cumulative [R] stack depth more than other Nonmetals
- Trigger Oxidation Bursts with high base multipliers

**Synergy Scaling:**
- Each additional Halogen in the squad increases all Halogen damage outputs
- Creates incentive to collect full elemental sets
- Rewards commitment to a specific class strategy

**Strategic Value:**
- Provide consistent, reliable damage output
- Scale elegantly with team composition
- Enable full-element set bonus farming

---

### 7. **Noble Gases (Group 18) - The Atomic Stabilizers**

**Combat Role:** Entropy management and defensive support

**Core Mechanic:** Atomic Stability
- Reduce Entropy generated by your team's reactions by 15%
- Cannot be debuffed by Void effects (act as "coolant units")
- Provide the only reliable defense against Heat Death events

**Vanguard Specialization:**
- Can serve as center Nucleus with Inert Barrier passive
- Block Creeping Entropy debuffs that other units cannot resist
- Restore HP per turn to provide sustained survivability

**Strategic Value:**
- Essential safety valve for high-intensity Actinide builds
- Enable prolonged fights against Entropy-heavy enemies
- Provide team-wide resilience without dealing massive damage

---

### 8. **Metalloids (7 Elements) - The Semiconductors & Wildcards**

**Combat Role:** Class bridge and set bonus amplifier

**Core Mechanic:** Resonance Link / Signal Amplification
- Count as members of your Vanguard's class for set bonuses
- "Link" elements of the same class, allowing shared passive buffs
- Create exponential stat growth through feedback loops

**Implementation:**
- Position-agnostic (no need to be adjacent to specific units)
- Adapt their utility based on which Vanguard is active
- Allow squad flexibility without compromising class synergies

**Strategic Value:**
- Enable hybrid team compositions
- Reduce collection burden (don't need full 118 elements)
- Create dynamic squad-building around a core Vanguard

---

### 9. **Alkali Metals (Special) - The Enthalpy Burst Masters**

**Specialized Mechanic:** Exothermic Runaway
- Gain damage multipliers based on environment and active status effects
- Trigger area-of-effect Enthalpy Bursts when enemies have "Wet" or "Vapor" status
- Deal AOE damage equal to: ΔH = Base Damage × (Atomic Mass × Stability)

**Combo Potential:**
- Setup environmental conditions to unlock massive payoffs
- Reward clever status effect stacking
- Create multi-turn strategic planning windows

---

## The Vanguard (Center Unit) - "The Nucleus Protocol"

### Core Function
The center slot creates a "Controlled Reaction Chamber" where:
- All single-target enemy attacks are forced to hit the Vanguard (Heavy Mass taunt)
- Enemies prime themselves by attacking repeatedly
- Setup phases occur naturally before combo payoff

### Vanguard-Exclusive Passives

**Electron Flux (General):** Every hit taken has 50% chance to apply [R] stack to attacker

**Class-Specific Vanguard Passives:**
- **Alkaline Earth:** Crystalline Lattice (reduce damage by 1% per enemy [R] stack)
- **Transition Metals:** Photon Shield (20% damage reflected as Entropy)
- **Noble Gases:** Inert Barrier (immunity to Void/Entropy debuffs)

### Strategic Implications
- Vanguard selection determines team identity and set bonus compatibility
- Enemies naturally build [R] stacks through attacking the Nucleus
- Defensive units become proactive combo enablers rather than passive blockers

---

## Combat Flow Example: The "Absurd" Payoff Loop

1. **Turn 1:** Alkaline Earth Vanguard taunts; enemy hits three times
2. **Turn 2:** Enemy has 3 [R] stacks from Electron Flux counterplay
3. **Turn 3:** Metalloid applies class-based buff through Resonance Link
4. **Turn 4:** Halogen Nonmetal triggers Oxidation Burst with massive multiplier (enemy pre-primed)
5. **Result:** Screen-bleaching damage numbers; Entropy rises; battle pressure peaks

---

## Balancing Considerations

### Health & Damage Recalibration
- Double base health pools to allow 3-5 turn minimum battles
- Encourage V.I.E. combos as the optimal (not mandatory) win condition
- Create windows for strategic play rather than luck-based one-shots

### Entropy Management
- Player must balance high-damage Actinide builds with Noble Gas stabilizers
- Enemy "Creeping Entropy" creates urgency without instant-death mechanics
- Heat Death events mark the timeout for prolonged stalling

### Turn Timeline UI
- Display next 10 turns ordered by Action Gauge
- Show exact turn when enemies hit max Entropy
- Allow players to calculate multi-turn combo windows in advance

---

## Collection & Progression

**91 Metal Elements** provide diverse primer strategies and Vanguard options
**27 Nonmetal Elements** serve as high-value detonators and tactical specialists
**Set Bonuses** reward full class collection without requiring all 118 elements
**Mastery at 100% Stability** grants "Chemical Efficiency" bonuses (reduced Entropy generation, faster reaction speeds)

