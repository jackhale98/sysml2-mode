// Simple Vehicle Model — Primary test fixture for sysml2-mode
// Tests: font-lock, indentation, completion, navigation

package VehicleModel {
    import ISQ::*;
    import SI::*;

    // Attribute definitions
    attribute def MassValue :> ISQ::MassValue;
    attribute def SpeedValue :> ISQ::SpeedValue;
    attribute def VolumeValue :> ISQ::VolumeValue;

    // Enumeration
    enum def FuelType {
        enum gasoline;
        enum diesel;
        enum electric;
    }

    // Port definitions
    port def FuelPort {
        in item fuelIn : FuelType;
    }

    port def ElectricalPort {
        in item powerIn : ScalarValues::Real;
        out item powerOut : ScalarValues::Real;
    }

    // Abstract base definition
    abstract part def PowerSource {
        attribute maxPower : ScalarValues::Real;
    }

    // Part definitions with specialization
    part def Engine :> PowerSource {
        port fuelIn : ~FuelPort;
        attribute displacement : VolumeValue;
        attribute fuelType : FuelType;
    }

    part def ElectricMotor :> PowerSource {
        port electricIn : ElectricalPort;
        attribute efficiency : ScalarValues::Real;
    }

    part def Transmission {
        attribute gearCount : ScalarValues::Integer;
        attribute isAutomatic : ScalarValues::Boolean;
    }

    part def Wheel {
        attribute diameter : ISQ::LengthValue;
    }

    part def Chassis {
        attribute mass : MassValue;
    }

    // Main vehicle definition
    part def Vehicle {
        attribute mass : MassValue;
        attribute topSpeed : SpeedValue;

        part engine : Engine;
        part transmission : Transmission;
        part wheel : Wheel[4];
        part chassis : Chassis;

        // Connections
        connection engineToTrans : EngineConnection
            connect engine to transmission;
    }

    // Connection definition
    connection def EngineConnection {
        end source : Engine;
        end target : Transmission;
    }

    // Action definitions
    action def StartEngine {
        in ignitionSignal : ScalarValues::Boolean;
        out engineRunning : ScalarValues::Boolean;
    }

    action def Accelerate {
        in throttle : ScalarValues::Real;
        out speed : SpeedValue;
    }

    action def Brake {
        in brakeForce : ScalarValues::Real;
        out speed : SpeedValue;
    }

    action def Drive {
        action start : StartEngine;
        action accelerate : Accelerate;
        action brake : Brake;

        first start then accelerate;
    }

    // State definitions
    state def EngineStates {
        entry; then off;

        state off;
        state starting;
        state running;
        state stopping;

        transition off_to_starting
            first off
            accept startCmd
            then starting;

        transition starting_to_running
            first starting
            then running;

        transition running_to_stopping
            first running
            accept stopCmd
            then stopping;

        transition stopping_to_off
            first stopping
            then off;
    }

    // Requirement definitions
    requirement def VehicleMassReq {
        doc /* The vehicle mass shall not exceed 2000 kg */
        subject vehicle : Vehicle;
        require constraint {
            vehicle.mass <= 2000 [kg]
        }
    }

    requirement def TopSpeedReq {
        doc /* The vehicle shall achieve a top speed of at least 180 km/h */
        subject vehicle : Vehicle;
        require constraint {
            vehicle.topSpeed >= 180 [km/h]
        }
    }

    // Constraint definition
    constraint def MassConstraint {
        in massActual : MassValue;
        in massLimit : MassValue;
        massActual <= massLimit;
    }

    // Use case
    use case def DriveVehicle {
        subject vehicle : Vehicle;
        actor driver : ScalarValues::String;

        include use case startEngine : StartEngine;
    }

    // View definition
    view def VehicleStructureView {
        filter @SysML::PartUsage;
    }

    // Satisfy relationship
    satisfy requirement VehicleMassReq by Vehicle;
    satisfy requirement TopSpeedReq by Vehicle;
}
