# Temperature Policies & Excursion Formulae

## 1. Fixed-Point Representation
All temperature values in smart contracts and firmware are represented as **signed 16-bit integers ($int16$) in centi-degrees Celsius ($\times 100$)**:

| Real Temperature (°C) | Int16 Encoding | Description |
|---|---|---|
| $+2.00^\circ\text{C}$ | `200` | Standard vaccine lower bound |
| $+8.00^\circ\text{C}$ | `800` | Standard vaccine upper bound |
| $-20.00^\circ\text{C}$ | `-2000` | Frozen goods standard |
| $-80.00^\circ\text{C}$ | `-8000` | Ultra-cold mRNA vaccine standard |
| $+25.50^\circ\text{C}$ | `2550` | Ambient excursion point |

---

## 2. Standard Policy Profiles

### 2.1 Standard Vaccine & Biologics Profile
- `minTemp`: `200` (+2.00°C)
- `maxTemp`: `800` (+8.00°C)
- `maxContinuousExcursionSeconds`: `1800` (30 minutes)
- `maxCumulativeExcursionSeconds`: `7200` (2 hours)
- `penaltyPerExcursionMinute`: `10` USDC
- `spoilageThresholdTemp`: `1500` (+15.00°C) or `0` (Freezing breach <= 0°C) -> 100% penalty (cargo considered total loss).

### 2.2 Deep-Frozen Profile
- `minTemp`: `-2500` (-25.00°C)
- `maxTemp`: `-1500` (-15.00°C)
- `maxContinuousExcursionSeconds`: `900` (15 minutes)
- `spoilageThresholdTemp`: `-500` (-5.00°C).

### 2.3 Controlled Room Temperature (CRT) Profile
- `minTemp`: `1500` (+15.00°C)
- `maxTemp`: `2500` (+25.00°C)
- `maxContinuousExcursionSeconds`: `7200` (2 hours).

---

## 3. Penalty Calculation Formula

Let:
- $T_{\text{meas}}$ = measured temperature.
- $D_{\text{exc}}$ = duration of excursion in minutes beyond allowable grace period $G$.
- $P_{\text{base}}$ = base fee per minute of breach.
- $S_{\text{mult}}$ = severity multiplier based on degrees exceeded:
  $$S_{\text{mult}} = 1 + \frac{\max(0, T_{\text{meas}} - T_{\max}, T_{\min} - T_{\meas})}{100}$$

Total Penalty:
$$\text{Penalty} = \min\left(\text{EscrowMaxPenalty}, \sum_{\text{events}} (D_{\text{exc}} \times P_{\text{base}} \times S_{\text{mult}})\right)$$
If a critical spoilage threshold is violated, penalty is automatically clamped to 100% of the penalty reserve.
