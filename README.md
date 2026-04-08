# OVM Dive Planner — iOS

Full-featured native iOS dive decompression planner. SwiftUI, Bühlmann ZHL-16C with gradient factors.
Mirrors all features of the OVM Deco Planner web app.

## Features

- Open Circuit (OC) and Closed Circuit Rebreather (CCR) modes
- Multi-level dive profiles
- Trimix support (N₂ + He)
- Bühlmann ZHL-16C algorithm with configurable Gradient Factor (GF) Low/High
- Automatic deco stops with gas switching at MOD
- CNS% and OTU tracking
- Gas usage calculation (SAC-based)
- CCR setpoints (low, high, deco) with auto bailout deco schedule
- Repetitive dives (surface interval + tissue carryover)
- Salt / fresh water selection
- Adjustable descent/ascent rates, SAC, last stop depth

---

## Building on macOS / Xcode

### Option A — XcodeGen (Recommended)

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen):
   ```bash
   brew install xcodegen
   ```
2. In Terminal, navigate to the `iOS/` folder:
   ```bash
   cd /path/to/deco-planner/iOS
   xcodegen generate
   ```
3. Open the generated `OVMDivePlanner.xcodeproj` in Xcode.
4. Select your development team in *Signing & Capabilities*.
5. Choose a simulator or device and press **Run (⌘R)**.

### Option B — Manual Xcode Project

1. Open Xcode → **File → New → Project → App**
2. Product name: `OVMDivePlanner`, Interface: SwiftUI, Language: Swift
3. Delete the placeholder `ContentView.swift` created by Xcode
4. Drag all `.swift` files from `iOS/OVMDivePlanner/` into the project, maintaining the group structure:
   ```
   Engine/
     BuhlmannEngine.swift
     DivePlanner.swift
   Models/
     Models.swift
   ViewModels/
     DivePlannerViewModel.swift
   Views/
     ContentView.swift
     PlannerView.swift
     ResultsView.swift
     SettingsView.swift
     RepetitiveDiveView.swift
   Utils/
     SharedComponents.swift
   OVMDivePlannerApp.swift
   ```
5. Make sure all files are in the `OVMDivePlanner` target.
6. Set minimum deployment target to **iOS 16.0**.
7. Build and run.

---

## File Structure

```
iOS/
├── project.yml                    ← XcodeGen spec
├── README.md
└── OVMDivePlanner/
    ├── OVMDivePlannerApp.swift    ← @main app entry
    ├── Engine/
    │   ├── BuhlmannEngine.swift   ← Bühlmann ZHL-16C tissue model
    │   └── DivePlanner.swift      ← planDive(), computeBailout(), helpers
    ├── Models/
    │   └── Models.swift           ← GasMix, DiveLevel, DivePlanInput, results
    ├── ViewModels/
    │   └── DivePlannerViewModel.swift
    ├── Views/
    │   ├── ContentView.swift      ← TabView root
    │   ├── PlannerView.swift      ← Dive input form
    │   ├── ResultsView.swift      ← Deco schedule + summary
    │   ├── SettingsView.swift     ← GF, rates, SAC
    │   └── RepetitiveDiveView.swift
    └── Utils/
        └── SharedComponents.swift ← LabeledSlider + reusable UI
```

---

## Algorithm Notes

The decompression engine is a Swift port of `buhlmann.js` / `planner.js` from the web app:

- **16 tissue compartments** (ZHL-16C N₂ and He parameters)
- **Schreiner equation** for linear depth-change segments
- **Haldane equation** for constant-depth segments
- **GF interpolation**: GF Low at first stop, linearly interpolating to GF High at surface
- **CNS** calculated from NOAA ppO₂ exposure limits
- **OTU** calculated as `time × ((ppO₂ − 0.5) / 0.5)^0.83`

> **Warning**: This app is for dive planning purposes only. All plans must be reviewed by a certified dive professional. Always carry appropriate tables and redundant equipment.
