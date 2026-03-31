# Literate Systems Engineering with SysML v2 and Org-Babel

This guide demonstrates how to use Emacs org-mode with `sysml2-mode` for **literate systems engineering** — weaving together requirements narratives, design rationale, and executable SysML v2 model definitions in a single document.

## Why Literate Systems Engineering?

Traditional MBSE tools separate documentation from models. Engineers write requirements in Word, models in a tool, and traceability in a spreadsheet. Changes in one are invisible to the others.

With literate SysML, your org document **is** the model:

- Requirements text and SysML definitions live side by side
- `org-babel-tangle` extracts a complete, valid `.sysml` model
- Code blocks can be executed to validate, simulate, and visualize
- Git tracks the document and the model together
- Pandoc exports to PDF/HTML for formal review

## Setup

Add to your Emacs config:

```elisp
(require 'sysml2-mode)

;; Optional: load org-babel SysML support eagerly
(require 'ob-sysml)

;; Ensure sysml is in org-babel's list of languages
(org-babel-do-load-languages
 'org-babel-load-languages
 '((sysml . t)))
```

The `sysml` CLI must be on your `exec-path` for execution features (check, simulate, diagram). Tangling and noweb composition work without it.

## Example: Drone Delivery System

The rest of this document walks through building a complete drone delivery system model using literate programming. Each section adds SysML definitions that compose into a final tangled model.

### Project Structure

We'll produce a single `drone-system.sysml` file by tangling all blocks:

```
#+PROPERTY: header-args:sysml :tangle drone-system.sysml :noweb yes
```

This org property tells every SysML block to tangle into `drone-system.sysml` and to expand `<<noweb-references>>`.

### 1. Package Declaration

Every SysML v2 model starts with a package. We declare ours and import the standard libraries:

```org
#+BEGIN_SRC sysml
package DroneDeliverySystem {
    public import ISQ::*;
    public import SI::*;
    public import ScalarValues::*;

    <<port-definitions>>
    <<part-definitions>>
    <<requirements>>
    <<state-machines>>
    <<actions>>
    <<connections>>
}
#+END_SRC
```

The `<<port-definitions>>`, `<<part-definitions>>`, etc. are noweb references — they'll be replaced with the contents of the named blocks below when tangling.

### 2. Port Definitions

Ports define the interfaces between components. We start with the communication and power interfaces:

```org
#+NAME: port-definitions
#+BEGIN_SRC sysml
// --- Port Definitions ---

port def PowerPort {
    in item powerIn : PowerSupply;
}

port def CmdPort {
    in item command : FlightCommand;
    out item status : FlightStatus;
}

port def PayloadPort {
    inout item payload : Package;
}

port def GPSPort {
    out attribute latitude : Real;
    out attribute longitude : Real;
    out attribute altitude :> ISQ::length;
}
#+END_SRC
```

### 3. Item Definitions

Items are things that flow through ports — signals, data, physical objects:

```org
#+NAME: port-definitions
#+BEGIN_SRC sysml
// --- Item Definitions ---

item def PowerSupply;
item def FlightCommand;
item def FlightStatus;
item def Package {
    attribute weight :> ISQ::mass;
    attribute destination : String;
}
#+END_SRC
```

Note that both this block and the port definitions block above share the same `#+NAME: port-definitions`. Org-babel concatenates blocks with the same noweb-ref name, so they'll be combined when tangling.

### 4. Part Definitions

Now we define the structural components of our drone:

```org
#+NAME: part-definitions
#+BEGIN_SRC sysml
// --- Part Definitions ---

part def Drone {
    attribute maxPayload :> ISQ::mass = 2.5 [kg];
    attribute maxRange :> ISQ::length = 15000 [m];
    attribute batteryCapacity : Real = 5000; // mAh

    port cmdPort : CmdPort;
    port gpsPort : GPSPort;
    port payloadPort : PayloadPort;

    part flightController : FlightController;
    part propulsion : PropulsionSystem;
    part navigation : NavigationModule;
    part battery : Battery;
    part cargo : CargoModule;
}

part def FlightController {
    port cmdPort : ~CmdPort;     // conjugated
    port powerPort : PowerPort;
    attribute firmwareVersion : String;
}

part def PropulsionSystem {
    port powerPort : PowerPort;
    attribute motorCount : Integer = 4;
    attribute maxThrust :> ISQ::force;
}

part def NavigationModule {
    port gpsPort : GPSPort;
    port powerPort : PowerPort;
    attribute accuracy :> ISQ::length = 0.5 [m];
}

part def Battery {
    attribute capacity : Real;  // mAh
    attribute voltage : Real = 22.2;  // V
    attribute chargeLevel : Real;  // 0.0 to 1.0
}

part def CargoModule {
    port payloadPort : PayloadPort;
    attribute maxWeight :> ISQ::mass = 2.5 [kg];
}
#+END_SRC
```

**Design rationale:** We separate propulsion, navigation, and cargo into distinct parts so they can be independently verified and potentially swapped for different mission profiles.

### 5. Requirements

Requirements are first-class model elements in SysML v2. We define them alongside the rationale:

```org
#+NAME: requirements
#+BEGIN_SRC sysml
// --- Requirements ---

requirement def PayloadCapacity {
    doc /* The drone shall carry payloads up to 2.5 kg */
    subject drone : Drone;
    require constraint { drone.maxPayload >= 2.5 [kg] }
}

requirement def RangeRequirement {
    doc /* The drone shall have a minimum range of 15 km */
    subject drone : Drone;
    require constraint { drone.maxRange >= 15000 [m] }
}

requirement def BatteryLife {
    doc /* The battery shall sustain 30 minutes of flight */
    subject battery : Battery;
    require constraint { battery.capacity >= 4000 }
}

requirement def GPSAccuracy {
    doc /* Navigation accuracy shall be within 1 meter */
    subject nav : NavigationModule;
    require constraint { nav.accuracy <= 1.0 [m] }
}
#+END_SRC
```

We can verify these requirements against our definitions right now:

```org
#+BEGIN_SRC sysml :cmd check :results output :tangle no
package DroneDeliverySystem {
    public import ISQ::*;
    <<port-definitions>>
    <<part-definitions>>
    <<requirements>>
}
#+END_SRC
```

The `:tangle no` prevents this validation block from being included in the output file — it's only for inline checking.

### 6. State Machine

The flight controller has a state machine governing its operational modes:

```org
#+NAME: state-machines
#+BEGIN_SRC sysml
// --- State Machines ---

state def FlightStates {
    entry action initial;

    state idle {
        entry action selfCheck;
    }
    state armed {
        entry action calibrateSensors;
    }
    state flying {
        entry action enablePropulsion;
        do action navigate;
        exit action disablePropulsion;
    }
    state returning {
        entry action setReturnCourse;
        do action navigate;
    }
    state landing {
        entry action initLanding;
        do action descend;
        exit action disengageMotors;
    }

    transition initial then idle;

    transition arm_drone
        first idle
        accept ArmCommand
        then armed;

    transition takeoff
        first armed
        accept TakeoffCommand
        then flying;

    transition start_return
        first flying
        accept ReturnCommand
        then returning;

    transition approach_landing
        first returning
        then landing;

    transition touchdown
        first landing
        then idle;
}
#+END_SRC
```

We can simulate this state machine inline:

```org
#+BEGIN_SRC sysml :cmd simulate :simulate-type sm :name FlightStates :events "ArmCommand,TakeoffCommand,ReturnCommand" :results output :tangle no
<<state-machines>>
#+END_SRC
```

Expected output:

```
State Machine: FlightStates
Initial state: idle

  Step 0: idle -- [ArmCommand]--> armed
  Step 1: armed -- [TakeoffCommand]--> flying
  Step 2: flying -- [ReturnCommand]--> returning

Status: deadlocked (3 steps, current: returning)
```

### 7. Action Definitions

The delivery mission is modeled as an action flow:

```org
#+NAME: actions
#+BEGIN_SRC sysml
// --- Actions ---

action def DeliverPackage {
    in item package : Package;

    action preflight : PreflightCheck;
    action takeoff : Takeoff;
    action flyToDestination : FlyToWaypoint;
    action deliver : DropPayload;
    action returnHome : FlyToWaypoint;
    action land : Landing;

    first start then preflight;
    then takeoff;
    then flyToDestination;
    then deliver;
    then returnHome;
    then land;
    then done;
}

action def PreflightCheck;
action def Takeoff;
action def FlyToWaypoint;
action def DropPayload;
action def Landing;
#+END_SRC
```

### 8. Connections

Finally, we wire the internal components together:

```org
#+NAME: connections
#+BEGIN_SRC sysml
// --- Connections ---

part droneInstance : Drone {
    connect flightController.cmdPort to cmdPort;
    connect flightController.powerPort to battery;
    connect propulsion.powerPort to battery;
    connect navigation.gpsPort to gpsPort;
    connect navigation.powerPort to battery;
    connect cargo.payloadPort to payloadPort;

    flow from battery to flightController.powerPort;
    flow from battery to propulsion.powerPort;
    flow from battery to navigation.powerPort;
}
#+END_SRC
```

### 9. Generate a Diagram

We can generate a parts tree diagram directly in the document:

```org
#+BEGIN_SRC sysml :cmd diagram :diagram-type tree :file images/drone-bdd.svg :tangle no
package DroneDeliverySystem {
    <<part-definitions>>
}
#+END_SRC

#+RESULTS:
[[file:images/drone-bdd.svg]]
```

### 10. Parameterized Variants

Using org variables, we can create variant configurations:

```org
#+NAME: drone-variant
#+BEGIN_SRC sysml :var payload="2.5" range="15000" motors="4" :tangle no
part def DroneVariant {
    attribute maxPayload :> ISQ::mass = $payload [kg];
    attribute maxRange :> ISQ::length = $range [m];
    part propulsion : PropulsionSystem {
        attribute motorCount : Integer = $motors;
    }
}
#+END_SRC
```

Call it with different values:

```org
#+CALL: drone-variant(payload="5.0", range="8000", motors="6")
```

## Tangling

To extract the complete model, run:

```
M-x org-babel-tangle
```

Or `C-c C-v t`. This produces `drone-system.sysml` with all noweb references expanded and blocks concatenated in document order.

The resulting file is a valid, standalone SysML v2 model that can be:
- Validated with `sysml check drone-system.sysml`
- Visualized with `sysml diagram -t bdd drone-system.sysml`
- Simulated with `sysml simulate sm drone-system.sysml`
- Exported to FMI with `sysml export interfaces drone-system.sysml`

## Tips

### Org Properties for Project-Wide Settings

Set at the top of your org file to apply to all SysML blocks:

```org
#+PROPERTY: header-args:sysml :tangle model.sysml :noweb yes :mkdirp yes
```

- `:tangle model.sysml` — all blocks tangle to this file
- `:noweb yes` — enable `<<reference>>` expansion everywhere
- `:mkdirp yes` — create output directories if needed

### Multiple Output Files

Different subsystems can tangle to separate files:

```org
#+BEGIN_SRC sysml :tangle subsystems/propulsion.sysml
package Propulsion { ... }
#+END_SRC

#+BEGIN_SRC sysml :tangle subsystems/navigation.sysml
package Navigation { ... }
#+END_SRC
```

### Selective Execution

Use `:tangle no` on blocks that are only for validation or visualization:

```org
#+BEGIN_SRC sysml :cmd check :results output :tangle no
<<full-model>>
#+END_SRC
```

### Exporting to PDF

With Pandoc installed, export the entire document (narrative + results + diagrams) to a formal review document:

```
M-x org-export-dispatch → l (LaTeX/PDF)
```

Or use the sysml2-mode report export for model-specific output:

```
M-x sysml2-report-export  (C-c C-i e)
```

### Keybindings Reference

| Binding | Action |
|---------|--------|
| `C-c C-v t` | Tangle all blocks to files |
| `C-c C-v f` | Tangle current block only |
| `C-c C-c` | Execute block at point |
| `C-c '` | Edit block in sysml2-mode buffer |
| `C-c C-v d` | Demarcate (split) a block |
| `C-c C-v n` | Jump to next src block |
| `C-c C-v p` | Jump to previous src block |

### Header Arguments Reference

| Argument | Values | Description |
|----------|--------|-------------|
| `:tangle` | `filename.sysml` / `no` | Output file for tangling |
| `:noweb` | `yes` / `no` / `tangle` | Enable `<<reference>>` expansion |
| `:cmd` | `check` / `list` / `stats` / `simulate` / `diagram` / `doc` / `show` / `none` | CLI command to run |
| `:diagram-type` | `tree` / `interconnection` / `state-machine` / `action-flow` / `requirement-tree` / `use-case` / `package` | Diagram type |
| `:scope` | element name | Scope for scoped diagrams |
| `:file` | path | Output file for diagrams |
| `:simulate-type` | `list` / `eval` / `sm` / `af` | Simulation subcommand |
| `:name` | element name | Element for simulate/show |
| `:events` | `"evt1,evt2"` | State machine events |
| `:bindings` | `"x=1,y=2"` | Variable bindings for simulation |
| `:var` | `name=value` | Variable for `$name` substitution |
| `:results` | `output` / `file` | How to capture results |
| `:exports` | `code` / `results` / `both` / `none` | What to include in export |
