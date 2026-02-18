// Basic KerML file for testing kerml-mode
// KerML is the kernel modeling language underlying SysML v2

package KerMLBasics {
    import Base::*;

    // Type definition (KerML construct)
    part def Sensor {
        attribute reading : ScalarValues::Real;
        attribute isActive : ScalarValues::Boolean;
    }

    part def Actuator {
        attribute command : ScalarValues::Real;
        attribute isEnabled : ScalarValues::Boolean;
    }

    // Specialization
    part def TemperatureSensor :> Sensor {
        attribute unit : ScalarValues::String;
    }

    // Feature chaining
    part def ControlSystem {
        part sensor : TemperatureSensor;
        part actuator : Actuator;

        // Binding
        bind sensor.reading = actuator.command;
    }

    // Occurrence
    occurrence def Measurement {
        in sensor : Sensor;
        out value : ScalarValues::Real;
    }
}
