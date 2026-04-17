# OVM Dive Planner

Native iOS dive planning app built with SwiftUI.

The app calculates decompression schedules using a Bühlmann ZH-L16C model with gradient factors and supports both open-circuit and CCR workflows. It also includes a gas mixer and a visual dive profile editor.

## Core Functionality

- Open Circuit and CCR planning
- Bühlmann ZH-L16C decompression model
- Configurable GF low / high
- Multi-level dive planning
- List-based and visual profile planning modes
- Trimix and helium support
- Deco gas management with switch depths
- CNS and OTU tracking
- Gas usage estimation
- Repetitive dive planning with tissue carry-over
- Metric and imperial unit support
- Persistent planner settings
- Gas mixer tools for boost, top-off blend, and trimix fill calculations

## Planner Modes

### Visual Planner

The visual planner is the default planner screen.

- Y axis represents depth
- X axis represents runtime
- Add waypoints directly on the chart
- Drag waypoints vertically to change depth
- Drag waypoints horizontally to change hold time
- Later waypoints shift in runtime automatically
- Chart range expands dynamically based on the current profile

### List Planner

The list planner remains available as an alternative editor.

- Depth and time are entered as discrete levels
- The same underlying dive profile is used by both list and visual modes

## Project Structure

```text
OVMDivePlanner/
├── OVMDivePlanner/
│   ├── Assets.xcassets
│   ├── Engine/
│   │   ├── BuhlmannEngine.swift
│   │   ├── DivePlanner.swift
│   │   └── MixerEngine.swift
│   ├── Models/
│   │   └── Models.swift
│   ├── Utils/
│   │   └── SharedComponents.swift
│   ├── ViewModels/
│   │   ├── DivePlannerViewModel.swift
│   │   └── MixerViewModel.swift
│   ├── Views/
│   │   ├── ContentView.swift
│   │   ├── PlannerView.swift
│   │   ├── RepetitiveDiveView.swift
│   │   ├── ResultsView.swift
│   │   ├── SettingsView.swift
│   │   └── MixerView.swift
│   └── OVMDivePlannerApp.swift
├── OVMDivePlannerTests/
├── project.yml
├── appstore.png
└── README.md
```

## Build Requirements

- macOS with Xcode
- iOS deployment target: 16.0
- Personal or paid Apple Developer team for device signing

## Build and Run

### Open in Xcode

Open the project/workspace you are using locally and build the `OVMDivePlanner` scheme.

If you regenerate from `project.yml`, make sure Xcode uses:

- Bundle ID: `com.ovm.OVMDivePlanner.OVMDivePlanner`
- Team ID: `DKA242B3QX`
- Automatic signing

### Command-Line Generation

If you use XcodeGen:

```bash
brew install xcodegen
cd /Users/ferryouwerkerk/Documents/OVMDivePlanner
xcodegen generate
```

Then open the generated Xcode project and run the app.

## Testing

The repository includes unit tests for core planner behavior, including:

- pressure/depth conversions
- gas selection logic
- no-decompression runtime sanity
- CCR bailout sanity
- imperial unit normalization

## App Store Preparation

The project is prepared with:

- explicit marketing version and build number
- automatic signing enabled in `project.yml`
- privacy manifest file at `OVMDivePlanner/PrivacyInfo.xcprivacy`
- app icon asset configuration

Manual App Store steps still required:

- archive in Xcode
- validate and upload build
- complete App Store Connect metadata
- complete the App Privacy questionnaire
- add screenshots and descriptions

## Safety Notice

This software is a planning tool, not a substitute for proper dive training, dive tables, or certified dive computer procedures.

Every plan should be independently reviewed before use in the water.
