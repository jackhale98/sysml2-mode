// Indentation edge cases for testing sysml2-indent-line
// Each section tests a specific indentation rule

// Case 1: Basic block indentation
package BasicBlock {
    part def Bar {
        attribute x : ScalarValues::Real;
    }
}

// Case 2: Nested blocks
part def Vehicle {
    part engine : Engine {
        port fuelIn : ~FuelPort;
    }
}

// Case 3: Multi-line expressions
requirement def MassReq {
    attribute massActual :
        ISQ::MassValue;

    require constraint {
        massActual <= massLimit
    }
}

// Case 4: Import statements inside package
package ImportTest {
    import ISQ::*;
    import SI::*;

    part def Foo {
    }
}

// Case 5: Semicolon-terminated single-line usages
part def System {
    part a : PartA;
    part b : PartB;
}

// Case 6: Action succession
action def Drive {
    action start : StartEngine;
    action accelerate : Accelerate;

    first start then accelerate;
}

// Case 7: State transitions
state def EngineStates {
    entry; then off;

    state off;
    state running;

    transition off_to_running
        first off
        accept startSignal
        then running;
}

// Case 8: Empty blocks
part def EmptyPart {
}

// Case 9: Deeply nested (3+ levels)
package Outer {
    package Inner {
        part def Deep {
            attribute x : ScalarValues::Real;
        }
    }
}

// Case 10: Connection with connect keyword
part def Connected {
    part a : PartA;
    part b : PartB;
    connection c : ConnType
        connect a to b;
}

// Case 11: Requirement with subject and constraint
requirement def PerformanceReq {
    subject system : System;
    doc /* Must perform well */
    require constraint {
        system.speed >= 100
    }
}

// Case 12: Use case with actors
use case def Operate {
    subject system : System;
    actor user : Person;
    actor admin : Person;
}

// Case 13: Top-level (no indent)
part def TopLevel1;
part def TopLevel2;
import Base::*;
