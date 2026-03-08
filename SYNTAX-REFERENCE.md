# SysML v2 Syntax Reference and Best Practices

SysML v2 is the next-generation systems modeling language from OMG, providing a
precise textual notation for specifying system structure, behavior, requirements,
and analysis. This document is a concise reference for the SysML v2 textual
notation as supported by `sysml2-mode` for Emacs, targeting SysML v2.0 / KerML 1.0.

## Table of Contents

- [Packages and Imports](#packages-and-imports)
- [Definitions vs Usages](#definitions-vs-usages)
- [Parts and Composition](#parts-and-composition)
- [Attributes and Enumerations](#attributes-and-enumerations)
- [Items](#items)
- [Ports and Interfaces](#ports-and-interfaces)
- [Connections and Flows](#connections-and-flows)
- [Actions and Behavior](#actions-and-behavior)
- [State Machines](#state-machines)
- [Requirements](#requirements)
- [Constraints and Calculations](#constraints-and-calculations)
- [Use Cases](#use-cases)
- [Verification](#verification)
- [Analysis](#analysis)
- [Views and Viewpoints](#views-and-viewpoints)
- [Comments and Documentation](#comments-and-documentation)
- [Common Patterns](#common-patterns)
- [Naming Conventions](#naming-conventions)
- [Quick Reference Table](#quick-reference-table)

## Packages and Imports

Packages are the top-level organizational unit. Every `.sysml` file typically
contains one root package. Packages nest to form namespace hierarchies.

```sysml
package VehicleModel {
    package Definitions {
        part def Engine;
    }
    package Usages {
        import Definitions::*;
    }
}
```

Import syntax:

```sysml
import ISQ::*;                         // wildcard -- all public members
import SI::kg;                         // single named element
import Definitions::**;               // recursive -- all nested members
public import ScalarValues::*;         // re-export to downstream importers
private import Definitions::*;        // private -- not visible outside
```

Key standard library packages:

```sysml
import ISQ::*;                         // International System of Quantities
import SI::*;                          // SI units (kg, m, s, N, W, ...)
import ScalarValues::*;                // Boolean, String, Integer, Real, ...
import USCustomaryUnits::*;            // lb, ft, in, ...
```

**Best practice:** One package per file, named to match the file. Separate
definitions from usages in sub-packages for reuse.

## Definitions vs Usages

SysML v2 distinguishes *definitions* (reusable types) from *usages* (instances
of those types). This is the most fundamental concept in the language.

| Concept     | Definition keyword | Usage keyword |
|-------------|-------------------|---------------|
| Part        | `part def`        | `part`        |
| Port        | `port def`        | `port`        |
| Action      | `action def`      | `action`      |
| State       | `state def`       | `state`       |
| Attribute   | `attribute def`   | `attribute`   |
| Item        | `item def`        | `item`        |
| Requirement | `requirement def` | `requirement` |
| Constraint  | `constraint def`  | `constraint`  |
| Connection  | `connection def`  | `connection`  |
| Interface   | `interface def`   | `interface`   |
| Enum        | `enum def`        | `enum`        |
| Calc        | `calc def`        | `calc`        |
| Flow        | `flow def`        | `flow`        |
| Allocation  | `allocation def`  | `allocation`  |
| View        | `view def`        | `view`        |
| Viewpoint   | `viewpoint def`   | `viewpoint`   |
| Use case    | `use case def`    | `use case`    |
| Analysis    | `analysis def`    | `analysis`    |
| Verification| `verification def`| `verification`|

```sysml
part def Engine {               // definition -- reusable type
    attribute displacement : Real;
}
part myEngine : Engine;         // usage -- typed by Engine
```

**Best practice:** Define types before using them. Keep definitions in dedicated
packages so they can be imported independently.

## Parts and Composition

Parts are the primary structural element. Nesting creates composition.

```sysml
part def Chassis {
    attribute mass : ISQ::MassValue;
}
part def Vehicle {
    part chassis : Chassis;             // composed part
    part wheel : Wheel[4];              // multiplicity
}
```

Specialization with `:>` creates subtypes. Use `abstract` to prevent direct instantiation:

```sysml
abstract part def PowerSource {
    attribute maxPower : Real;
}
part def Engine :> PowerSource { }      // concrete specialization
part def FrontAxle :> Axle {
    attribute steeringAngle : Real;
}
```

Multiplicity specifies cardinality:

```sysml
part wheel : Wheel[4];                 // exactly 4
part sensor : Sensor[1..3];            // 1 to 3
part option : Option[0..*];            // zero or more
part lugNut : LugNut[*];              // unbounded
part frontWheel : Wheel[2] ordered;    // ordered collection
```

Redefines and subsets refine inherited features:

```sysml
part vehicle1 : Vehicle {
    attribute mass redefines Vehicle::mass = 1750 [kg];
}
part frontWheel_1 subsets frontWheel = frontWheel#(1);
```

**Best practice:** Design composition top-down. Use specialization (`:>`) for
type variation, not deep nesting.

## Attributes and Enumerations

```sysml
attribute def MassValue :> ISQ::MassValue;

part def Vehicle {
    attribute mass : MassValue;
    attribute topSpeed :> ISQ::speed;
    attribute isAutomatic : Boolean;
}

// Attributes with values and units
attribute mass redefines Vehicle::mass = 1750 [kg];
attribute cylinderDiameter : DiameterChoices = 80 [mm];
```

Enumerations define fixed value sets:

```sysml
enum def FuelType {
    enum gasoline;
    enum diesel;
    enum electric;
}
enum def Colors { black; grey; red; }
enum def DiameterChoices :> ISQ::LengthValue {
    enum = 60 [mm];
    enum = 80 [mm];
    enum = 100 [mm];
}
```

**Best practice:** Use enums for fixed value sets. Enum defs can specialize
quantity types to constrain valid numeric values.

## Items

Items represent things that flow between parts — commands, signals, data,
physical substances. Unlike parts, items are not composed into a structural
hierarchy; they model what is exchanged through ports, flows, and actions.

```sysml
item def Fuel {
    attribute fuelMass :> ISQ::mass;
}
item def PwrCmd {
    attribute throttleLevel : Real;
}
item def FuelCmd :> PwrCmd;          // specialization
item def SensedSpeed {
    attribute speed :> ISQ::speed;
}
```

Items are used in port definitions to declare what flows in or out:

```sysml
port def FuelPort { out item fuel : Fuel; }
port def ControlPort { in item fuelCmd : FuelCmd; }
```

Items also model signals and commands. Specialization (`:>`) creates signal
hierarchies:

```sysml
item def Cmd;
item def DriverCmd;
item def IgnitionCmd :> DriverCmd {
    attribute ignitionOnOff : IgnitionOnOff;
}
item def EngineStatus;
```

Use `ref item` for a reference to an item (not an owned copy):

```sysml
ref item fuel : Fuel { attribute fuelMass = 0 [kg]; }
```

**Best practice:** Define items in a dedicated `ItemDefinitions` or
`SignalDefinitions` package. Use specialization to create command/signal
hierarchies. Items are the "what" in flows — define them before port defs.

## Ports and Interfaces

Ports define interaction points on parts. The `~` operator conjugates a port,
reversing all `in`/`out` directions.

```sysml
port def FuelPort { out item fuel : Fuel; }
port def ElectricalPowerPort { in item electricPower : Real; }
port def VehicleToRoadPort {
    port wheelToRoadPort : WheelToRoadPort[2];   // nested ports
}

part def FuelTank { port fuelOut : FuelPort; }           // fuel flows OUT
part def Engine { port fuelIn : ~FuelPort; }             // conjugated: IN
```

Interfaces define typed contracts between port ends:

```sysml
interface def FuelInterface {
    end fuelOutPort : FuelPort;
    end fuelInPort : ~FuelPort;
    flow of Fuel from fuelOutPort.fuel to fuelInPort.fuel;
}
```

**Best practice:** Define port types before parts. Use conjugation (`~`)
consistently so `out` matches `in` on the connected side.

## Connections and Flows

```sysml
part def VehicleSystem {
    part engine : Engine;
    part transmission : Transmission;
    connection engineToTrans : EngineConnection    // named, typed
        connect engine to transmission;
    connect engine.driveOut to transmission.driveIn;  // dot-path notation
}
// Interface usage (typed connection)
interface : EngineToTransmissionInterface
    connect engine.drivePwrPort to transmission.clutchPort;
```

Flows specify what moves; bindings equate features; allocations map logical
to physical:

```sysml
flow of Fuel from fuelTank.fuelOut to engine.fuelIn;
bind fuelCmdPort = engine.fuelCmdPort;
allocate generateTorque to engine;
```

**Best practice:** Name connections explicitly for significant architectural
links. Use typed connections (via `interface def`) for contracts with
constraints or flows.

## Actions and Behavior

Actions model behavior. Use `first`/`then` for sequencing.

```sysml
action def StartEngine {
    in ignitionSignal : Boolean;
    out engineRunning : Boolean;
}
action def Drive {
    action start : StartEngine;
    action accelerate : Accelerate;
    action brake : Brake;
    first start then accelerate;
}
```

Fork/join for parallel, decide/merge for conditionals:

```sysml
// Parallel                            // Conditional
first start then fork;                 first check then decide;
fork then prepareA;                    decide if check.result then pathA;
fork then prepareB;                    decide if not check.result then pathB;
prepareA then join;                    pathA then merge;
prepareB then join;                    pathB then merge;
join then assemble;
```

Send, accept, and perform:

```sysml
do send new StartSignal() to controller;
accept ignitionCmd : IgnitionCmd via ignitionCmdPort;

part def Vehicle {
    perform action providePower;       // part executes action
}
```

**Best practice:** Decompose complex behavior into small, typed action defs.
Name actions by what they accomplish.

## State Machines

State machines model lifecycle behavior with states and transitions.

```sysml
state def EngineStates {
    entry; then off;                    // initial transition
    state off;
    state starting;
    state running;

    transition off_to_starting
        first off
        accept startCmd
        then starting;

    transition starting_to_running
        first starting
        then running;
}
```

Transition anatomy -- up to five clauses:

```sysml
transition off_To_starting
    first off                                          // source
    accept ignitionCmd : IgnitionCmd via ignitionCmdPort // trigger
        if ignitionCmd.ignitionOnOff == IgnitionOnOff::on  // guard
           and brakePedalDepressed
    do send new StartSignal() to controller            // effect
    then starting;                                     // target
```

Entry, exit, and do actions bind behavior to state lifecycle:

```sysml
state on {
    entry performSelfTest;
    do providePower;
    exit applyParkingBrake;
    constraint { electricalPower <= 500 [W] }
}
```

Use `exhibit state` to attach a state machine to a part, with `parallel` for
orthogonal regions:

```sysml
part def Vehicle {
    exhibit state vehicleStates parallel {
        state operatingStates { state off; state on; }
        state healthStates { state normal; state degraded; }
    }
}
```

Timed and conditional triggers:

```sysml
accept at maintenanceTime;                          // time trigger
accept when senseTemperature.temp > Tmax;           // change trigger
```

**Best practice:** Name states as nouns/adjectives (`off`, `running`,
`degraded`). Name transitions as `source_to_target`.

## Requirements

Requirements capture what the system must do, with formal subjects and
constraints.

```sysml
requirement def MassRequirement {
    doc /* The actual mass shall be less than the required mass. */
    attribute massRequired :> ISQ::mass;
    attribute massActual :> ISQ::mass;
    require constraint { massActual <= massRequired }
}

requirement def TopSpeedReq {
    doc /* The vehicle shall achieve at least 180 km/h. */
    subject vehicle : Vehicle;
    require constraint { vehicle.topSpeed >= 180 [km/h] }
}
```

Requirement IDs use short names in angle brackets:

```sysml
requirement def <'REQ-001'> MassRequirement {
    doc /* Vehicle mass shall not exceed 2000 kg. */
}
```

Satisfy and verify create traceability links:

```sysml
satisfy requirement vehicleSpecification by vehicle_b {
    requirement vehicleMassRequirement :>> vehicleMassRequirement {
        attribute redefines massActual = vehicle_b.mass;
    }
}
verify vehicleSpecification.vehicleMassRequirement {
    redefines massActual = weighVehicle.massMeasured;
}
```

Derivation connects a derived requirement to its original source using a
`#derivation connection` with `#original` and `#derive` ends:

```sysml
// engine mass requirement is derived from the vehicle mass requirement
#derivation connection {
    end #original ::> vehicleSpecification.vehicleMassRequirement;
    end #derive ::> engineSpecification.engineMassRequirement;
}
```

Refinement maps a design element to a more detailed or variant element using
`#refinement dependency`:

```sysml
#refinement dependency engine4Cyl
    to VehicleConfiguration_b::PartsTree::vehicle_b::engine;
```

Assert constraints inline:

```sysml
assert constraint fuelConstraint { fuel.fuelMass <= fuelMassMax }
```

**Best practice:** Give every requirement a short-name ID (`<'REQ-nnn'>`) for
traceability. Close the loop: define, derive, satisfy, verify.

## Constraints and Calculations

```sysml
constraint def MassConstraint {
    in massActual : MassValue;
    in massLimit : MassValue;
    massActual <= massLimit;
}
```

Inline constraints appear in states, interfaces, and parts:

```sysml
constraint { lugNutPort.threadDia == shankPort.threadDia }
```

Calculations return computed values:

```sysml
calc def KineticEnergy {
    in mass : ISQ::MassValue;
    in velocity : ISQ::SpeedValue;
    return : ISQ::EnergyValue;
    0.5 * mass * velocity * velocity
}
```

Built-in operators: arithmetic (`+`, `-`, `*`, `/`, `%`, `**`), comparison
(`==`, `!=`, `<`, `>`, `<=`, `>=`), logical (`and`, `or`, `not`, `xor`,
`implies`), type-test (`hastype`, `istype`, `as`).

**Best practice:** Extract repeated logic into named `constraint def` elements.
Use `calc def` for computations with return values.

## Use Cases

Use cases model interactions between a system (the subject) and external actors.
They capture what the system does from the actors' perspective, with objectives,
constraints, and included sub-use-cases.

```sysml
use case def TransportPassenger {
    objective TransportObjective {
        doc /* deliver passenger to destination safely and comfortably */
        require transportRequirements;
    }
    subject vehicle : Vehicle;
    actor environment;
    actor road;
    actor driver;
    actor passenger [0..4];                              // multiplicity
    include use case getInVehicle_a :> getInVehicle [1..5];
    include use case getOutOfVehicle_a :> getOutOfVehicle [1..5];
}
```

Use case definitions declare actors and constraints; use case usages add
behavioral sequencing with `first`/`then`, `fork`/`join`, and `accept`:

```sysml
use case def GetInVehicle {
    subject vehicle : Vehicle;
    actor driver [0..1];
    actor passenger [0..1];
    assert constraint { driver != null xor passenger != null }
}
use case getInVehicle : GetInVehicle {
    action unlockDoor_in [0..1];
    then action openDoor_in;
    then action enterVehicle;
    then action closeDoor_in;
}
```

Use case scenarios sequence sub-use-cases with concurrency:

```sysml
use case transportPassenger : TransportPassenger {
    first start;
    then action a {
        action driverGetInVehicle subsets getInVehicle_a[1];
        action passenger1GetInVehicle subsets getInVehicle_a[1];
    }
    then action trigger accept ignitionCmd : IgnitionCmd;
    then action b {
        action driveVehicleToDestination;
        action providePower;
    }
    then action c {
        action driverGetOutOfVehicle subsets getOutOfVehicle_a[1];
        action passenger1GetOutOfVehicle subsets getOutOfVehicle_a[1];
    }
    then done;
}
```

Bind parts to actors using assignment to connect the physical system to the
use case context:

```sysml
part missionContext : MissionContext {
    perform transportPassenger;
    part driver : Driver = transportPassenger.driver {
        perform transportPassenger.a.driverGetInVehicle.openDoor_in;
        perform transportPassenger.b.driveVehicleToDestination;
    }
}
```

**Best practice:** Define use case defs with actors and constraints first, then
create use case usages with action sequencing. Bind parts to actors in a mission
context package to connect structure to behavior.

## Verification

Verification cases define how to test that requirements are met. Each
verification has a subject (what is tested), an objective (which requirements
to verify), a method annotation, and test actions:

```sysml
verification def MassTest;
verification def AccelerationTest;

verification massTests : MassTest {
    subject vehicle_uut :> vehicle_b;
    actor vehicleVerificationSubSystem_1 = verificationContext.massVerificationSystem;
    objective {
        verify vehicleSpecification.vehicleMassRequirement {
            redefines massActual = weighVehicle.massMeasured;
        }
    }
    @ VerificationMethod {
        kind = (VerificationMethodKind::test, VerificationMethodKind::analyze);
    }
    action weighVehicle {
        out massMeasured :> ISQ::mass;
    }
    then action evaluatePassFail {
        in massMeasured :> ISQ::mass;
        out verdict = PassIf(vehicleSpecification.vehicleMassRequirement(vehicle_uut));
    }
    flow from weighVehicle.massMeasured to evaluatePassFail.massMeasured;
    return :>> verdict = evaluatePassFail.verdict;
}
```

The verification context maps test equipment to verification actions using
`perform`:

```sysml
part verificationContext {
    perform massTests;
    part vehicle_UnitUnderTest :> vehicle_b;
    part massVerificationSystem {
        part scale { perform massTests.weighVehicle; }
        part operator { perform massTests.evaluatePassFail; }
    }
}
```

**Best practice:** Organize verifications in a `VehicleVerification` package.
Define verification defs first, then create verification usages with subjects,
objectives, method annotations, and test action sequences. Use `perform` to
allocate test actions to verification equipment.

## Analysis

Analysis cases evaluate system properties. Each analysis has a subject, an
objective, and returns a computed result:

```sysml
analysis def FuelEconomyAnalysis {
    subject vehicle : Vehicle;
    objective {
        doc /* Determine fuel economy under standard conditions. */
    }
    return fuelEconomy : Real;
}
```

## Views and Viewpoints

Views and viewpoints control what parts of a model are exposed to stakeholders.
They form a layered system: concerns identify what matters, viewpoints frame the
perspective, view definitions specify filters and rendering, and view usages
select scope and apply additional filters.

### Concerns and Stakeholders

A `concern def` captures a stakeholder need. Each concern has a subject (what is
being examined) and one or more stakeholders (who cares about the result):

```sysml
part def SafetyEngineer;

concern def VehicleSafety {
    doc /* identify system safety features */
    subject;
    stakeholder se : SafetyEngineer;
}
```

### Viewpoint Definitions

A `viewpoint def` frames a perspective by referencing one or more concerns:

```sysml
viewpoint def BehaviorViewpoint;

viewpoint def SafetyViewpoint {
    frame concern vs : VehicleSafety;
}
```

### View Definitions

A `view def` specifies how to render a filtered subset of the model. View
definitions can specialize other view definitions with `:>` to inherit their
filters and render method:

```sysml
// Import the standard rendering library
public import Views::*;

// Base view with render method
view def TreeView {
    render asTreeDiagram;
}

// Empty view defs for other layouts
view def NestedView;
view def RelationshipView;
view def TableView;

// Inherits TreeView render + adds a metatype filter
view def PartsTreeView :> TreeView {
    filter @SysML::PartUsage;
}

// Inherits NestedView layout
view def PartsInterconnection :> NestedView;
```

Available render methods from the standard `Views` library:

| Render method                | Diagram style                        |
|------------------------------|--------------------------------------|
| `asTreeDiagram`              | Tree / BDD                           |
| `asInterconnectionDiagram`   | Internal block diagram (IBD)         |
| `asTableDiagram`             | Tabular view                         |

### View Usages

A view usage instantiates a view definition, selects scope with `expose`, and
can add additional filters. It can also satisfy a viewpoint requirement:

```sysml
view vehiclePartsTree_Safety : PartsTreeView {
    satisfy requirement sv : SafetyViewpoint;
    expose PartsTree::**;       // scope: all nested elements of PartsTree
    filter @Safety;             // additional filter: only Safety-tagged parts
}
```

The `expose` clause defines the model scope that the view includes. Recursive
import (`**`) includes all nested members.

### Metadata Filters

Filters select model elements by metatype or metadata annotation. SysML v2
supports boolean combinations:

```sysml
// Filter by SysML metatype
filter @SysML::PartUsage;
filter @SysML::RequirementUsage;
filter @SysML::ConnectionUsage;

// Filter by user-defined metadata tag
filter @Safety;
filter @Security;

// Boolean combinations
filter @Safety or @Security;           // either tag
filter @Safety and Safety::isMandatory; // tag + property access
```

Metadata filter packages can scope imports before filtering:

```sysml
package SafetyGroup {
    public import vehicle_b::**;
    filter @Safety;
}
package SafetyandSecurityGroup {
    public import vehicle_b::**;
    filter @Safety or @Security;
}
package MandatorySafetyGroup {
    public import vehicle_b::**;
    filter @Safety and Safety::isMandatory;
}
```

**Best practice:** Define base view defs with render methods, then specialize
with `:>` to add metatype filters. Keep view usages separate from view
definitions so the same view def can be reused across different scopes.

## Comments and Documentation

```sysml
// Line comment
/* Block comment */
doc /* Formal doc comment attached to the enclosing element. */
```

Metadata annotations prefix elements with `#`. Aliases create shorthand names:

```sysml
metadata def Safety { attribute isMandatory : Boolean; }
#Safety part safetyController : Controller;
alias Torque for ISQ::TorqueValue;
```

## Common Patterns

**System decomposition:** Top-level package with `Definitions` and `Usages`
sub-packages. Definitions hold reusable types; usages instantiate them.

**Interface-first design:** Define items (what flows), then port defs (where it
flows), then part defs (who has the ports), then interface defs (the contract):
`item def` -> `port def` -> `part def` -> `interface def`.

**Requirement traceability chain:** Define requirements with IDs, derive
sub-requirements, satisfy by parts, verify by test cases. Every requirement
should appear in all four steps: define -> derive -> satisfy -> verify.

**State machine for lifecycle:** Use `entry; then initialState;` for the initial
transition. Model operating modes, health states, or protocol states. Attach to
parts with `exhibit state`.

**Constraint-driven validation:** Extract reusable boolean assertions into
`constraint def` elements. Apply them inline or with `assert constraint`:

```sysml
constraint def PowerBudget {
    in allocated : ISQ::PowerValue;
    in consumed : ISQ::PowerValue;
    consumed <= allocated;
}
part def Subsystem {
    attribute powerConsumed : ISQ::PowerValue;
    assert constraint powerCheck : PowerBudget {
        in allocated = 500 [W];
        in consumed = powerConsumed;
    }
}
```

## Naming Conventions

| Category        | Convention             | Examples                                  |
|-----------------|------------------------|-------------------------------------------|
| Definitions     | PascalCase             | `Vehicle`, `FuelPort`, `MassReq`          |
| Usages          | camelCase              | `myEngine`, `fuelIn`, `frontAxle`         |
| Enum values     | camelCase or lowercase | `gasoline`, `on`, `off`                   |
| Packages        | PascalCase             | `Definitions`, `PartDefinitions`          |
| Transitions     | source_to_target       | `off_to_starting`, `normal_To_degraded`   |
| Requirement IDs | Quoted short names     | `<'REQ-001'>`, `<'PERF-042'>`            |
| Metadata tags   | Abbreviated            | `<fm>`, `<l>`, `<p>`                     |

- Suffix port defs with `Port`: `FuelPort`, `ControlPort`, `StatusPort`
- Suffix signals/commands with their role: `IgnitionCmd`, `StartSignal`
- Suffix requirements with `Req` or `Requirement`: `MassReq`, `FuelEconomyRequirement`

## Quick Reference Table

| Concept            | Keyword(s)                        | Example                                   |
|--------------------|-----------------------------------|-------------------------------------------|
| Package            | `package`                         | `package Sys { }`                         |
| Import             | `import`                          | `import ISQ::*;`                          |
| Part def / usage   | `part def`, `part`                | `part engine : Engine;`                   |
| Attribute          | `attribute def`, `attribute`      | `attribute mass : Real;`                  |
| Enum               | `enum def`, `enum`                | `enum def Color { enum red; }`            |
| Port               | `port def`, `port`                | `port fuelIn : ~FuelPort;`               |
| Connection         | `connection`, `connect ... to`    | `connect a.p1 to b.p2;`                  |
| Interface          | `interface def`                   | `interface def I { end a; end b; }`       |
| Flow               | `flow of ... from ... to`         | `flow of Fuel from a to b;`              |
| Binding            | `bind`                            | `bind portA = partB.portA;`              |
| Allocation         | `allocation def`, `allocate`      | `allocate logical to physical;`           |
| Item               | `item def`, `item`                | `item def Fuel { }`                       |
| Action             | `action def`, `action`            | `action def Start { in x; out y; }`       |
| Succession         | `first ... then`                  | `first start then run;`                   |
| Fork / Join        | `fork`, `join`                    | `fork then a; join then b;`              |
| Send / Accept      | `send`, `accept`                  | `accept Cmd via port;`                    |
| Perform            | `perform action`                  | `perform action drive;`                   |
| State              | `state def`, `state`              | `state def S { state off; }`              |
| Exhibit            | `exhibit state`                   | `exhibit state sm parallel { }`           |
| Transition         | `transition ... first ... then`   | `transition first off then on;`           |
| Entry / Exit / Do  | `entry`, `exit`, `do`             | `entry init; do run; exit cleanup;`       |
| Requirement        | `requirement def`                 | `requirement def R { subject s : S; }`    |
| Satisfy / Verify   | `satisfy ... by`, `verify ... by` | `satisfy requirement R by Part;`          |
| Derivation         | `#derivation connection`          | `end #original ::> A; end #derive ::> B;` |
| Refinement         | `#refinement dependency`          | `#refinement dependency X to Y;`          |
| Requirement ID     | `<'ID'>`                          | `requirement def <'REQ-1'> R { }`         |
| Constraint         | `constraint def`, `constraint`    | `constraint { x <= y }`                   |
| Assert             | `assert constraint`               | `assert constraint { a > 0 }`             |
| Calculation        | `calc def`                        | `calc def F { in x; return : R; }`        |
| Use case           | `use case def`                    | `use case def U { subject s; }`           |
| Analysis           | `analysis def`                    | `analysis def A { return r : R; }`        |
| Verification       | `verification def`                | `verification def V { objective { } }`    |
| View / Viewpoint   | `view def`, `viewpoint def`       | `view def V { filter @SysML::PartUsage; }`|
| Concern            | `concern def`                     | `concern def C { stakeholder s; }`        |
| Expose             | `expose`                          | `expose PartsTree::**;`                   |
| Render             | `render`                          | `render asTreeDiagram;`                   |
| Filter             | `filter @`                        | `filter @Safety or @Security;`            |
| Doc comment        | `doc /* */`                       | `doc /* description */`                   |
| Metadata           | `metadata def`, `#`               | `#Safety part p : P;`                     |
| Alias              | `alias ... for`                   | `alias T for ISQ::TorqueValue;`           |
| Visibility         | `public`, `private`, `protected`  | `private import X::*;`                    |
| Specialization     | `:>`                              | `part def Sub :> Base { }`                |
| Redefines          | `redefines`                       | `attribute m redefines Base::m;`          |
| Subsets            | `subsets`                         | `part w1 subsets wheels;`                 |
| Conjugation        | `~`                               | `port p : ~FuelPort;`                     |
| Multiplicity       | `[n]`, `[n..m]`, `[*]`           | `part wheel : Wheel[4];`                  |
| Abstract           | `abstract`                        | `abstract part def Base { }`              |
| Reference          | `ref`                             | `ref item fuel : Fuel;`                   |
| Individual         | `individual def`                  | `individual def Car_1 :> Car;`            |
