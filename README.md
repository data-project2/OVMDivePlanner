# OVM Dive Planner

OVM Dive Planner is a native iOS dive planning app built with SwiftUI for technical and recreational dive planning workflows.

It combines a Bühlmann ZH-L16C decompression engine with gradient factors, open-circuit and CCR planning, repetitive dive support, gas usage estimation, and a built-in gas mixer. The app supports both list-based and visual profile editing.

## Features

- Open-circuit and CCR planning
- Bühlmann ZH-L16C decompression model
- Configurable gradient factors
- Multi-level dive planning
- Visual planner with draggable waypoints
- List planner for discrete depth/time level entry
- Deco gas planning with manual or automatic switch depths
- Oxygen exposure tracking with CNS and OTU output
- Gas usage estimation
- Repetitive dive planning with tissue carry-over
- Metric and imperial unit support
- Persistent planner and settings values
- Gas mixer for nitrox and trimix calculations

## Planner Modes

### Visual Planner

The visual planner provides a chart-based way to create and adjust the dive profile.

- Depth is shown on the Y axis with `0 m` at the top
- Runtime is shown on the X axis
- Waypoints can be added directly on the chart
- Existing waypoints can be dragged to change depth or hold time
- Chart bounds expand with the profile to preserve editing room
- Calculated decompression stops are shown on the profile after a plan is run

### List Planner

The list planner provides structured depth/time entry.

- Each level is entered as depth plus duration
- The same underlying profile is shared with the visual planner
- Planner sections can be collapsed to improve usability on smaller screens

## Core Planning Scope

The current app supports:

- Open-circuit bottom gas planning
- CCR planning with diluent/bailout workflow
- Deco gases with gas switch depths
- Runtime calculation including level time and transit time
- Warnings for unsafe or inconsistent gas/deco inputs

The app is intended as a planning tool. It does not replace dive training, team procedures, or a certified dive computer.

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
│   │   ├── MixerView.swift
│   │   ├── PlannerView.swift
│   │   ├── RepetitiveDiveView.swift
│   │   ├── ResultsView.swift
│   │   └── SettingsView.swift
│   └── OVMDivePlannerApp.swift
├── OVMDivePlannerTests/
├── project.yml
├── README.md
└── appstore.png
```

## Build Requirements

- macOS with Xcode
- iOS deployment target: `16.0`
- Swift `5.9`
- XcodeGen if regenerating the project from `project.yml`

## Build Configuration

Current project configuration in [`project.yml`](/Users/ferryoukerk/Documents/OVMDivePlanner/project.yml):

- App name: `OVMDivePlanner`
- Bundle identifier: `com.ovm.OVMDivePlanner.OVMDivePlanner`
- Marketing version: `1.0`
- Build number: `1`
- Development team: `DKA242B3QX`
- iPhone orientations: portrait and landscape

## Building

### Open in Xcode

Open the project in Xcode and build the `OVMDivePlanner` scheme.

Use automatic signing with:

- Bundle ID: `com.ovm.OVMDivePlanner.OVMDivePlanner`
- Team ID: `DKA242B3QX`

### Regenerate From XcodeGen

If you use XcodeGen, regenerate from `project.yml` and then open the generated Xcode project:

```bash
brew install xcodegen
cd /Users/ferryoukerk/Documents/OVMDivePlanner
xcodegen generate
```

## Testing

The repository includes unit coverage for planner and model sanity checks, including:

- depth and pressure conversion
- open-circuit runtime sanity
- hypoxic gas warnings
- manual deco switch depth warning behavior
- CCR bailout planning sanity
- imperial unit normalization

Tests are located in [`OVMDivePlannerTests`](/Users/ferryoukerk/Documents/OVMDivePlanner/OVMDivePlannerTests).

## App Store Submission Notes

Before submission, verify:

- signing and provisioning are correct for the release team
- version and build number are incremented
- screenshots and metadata are complete in App Store Connect
- privacy answers are complete and accurate
- final archive validates cleanly in Xcode

## Safety Notice

This software is a dive planning aid only.

Every plan must be independently checked before use. The diver remains responsible for gas selection, exposure management, decompression strategy, equipment setup, and operational safety.
