# SysML v2 with sysml2-mode: A Practical Tutorial

This tutorial walks through building a complete SysML v2 model from scratch
using `sysml2-mode` in Emacs. You'll learn both the SysML v2 textual notation
and the editor features that make working with it productive.

## Prerequisites

- Emacs 29.1+ with `sysml2-mode` installed
- (Recommended) Tree-sitter grammar for enhanced highlighting:
  ```elisp
  (add-to-list 'treesit-language-source-alist
               '(sysml "https://github.com/jackhale98/tree-sitter-sysml"
                       nil "src"))
  M-x treesit-install-language-grammar RET sysml
  ```

## Quick Reference: Key Bindings

| Emacs         | Doom (SPC m)  | Action                        |
|---------------|---------------|-------------------------------|
| `C-c C-n t`   | `SPC m o`     | Toggle outline panel          |
| `C-c C-n o`   | `SPC m n o`   | Imenu (jump to definition)    |
| `M-.`         | `gd`          | Go to definition at point     |
| `C-c C-c c`   | `SPC m c c`   | Insert connection             |
| `C-c C-c f`   | `SPC m c f`   | Insert flow                   |
| `C-c C-c b`   | `SPC m c b`   | Insert binding                |
| `C-c C-c i`   | `SPC m c i`   | Insert interface              |
| `C-c C-c a`   | `SPC m c a`   | Insert allocation             |
| `C-c C-c s`   | `SPC m c s`   | Insert satisfy                |
| `C-c C-d p`   | `SPC m d p`   | Preview diagram at point      |
| `C-c C-d b`   | `SPC m d b`   | Preview diagram (whole buffer)|
| `C-c C-d t`   | `SPC m d t`   | Select diagram type           |
| `C-c C-d e`   | `SPC m d e`   | Export diagram                |

Snippets (type abbreviation then `TAB`):

Definitions: `pd` part def, `ad` action def, `sd` state def,
`ptd` port def, `cd` connection def, `atd` attribute def,
`rd` requirement def, `cnd` constraint def, `ed` enum def,
`fd` flow def, `vd` view def, `vpd` viewpoint def, `ucd` use case def

Usages: `p` part, `a` action, `s` state, `pt` port, `at` attribute,
`c` connection, `r` requirement, `cn` constraint

Relationships: `fl` flow, `ifc` interface, `alloc` allocation,
`bind` binding, `sat` satisfy

Other: `pkg` package, `imp` import, `imps` import star, `doc` doc comment

---

## Step 1: Create a Package

Every SysML v2 model lives inside a **package**. Create a new file called
`drone-system.sysml` and start with:

```sysml
package DroneSystem {
    import ISQ::*;
    import SI::*;
}
```

**What's happening:**
- `package` declares a namespace for all your model elements
- `import ISQ::*` brings in the International System of Quantities (mass,
  length, speed, etc.)
- `import SI::*` brings in SI units (kg, m, m/s, etc.)

> **Editor tip:** After typing `package`, completion will suggest keywords.
> Press `TAB` to accept, or keep typing. The outline panel (`C-c C-n t` /
> `SPC m o`) will immediately show your package.

---

## Step 2: Define Attributes

**Attribute definitions** describe reusable value types. They are the
fundamental data types of your model.

```sysml
package DroneSystem {
    import ISQ::*;
    import SI::*;

    // Custom attribute types
    attribute def Voltage :> ISQ::ElectricPotentialValue;
    attribute def Current :> ISQ::ElectricCurrentValue;
    attribute def Altitude :> ISQ::LengthValue;
    attribute def BatteryCapacity;
    attribute def GPSCoordinate;
}
```

**SysML v2 concepts:**
- `:>` means **specializes** — `Voltage` is a more specific kind of
  `ElectricPotentialValue`
- Attribute definitions without `:>` are standalone types
- `//` starts a line comment; `/* ... */` is a block comment

> **Editor tip:** Type `atd` then `TAB` to expand the attribute def snippet.
> After `:>`, completion suggests known definitions and standard library types.

---

## Step 3: Define Enumerations

**Enumerations** define a fixed set of named values.

```sysml
    // Flight modes
    enum def FlightMode {
        enum hover;
        enum cruise;
        enum landing;
        enum emergency;
    }

    // Drone status
    enum def DroneStatus {
        enum idle;
        enum preflight;
        enum airborne;
        enum returning;
        enum fault;
    }
```

> **Editor tip:** Type `ed` then `TAB` for the enum def snippet. Each `enum`
> member is a variant.

---

## Step 4: Define Ports

**Ports** are the interfaces through which parts communicate. They define
what flows in and out of a component.

```sysml
    // Communication interface
    port def CommandPort {
        in item command : ScalarValues::String;
        out item telemetry : ScalarValues::String;
    }

    // Electrical power interface
    port def PowerPort {
        in attribute voltage : Voltage;
        in attribute current : Current;
    }

    // GPS data interface
    port def GPSPort {
        out attribute position : GPSCoordinate;
        out attribute altitude : Altitude;
    }
```

**SysML v2 concepts:**
- `in` / `out` specify the direction of data flow
- `item` is for discrete things that flow (messages, signals, physical items)
- `attribute` is for continuous values (measurements, settings)
- Ports are **reusable** — define them once, use them on many parts

> **Editor tip:** Type `ptd` then `TAB` for the port def snippet. The `in`
> and `out` keywords get modifier highlighting.

---

## Step 5: Define Parts

**Part definitions** are the core building blocks — they describe the
structure of your system's components.

```sysml
    // Battery
    part def Battery {
        attribute capacity : BatteryCapacity;
        attribute voltage : Voltage;
        attribute chargeLevel : ScalarValues::Real;

        port powerOut : PowerPort;
    }

    // Motor (there will be 4)
    part def Motor {
        attribute maxRPM : ScalarValues::Integer;
        attribute efficiency : ScalarValues::Real;

        port powerIn : PowerPort;
    }

    // Flight controller — the "brain"
    part def FlightController {
        attribute currentMode : FlightMode;
        attribute firmwareVersion : ScalarValues::String;

        port cmdPort : CommandPort;
        port gpsPort : GPSPort;
    }

    // GPS module
    part def GPSModule {
        attribute accuracy : ISQ::LengthValue;

        port gpsOut : GPSPort;
    }

    // Camera payload
    part def Camera {
        attribute resolution : ScalarValues::Integer;
        attribute isRecording : ScalarValues::Boolean;
    }

    // Frame / airframe
    part def Frame {
        attribute mass : ISQ::MassValue;
        attribute material : ScalarValues::String;
    }
```

**SysML v2 concepts:**
- `attribute` usages inside a part are its properties/data
- `port` usages are its communication interfaces
- Parts are **definitions** (templates) — they aren't instantiated yet

> **Editor tip:** Type `pd` then `TAB` for the part def snippet. Place your
> cursor on `PowerPort` and press `gd` (Doom) or `M-.` to jump to its
> definition.

---

## Step 6: Compose the System

Now assemble the drone by creating **part usages** inside a system-level
part definition. Usages are instances of definitions.

```sysml
    // The complete drone system
    part def Drone {
        attribute serialNumber : ScalarValues::String;
        attribute status : DroneStatus;
        attribute totalMass : ISQ::MassValue;

        // Structural decomposition
        part battery : Battery;
        part motor : Motor[4];          // 4 motors
        part flightController : FlightController;
        part gps : GPSModule;
        part camera : Camera;
        part frame : Frame;
    }
```

**SysML v2 concepts:**
- `part motor : Motor[4]` creates 4 instances of `Motor` — the `[4]` is a
  **multiplicity**
- The parts inside `Drone` define its **structural decomposition** — what
  it's made of
- This is a **definition**, not an individual. We'll create individuals later.

> **Editor tip:** Open the outline panel (`SPC m o`) to see the full
> hierarchy. All definitions are listed with their types.

---

## Step 7: Connect Parts

Parts need to be connected to show how they relate. Use the smart connection
commands to insert connections interactively.

### Interactive connection insertion

Place your cursor inside the `Drone` definition body and run `SPC m c c`
(Doom) or `C-c C-c c`. The editor will:

1. Ask you to **name** the connection (free text — type a new name)
2. Ask for a **connection type** (pick from definitions, or press RET to skip)
3. Show you all **connectable elements** in the buffer with type annotations
   — pick the source
4. Show the same list — pick the target

This generates valid SysML v2 syntax like:

```sysml
        // Inside Drone definition, after the part usages:

        // Power distribution: battery powers each motor
        connection powerLink
            connect battery.powerOut to motor.powerIn;
```

### Flows

Use `SPC m c f` / `C-c C-c f` to insert flow connections. Flows show what
**items** move between parts:

```sysml
        // GPS data flows to flight controller
        flow gpsData of GPSCoordinate
            from gps.gpsOut to flightController.gpsPort;
```

### Interfaces

Use `SPC m c i` / `C-c C-c i` for interface usages:

```sysml
        // Ground station communication
        interface groundLink : GroundStationInterface
            connect flightController.cmdPort to groundStation.cmdPort;
```

### Bindings

Use `SPC m c b` / `C-c C-c b` for binding connectors (value equality):

```sysml
        bind battery.voltage = motor.powerIn.voltage;
```

> **Editor tip:** The completion menu shows annotations like
> `<port : PowerPort>` and `<path>` so you can tell what each element is.
> Dot-paths like `battery.powerOut` are automatically discovered from your
> model.

---

## Step 8: Define Behavior with Actions

**Action definitions** describe what the system *does*. They can have
inputs, outputs, and sub-actions with control flow.

```sysml
    // Individual actions
    action def PerformPreflight {
        in drone : Drone;
        out result : ScalarValues::Boolean;
    }

    action def Takeoff {
        in targetAltitude : Altitude;
        out reachedAltitude : Altitude;
    }

    action def Navigate {
        in waypoint : GPSCoordinate;
        out currentPosition : GPSCoordinate;
    }

    action def CaptureImage {
        in camera : Camera;
    }

    action def Land {
        out touchdownSpeed : ISQ::SpeedValue;
    }

    // Composite mission action
    action def SurveyMission {
        in drone : Drone;
        in surveyArea : GPSCoordinate[2];  // start and end coordinates

        action preflight : PerformPreflight;
        action takeoff : Takeoff;
        action survey : Navigate;
        action capture : CaptureImage;
        action rtb : Navigate;     // return to base
        action land : Land;

        // Control flow: sequence of actions
        first preflight then takeoff;
        first takeoff then survey;
        first survey then capture;
        first capture then rtb;
        first rtb then land;
    }
```

**SysML v2 concepts:**
- `first ... then ...` defines **control flow** (sequencing)
- Actions can have `in` and `out` parameters
- Composite actions contain sub-actions (decomposition)
- `[2]` on `surveyArea` means exactly 2 coordinates

> **Editor tip:** Type `ad` then `TAB` for the action def snippet. The
> `first` and `then` keywords are highlighted as behavioral keywords.

---

## Step 9: Define States

**State definitions** model the lifecycle of a component with states and
transitions.

```sysml
    state def DroneLifecycle {
        entry; then idle;

        state idle;
        state preflight;
        state armed;
        state flying {
            // Nested states
            state hovering;
            state cruising;
            state maneuvering;
        }
        state returning;
        state landed;
        state emergency;

        // Transitions
        transition idle_to_preflight
            first idle
            accept startMission
            then preflight;

        transition preflight_to_armed
            first preflight
            accept preflightComplete
            then armed;

        transition armed_to_flying
            first armed
            accept takeoffCmd
            then flying;

        transition flying_to_returning
            first flying
            accept returnCmd
            then returning;

        transition returning_to_landed
            first returning
            accept touchdownDetected
            then landed;

        transition landed_to_idle
            first landed
            accept missionComplete
            then idle;

        // Emergency from any flying state
        transition to_emergency
            first flying
            accept faultDetected
            then emergency;
    }
```

**SysML v2 concepts:**
- `entry; then idle;` sets the initial state
- `accept` specifies the **trigger** (event) for a transition
- States can be **nested** (`flying` contains `hovering`, `cruising`, etc.)
- `first ... then ...` in transitions means "from state ... go to state ..."

> **Editor tip:** Type `sd` then `TAB` for the state def snippet. Use the
> diagram preview (`SPC m d p`) with diagram type set to "state" to see a
> visual state machine.

---

## Step 10: Define Requirements

**Requirements** capture what the system must do or be. They can have
formal constraints.

```sysml
    requirement def MaxWeightReq {
        doc /* The total drone mass including payload shall not
               exceed 2.5 kg to comply with FAA Part 107. */

        subject drone : Drone;

        require constraint {
            drone.totalMass <= 2.5 [kg]
        }
    }

    requirement def MinFlightTimeReq {
        doc /* The drone shall sustain flight for at least
               30 minutes on a full charge. */

        subject drone : Drone;
        attribute minMinutes : ScalarValues::Real = 30;
    }

    requirement def MaxAltitudeReq {
        doc /* The drone shall not exceed 120 meters AGL
               per regulatory requirements. */

        subject drone : Drone;

        require constraint {
            drone.gps.gpsOut.altitude <= 120 [m]
        }
    }

    requirement def GPSAccuracyReq {
        doc /* GPS horizontal accuracy shall be within 2 meters. */

        subject gps : GPSModule;

        require constraint {
            gps.accuracy <= 2 [m]
        }
    }
```

**SysML v2 concepts:**
- `doc /* ... */` is a **documentation comment** — structured prose
- `subject` names the element being constrained
- `require constraint { ... }` contains a formal Boolean expression
- `<=` is a comparison operator; `[kg]` and `[m]` are unit annotations

> **Editor tip:** Type `rd` then `TAB` for the requirement def snippet.
> Preview requirements as a diagram with `SPC m d t` → "requirement".

---

## Step 11: Satisfy Requirements

Link requirements to the parts that fulfill them using `satisfy`.

```sysml
    // Traceability: which parts satisfy which requirements
    satisfy requirement MaxWeightReq by Drone;
    satisfy requirement MinFlightTimeReq by Drone;
    satisfy requirement MaxAltitudeReq by Drone;
    satisfy requirement GPSAccuracyReq by GPSModule;
```

> **Editor tip:** Use `SPC m c s` / `C-c C-c s` to insert satisfy
> statements interactively. The requirement prompt filters to show only
> requirement and constraint usages. The "by" prompt shows all parts and
> definitions.

---

## Step 12: Define Allocations

**Allocations** trace behavioral elements to structural elements —
"this action is performed by this part."

```sysml
    // Allocate actions to parts
    allocation def ActionAllocation;

    allocation navAlloc
        allocate Navigate to FlightController;

    allocation captureAlloc
        allocate CaptureImage to Camera;
```

> **Editor tip:** Use `SPC m c a` / `C-c C-c a` to insert allocations
> interactively. Type `alloc` then `TAB` for the snippet.

---

## Step 13: Specialization and Variation

SysML v2 supports **specialization** (inheritance) and **variation**
(product lines).

```sysml
    // Specialized drone variants
    part def SurveyDrone :> Drone {
        doc /* Drone optimized for aerial survey missions
               with enhanced GPS and camera. */

        // Redefine camera with higher resolution
        part redefines camera : Camera {
            attribute redefines resolution = 48000000;  // 48 MP
        }

        // Add LIDAR
        part lidar : Camera;
    }

    part def DeliveryDrone :> Drone {
        doc /* Drone designed for package delivery. */

        // Additional payload bay
        part payloadBay {
            attribute maxPayload : ISQ::MassValue;
        }
    }

    // Variation point
    variation part def DroneVariant :> Drone {
        variant part survey : SurveyDrone;
        variant part delivery : DeliveryDrone;
    }
```

**SysML v2 concepts:**
- `:>` on a part def means **specialization** (SurveyDrone is a kind of Drone)
- `redefines` replaces an inherited feature with a new version
- `variation` / `variant` define a product-line choice point

---

## Step 14: Create Individual Instances

**Individuals** are specific instances of definitions — actual drones,
not the template.

```sysml
    // A specific drone
    individual part def DroneUnit1 :> SurveyDrone {
        attribute redefines serialNumber = "DRN-2026-0042";
    }
```

---

## Step 15: Use Cases

**Use cases** describe how actors interact with the system.

```sysml
    use case def PerformSurvey {
        doc /* An operator deploys a survey drone to map a
               designated area and returns with imagery. */

        subject drone : Drone;
        actor operator : ScalarValues::String;
        actor airspace : ScalarValues::String;

        include use case preflight;
        include use case executeSurvey;
        include use case processData;
    }
```

> **Editor tip:** Preview use case diagrams with `SPC m d t` → "use-case",
> then `SPC m d p`.

---

## Step 16: Views

**Views** filter and present parts of the model for different stakeholders.

```sysml
    // Structural overview for engineers
    view def StructuralOverview {
        filter @SysML::PartUsage;
    }

    // Requirements view for certification
    view def CertificationView {
        filter @SysML::RequirementUsage;
    }
```

---

## Step 17: Generate Diagrams

With your model complete, generate visual diagrams using PlantUML.

1. **Set diagram type:** `SPC m d t` / `C-c C-d t` — choose from:
   - `tree` — Block Definition Diagram (BDD): shows part hierarchy
   - `interconnection` — Internal Block Diagram (IBD): shows connections
   - `state` — State Machine Diagram
   - `action` — Action Flow Diagram
   - `requirement` — Requirement Tree
   - `use-case` — Use Case Diagram
   - `package` — Package Diagram

2. **Preview:** `SPC m d p` / `C-c C-d p` — renders the definition at point

3. **Preview buffer:** `SPC m d b` / `C-c C-d b` — renders the whole file

4. **Export:** `SPC m d e` / `C-c C-d e` — save as SVG/PNG/PDF

> **Note:** Diagram generation requires PlantUML. Install it and set
> `sysml2-plantuml-executable-path` or `sysml2-plantuml-jar-path`.

---

## Step 18: Navigation and Exploration

### Outline panel

Toggle with `SPC m o` / `C-c C-n t`. Shows all definitions in a side
panel. Press `RET` to jump, `o` to jump and close, `q` to close,
`g` to refresh (`gr` in evil normal state).

### Go to definition

Place cursor on any type name and press `gd` (Doom) or `M-.` to jump to
its definition. Press `C-o` (Doom) or `C-x C-SPC` to return.

### Imenu

`SPC m n o` / `C-c C-n o` opens a searchable list of all definitions
grouped by category (Parts, Actions, States, Requirements, etc.).

### Which-function

Enable `which-function-mode` to always see the enclosing definition name
in the modeline.

### Tree-sitter inspection

If using tree-sitter mode (modeline shows `SysML2[TS]`), Emacs has
built-in tree inspection commands:
- `M-x treesit-inspect-mode` — shows the parse tree node at cursor
  in the modeline
- `M-x treesit-explore-mode` — opens the full parse tree explorer
  (useful for grammar debugging, not general navigation)

> **Doom tip:** You can bind these to `SPC m t i` and `SPC m t e` in
> your `config.el` — see the Doom setup example in `sysml2-mode.el`.

---

## Complete File

Here is the complete `drone-system.sysml` file with all elements:

```sysml
package DroneSystem {
    import ISQ::*;
    import SI::*;

    // --- Attribute Definitions ---
    attribute def Voltage :> ISQ::ElectricPotentialValue;
    attribute def Current :> ISQ::ElectricCurrentValue;
    attribute def Altitude :> ISQ::LengthValue;
    attribute def BatteryCapacity;
    attribute def GPSCoordinate;

    // --- Enumerations ---
    enum def FlightMode {
        enum hover;
        enum cruise;
        enum landing;
        enum emergency;
    }

    enum def DroneStatus {
        enum idle;
        enum preflight;
        enum airborne;
        enum returning;
        enum fault;
    }

    // --- Port Definitions ---
    port def CommandPort {
        in item command : ScalarValues::String;
        out item telemetry : ScalarValues::String;
    }

    port def PowerPort {
        in attribute voltage : Voltage;
        in attribute current : Current;
    }

    port def GPSPort {
        out attribute position : GPSCoordinate;
        out attribute altitude : Altitude;
    }

    // --- Part Definitions ---
    part def Battery {
        attribute capacity : BatteryCapacity;
        attribute voltage : Voltage;
        attribute chargeLevel : ScalarValues::Real;
        port powerOut : PowerPort;
    }

    part def Motor {
        attribute maxRPM : ScalarValues::Integer;
        attribute efficiency : ScalarValues::Real;
        port powerIn : PowerPort;
    }

    part def FlightController {
        attribute currentMode : FlightMode;
        attribute firmwareVersion : ScalarValues::String;
        port cmdPort : CommandPort;
        port gpsPort : GPSPort;
    }

    part def GPSModule {
        attribute accuracy : ISQ::LengthValue;
        port gpsOut : GPSPort;
    }

    part def Camera {
        attribute resolution : ScalarValues::Integer;
        attribute isRecording : ScalarValues::Boolean;
    }

    part def Frame {
        attribute mass : ISQ::MassValue;
        attribute material : ScalarValues::String;
    }

    // --- System Composition ---
    part def Drone {
        attribute serialNumber : ScalarValues::String;
        attribute status : DroneStatus;
        attribute totalMass : ISQ::MassValue;

        part battery : Battery;
        part motor : Motor[4];
        part flightController : FlightController;
        part gps : GPSModule;
        part camera : Camera;
        part frame : Frame;

        // Connections
        connection powerLink
            connect battery.powerOut to motor.powerIn;

        flow gpsData of GPSCoordinate
            from gps.gpsOut to flightController.gpsPort;
    }

    // --- Actions ---
    action def PerformPreflight {
        in drone : Drone;
        out result : ScalarValues::Boolean;
    }

    action def Takeoff {
        in targetAltitude : Altitude;
        out reachedAltitude : Altitude;
    }

    action def Navigate {
        in waypoint : GPSCoordinate;
        out currentPosition : GPSCoordinate;
    }

    action def CaptureImage {
        in camera : Camera;
    }

    action def Land {
        out touchdownSpeed : ISQ::SpeedValue;
    }

    action def SurveyMission {
        in drone : Drone;
        in surveyArea : GPSCoordinate[2];

        action preflight : PerformPreflight;
        action takeoff : Takeoff;
        action survey : Navigate;
        action capture : CaptureImage;
        action rtb : Navigate;
        action land : Land;

        first preflight then takeoff;
        first takeoff then survey;
        first survey then capture;
        first capture then rtb;
        first rtb then land;
    }

    // --- States ---
    state def DroneLifecycle {
        entry; then idle;

        state idle;
        state preflight;
        state armed;
        state flying {
            state hovering;
            state cruising;
            state maneuvering;
        }
        state returning;
        state landed;
        state emergency;

        transition idle_to_preflight
            first idle accept startMission then preflight;
        transition preflight_to_armed
            first preflight accept preflightComplete then armed;
        transition armed_to_flying
            first armed accept takeoffCmd then flying;
        transition flying_to_returning
            first flying accept returnCmd then returning;
        transition returning_to_landed
            first returning accept touchdownDetected then landed;
        transition landed_to_idle
            first landed accept missionComplete then idle;
        transition to_emergency
            first flying accept faultDetected then emergency;
    }

    // --- Requirements ---
    requirement def MaxWeightReq {
        doc /* The total drone mass including payload shall not
               exceed 2.5 kg to comply with FAA Part 107. */
        subject drone : Drone;
        require constraint { drone.totalMass <= 2.5 [kg] }
    }

    requirement def MinFlightTimeReq {
        doc /* The drone shall sustain flight for at least
               30 minutes on a full charge. */
        subject drone : Drone;
    }

    requirement def MaxAltitudeReq {
        doc /* The drone shall not exceed 120 meters AGL. */
        subject drone : Drone;
        require constraint { drone.gps.gpsOut.altitude <= 120 [m] }
    }

    requirement def GPSAccuracyReq {
        doc /* GPS horizontal accuracy shall be within 2 meters. */
        subject gps : GPSModule;
        require constraint { gps.accuracy <= 2 [m] }
    }

    // --- Satisfy ---
    satisfy requirement MaxWeightReq by Drone;
    satisfy requirement MinFlightTimeReq by Drone;
    satisfy requirement MaxAltitudeReq by Drone;
    satisfy requirement GPSAccuracyReq by GPSModule;

    // --- Allocations ---
    allocation navAlloc
        allocate Navigate to FlightController;
    allocation captureAlloc
        allocate CaptureImage to Camera;

    // --- Specialization ---
    part def SurveyDrone :> Drone {
        part redefines camera : Camera {
            attribute redefines resolution = 48000000;
        }
        part lidar : Camera;
    }

    part def DeliveryDrone :> Drone {
        part payloadBay {
            attribute maxPayload : ISQ::MassValue;
        }
    }

    // --- Use Case ---
    use case def PerformSurvey {
        subject drone : Drone;
        actor operator : ScalarValues::String;
        include use case preflight;
        include use case executeSurvey;
    }

    // --- Views ---
    view def StructuralOverview {
        filter @SysML::PartUsage;
    }

    view def CertificationView {
        filter @SysML::RequirementUsage;
    }
}
```

---

## SysML v2 Concept Summary

| Concept              | Keyword            | Purpose                              |
|----------------------|--------------------|--------------------------------------|
| Package              | `package`          | Namespace / container                |
| Import               | `import`           | Bring in external definitions        |
| Attribute def        | `attribute def`    | Value type                           |
| Enumeration          | `enum def`         | Fixed set of values                  |
| Port def             | `port def`         | Communication interface              |
| Part def             | `part def`         | Structural component                 |
| Part usage           | `part name : Type` | Instance of a part def               |
| Connection           | `connection`       | Structural link between parts        |
| Flow                 | `flow ... of`      | Item/data flowing between ports      |
| Binding              | `bind`             | Value equality constraint            |
| Interface            | `interface`        | Typed connection interface           |
| Action def           | `action def`       | Behavior / function                  |
| State def            | `state def`        | Lifecycle / state machine            |
| Requirement def      | `requirement def`  | What the system shall do/be          |
| Constraint def       | `constraint def`   | Boolean condition                    |
| Use case def         | `use case def`     | Actor-system interaction             |
| Allocation           | `allocation`       | Trace behavior → structure           |
| Satisfy              | `satisfy`          | Trace requirement → implementation   |
| Specialization       | `:>`               | Inheritance / "is a kind of"         |
| Redefinition         | `redefines`        | Override inherited feature           |
| Multiplicity         | `[n]` or `[n..m]`  | How many instances                   |
| Variation            | `variation`        | Product line choice point            |
| Individual           | `individual`       | Specific named instance              |
| View def             | `view def`         | Filtered model presentation          |
| Abstract             | `abstract`         | Cannot be instantiated directly      |
| Visibility           | `public`/`private` | Access control                       |
| Doc comment          | `doc /* ... */`     | Structured documentation             |
| Metadata             | `#AnnotationName`  | Model annotations                    |

---

## Further Reading

- [OMG SysML v2 Specification](https://www.omg.org/spec/SysML/2.0)
- [tree-sitter-sysml grammar](https://github.com/jackhale98/tree-sitter-sysml)
- [sysml2-mode source](https://github.com/jackhale98/sysml2-mode)
