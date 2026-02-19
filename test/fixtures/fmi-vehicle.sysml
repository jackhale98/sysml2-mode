package FMIVehicle {
    port def FuelPort {
        in item fuelFlow : Real;
    }
    port def DrivePort {
        out item torque : Real;
        out item speed : Real;
    }
    port def IgnitionPort {
        in item ignitionOn : Boolean;
    }
    part def Engine {
        port fuelIn : FuelPort;
        port driveOut : ~DrivePort;
        port ignition : IgnitionPort;
        attribute displacement : Real;
        attribute cylinders : Integer;
    }
    part def Transmission {
        port driveIn : DrivePort;
        attribute gearCount : Integer;
    }
    part def VehicleSystem {
        part engine : Engine;
        part transmission : Transmission;
        connection engineToDrive
            connect engine.driveOut to transmission.driveIn;
    }
    requirement def MaxSpeedReq {
        doc /* speed <= 200 */
        subject s : VehicleSystem;
    }
    requirement def MaxTorqueReq {
        doc /* torqueOut <= 500 */
    }
    requirement def ComplexReq {
        doc /* acceleration * mass < maxForce AND speed > 0 */
    }
}
