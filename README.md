# Daily Numbers (Flutter)

A clean, daily number-guessing game with six rounds (3–8 digits). Deterministic daily secrets, crisp feedback tiles, and a simple flow designed to match the Figma handoff.

**Design (Figma):** https://www.figma.com/design/Wjdhkf9yE2XMiyzoEllQHD/Pre-handoff-checkpoint-v1?node-id=7518-199&t=KFSsBoU30mes9czx-1

---

## What’s inside (current build)

- **Flutter + Material 3** UI (scaffolded to match the Figma structure).
- **Font:** Nunito (design intent).  
- **Six rounds per day:** lengths = 3,4,5,6,7,8 (single session flow).
- **Deterministic daily secret** per day+length (seeded RNG).
- **Tile feedback:** Green = correct, Orange = wrong position, Grey = not present.
- **Status hint:** Higher / Lower chip in the round app bar (changes after each guess).
- **Guess history is scrollable** (previous guesses list scrolls; input row stays fixed).
- **Persistence:** Local stats & flags via `shared_preferences` (e.g., best/avg by length, “seen how-to”, etc.).
- **Daily reset at local midnight** (the next day’s secrets and counters roll over automatically).

> **Notes:** Uses Nunito + Material 3; previous guesses scroll; daily reset at midnight (local time).

---

## Quick start

```bash
# 1) Install dependencies
flutter pub get

# 2) Run (choose a device when prompted)
flutter run

# Optional: specify a device
flutter run -d windows       # desktop
flutter run -d chrome        # web
flutter run -d emulator-5554 # Android emulator if running
