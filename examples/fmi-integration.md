# SysML v2 + Modelica/FMI Integration Guide

This guide walks through a complete workflow for integrating a SysML v2 system model
with Modelica-based simulation using `sysml2-mode` and `sysml2-cli`.

## Overview

The workflow follows the standard MBSE co-simulation pattern:

1. **Define** the system architecture in SysML v2 (ports, parts, connections)
2. **Extract** FMI interface contracts from the SysML model
3. **Generate** Modelica stubs with correct connectors and parameters
4. **Implement** behavioral equations in Modelica (OpenModelica, Dymola, etc.)
5. **Compile** Modelica models to FMUs (Functional Mock-up Units)
6. **Validate** FMU interfaces against SysML contracts
7. **Assemble** SSP (System Structure and Parameterization) for co-simulation
8. **Run** co-simulation and verify requirements against results

## Step 1: Define the System in SysML v2

Create a file `thermal-system.sysml`:

```sysml
package ThermalSystem {

    // === Port Definitions ===
    // Ports define the interface contract between components.
    // Items inside ports become FMI variables.

    port def HeatPort {
        out item temperature : Real;    // FMI output: Float64
        out item heatFlow : Real;       // FMI output: Float64
    }

    port def CoolantPort {
        in item flowRate : Real;        // FMI input: Float64
        in item inletTemp : Real;       // FMI input: Float64
        out item outletTemp : Real;     // FMI output: Float64
    }

    port def ControlPort {
        in item setpoint : Real;        // FMI input: Float64
        out item controlSignal : Real;  // FMI output: Float64
    }

    port def SensorPort {
        out item measuredTemp : Real;   // FMI output: Float64
    }

    // === Part Definitions ===
    // Parts define the components with their interfaces and parameters.

    part def Heater {
        // Ports — these become FMI interface items
        port heatOut : HeatPort;
        port control : ~ControlPort;    // Conjugated: in/out flipped

        // Attributes — these become Modelica parameters
        attribute maxPower : Real;
        attribute efficiency : Real;
    }

    part def HeatExchanger {
        port heatIn : ~HeatPort;        // Conjugated: receives heat
        port coolant : CoolantPort;

        attribute surfaceArea : Real;
        attribute heatTransferCoeff : Real;
    }

    part def Controller {
        port sensor : ~SensorPort;      // Conjugated: receives measurement
        port output : ControlPort;

        attribute kp : Real;            // Proportional gain
        attribute ki : Real;            // Integral gain
    }

    // === System Composition ===

    part def ThermalControlSystem {
        // Component instances
        part heater : Heater;
        part exchanger : HeatExchanger;
        part controller : Controller;

        // Connections define the SSP wiring
        connection heaterToExchanger
            connect heater.heatOut to exchanger.heatIn;

        connection sensorFeedback
            connect exchanger.coolant to controller.sensor;

        connection controlLoop
            connect controller.output to heater.control;
    }

    // === Requirements ===

    requirement def MaxTempReq {
        doc /* temperature <= 150 */
        subject s : ThermalControlSystem;
    }

    requirement def SettlingTimeReq {
        doc /* System reaches setpoint within 30 seconds */
    }

    requirement def EfficiencyReq {
        doc /* heatFlow >= 0.8 * maxPower * controlSignal */
    }
}
```

## Step 2: Explore the Model

Open `thermal-system.sysml` in Emacs. With `sysml2-mode`, you get:
- Syntax highlighting for all SysML v2 keywords
- Outline navigation (`C-c C-n t` or `SPC m o`)
- Imenu jump-to-definition (`C-c C-n o`)

### List Exportable Parts

Press `C-c C-x l` (or `SPC m x l`) to list simulatable constructs, then:

```
sysml2-cli export list thermal-system.sysml
```

Or from the command line:
```sh
sysml2-cli export list thermal-system.sysml
```

Output:
```
Exportable Parts:
  Heater (2 ports, 2 attributes, 0 connections)
  HeatExchanger (2 ports, 2 attributes, 0 connections)
  Controller (2 ports, 2 attributes, 0 connections)
  ThermalControlSystem (0 ports, 0 attributes, 2 connections)
```

## Step 3: Extract FMI Interfaces

### From Emacs

Press `C-c C-s e` and enter `Heater` when prompted. This calls `sysml2-cli export interfaces`
under the hood and displays the results:

```
FMI Interface: Heater
------------------------------------------------------------
Name            Direction  SysML Type   FMI Type   Causality    Port
----------------------------------------------------------------------
temperature     out        Real         Float64    output       heatOut
heatFlow        out        Real         Float64    output       heatOut
setpoint        out        Real         Float64    output       control
controlSignal   in         Real         Float64    input        control
```

Note how the `control` port uses `~ControlPort` (conjugated), so its directions are
flipped: the `ControlPort`'s `in item setpoint` becomes `out` on the Heater, and
`out item controlSignal` becomes `in`.

### From the Command Line

```sh
# Text output
sysml2-cli export interfaces thermal-system.sysml --part Heater

# JSON for tooling
sysml2-cli -f json export interfaces thermal-system.sysml --part Heater
```

The JSON output is what `sysml2-mode` consumes internally for its display buffers.

## Step 4: Generate Modelica Stubs

### From Emacs

Press `C-c C-s m` and enter `Heater`. You'll be prompted for an output path.
The generated file opens in a split window:

### From the Command Line

```sh
sysml2-cli export modelica thermal-system.sysml --part Heater --output Heater.mo
```

Output (`Heater.mo`):
```modelica
partial model Heater
  "Generated from SysML v2 part def Heater"
  Modelica.Blocks.Interfaces.RealOutput temperature "From port heatOut";
  Modelica.Blocks.Interfaces.RealOutput heatFlow "From port heatOut";
  Modelica.Blocks.Interfaces.RealOutput setpoint "From port control";
  Modelica.Blocks.Interfaces.RealInput controlSignal "From port control";
  parameter Real maxPower "From SysML attribute";
  parameter Real efficiency "From SysML attribute";
equation
  // Equations to be filled by model developer
end Heater;
```

Do the same for all components:
```sh
sysml2-cli export modelica thermal-system.sysml --part HeatExchanger -o HeatExchanger.mo
sysml2-cli export modelica thermal-system.sysml --part Controller -o Controller.mo
```

## Step 5: Implement Behavioral Equations

Open each `.mo` file and fill in the physics. For example, `Heater.mo`:

```modelica
model Heater
  "Resistive heater with efficiency losses"
  Modelica.Blocks.Interfaces.RealOutput temperature "From port heatOut";
  Modelica.Blocks.Interfaces.RealOutput heatFlow "From port heatOut";
  Modelica.Blocks.Interfaces.RealOutput setpoint "From port control";
  Modelica.Blocks.Interfaces.RealInput controlSignal "From port control";
  parameter Real maxPower = 5000 "Maximum power [W]";
  parameter Real efficiency = 0.85 "Thermal efficiency";

  // Internal state
  Real internalTemp(start=20) "Internal temperature [C]";
  constant Real thermalMass = 500 "J/K";
equation
  heatFlow = maxPower * controlSignal * efficiency;
  der(internalTemp) = (heatFlow - 10*(internalTemp - 20)) / thermalMass;
  temperature = internalTemp;
  setpoint = 0; // Driven externally in co-simulation
end Heater;
```

## Step 6: Compile to FMU

Use OpenModelica to compile each Modelica model to an FMU:

```sh
# Using OpenModelica command-line
omc --simCodeTarget=fmu Heater.mo
omc --simCodeTarget=fmu HeatExchanger.mo
omc --simCodeTarget=fmu Controller.mo
```

This produces `Heater.fmu`, `HeatExchanger.fmu`, and `Controller.fmu`.

## Step 7: Validate FMU Interfaces

### From Emacs

Press `C-c C-s v`, select the FMU file, and enter the part name.
A validation dashboard shows matches, mismatches, and missing variables.

### Understanding Validation Results

```
FMI Interface Validation
--------------------------------------------------

FMU:      Heater.fmu
Part Def: Heater

MATCHES (4)
  temperature
  heatFlow
  setpoint
  controlSignal

TYPE MISMATCHES (0)

FMU ONLY (1)
  internalTemp    (local state variable, OK)

SYSML ONLY (0)
```

- **MATCHES**: FMU and SysML agree on name, type, and causality
- **TYPE MISMATCHES**: FMU has a different type than SysML expects (needs fixing)
- **FMU ONLY**: Variables in the FMU not declared in SysML (often internal states — OK)
- **SYSML ONLY**: SysML declares an interface the FMU doesn't implement (needs fixing)

## Step 8: Generate SSP and Run Co-Simulation

### Generate SSP XML

From Emacs, press `C-c C-s g` with `thermal-system.sysml` open. Or from CLI:

```sh
sysml2-cli export ssp thermal-system.sysml --output system.ssd
```

This produces a SystemStructureDescription with components wired according to
the SysML connections.

### Assemble the SSP Package

The SSP file needs FMUs bundled alongside the SSD:

```
system.ssp (ZIP archive)
  SystemStructure.ssd        ← Generated XML
  resources/
    heater.fmu               ← Compiled Modelica FMU
    heatexchanger.fmu        ← Compiled Modelica FMU
    controller.fmu           ← Compiled Modelica FMU
```

From Emacs, `C-c C-s g` handles the packaging automatically.

### Run Co-Simulation

From Emacs, press `C-c C-s r` and select the `.ssp` file:

```
Starting simulation: system.ssp
Simulation complete: results.csv
```

The simulation runs asynchronously via FMPy or OMSimulator (configurable via
`sysml2-cosim-tool`).

## Step 9: Verify Requirements

Press `C-c C-s c` to verify requirements against simulation results:

```
Requirement Verification Dashboard
------------------------------------------------------------

Requirement          Constraint           Signal     Result     Value
---------------------------------------------------------------------------
MaxTempReq           temperature <= 150   temperature PASS       max=142.3
SettlingTimeReq                                      MANUAL     Complex constraint
EfficiencyReq                                        MANUAL     Complex constraint
```

Requirements with simple `SIGNAL OP VALUE` patterns in their `doc` comments are
automatically checked. Complex constraints are flagged for manual review.

## Key Bindings Reference

| Binding | Doom | Command | Description |
|---------|------|---------|-------------|
| `C-c C-s e` | `SPC m s e` | `sysml2-fmi-extract-interfaces` | Extract FMI interfaces |
| `C-c C-s m` | `SPC m s m` | `sysml2-fmi-generate-modelica` | Generate Modelica stub |
| `C-c C-s v` | `SPC m s v` | `sysml2-fmi-validate-interfaces` | Validate FMU interfaces |
| `C-c C-s i` | `SPC m s i` | `sysml2-fmi-inspect-fmu` | Inspect FMU contents |
| `C-c C-s g` | `SPC m s g` | `sysml2-cosim-generate-ssp` | Generate SSP package |
| `C-c C-s r` | `SPC m s r` | `sysml2-cosim-run` | Run co-simulation |
| `C-c C-s p` | `SPC m s p` | `sysml2-cosim-results` | View results |
| `C-c C-s c` | `SPC m s c` | `sysml2-cosim-verify-requirements` | Verify requirements |

## Configuration

```elisp
;; Tool selection for co-simulation
(setq sysml2-cosim-tool 'fmpy)            ; or 'omsimulator
(setq sysml2-cosim-stop-time 60.0)        ; simulation duration (seconds)
(setq sysml2-cosim-step-size 0.01)        ; integration step size

;; Output paths
(setq sysml2-fmi-modelica-output-dir "~/models/modelica/")
(setq sysml2-cosim-output-dir "~/models/results/")

;; Custom type mapping (extend the built-in SysML → FMI map)
(setq sysml2-fmi-type-mapping-alist
      '(("Voltage" . "Float64")
        ("Current" . "Float64")))
```

## Troubleshooting

### "Cannot find sysml2-cli on exec-path"

Install sysml2-cli:
```sh
git clone https://github.com/jackhale98/tree-sitter-sysml.git
git clone https://github.com/jackhale98/sysml-lint.git
cd sysml-lint
cargo install --path .
```

Ensure `~/.cargo/bin` is in your shell PATH.

### Regex fallback active

If `sysml2-cli` is not on your PATH, FMI extraction falls back to regex-based parsing.
This works for simple models but may miss edge cases (nested ports, complex conjugation).
Install `sysml2-cli` for full tree-sitter AST accuracy.

### FMU validation shows all items as "SYSML ONLY"

The FMU's `modelDescription.xml` variable names must match the SysML `item` names exactly.
Check that your Modelica model uses the same connector names as the generated stub.
