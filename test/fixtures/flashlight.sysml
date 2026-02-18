// Flashlight Example — Adapted from SysML v2 Pilot Implementation
// Based on official SysML v2 example corpus

package Flashlight {
    import ISQ::*;
    import SI::*;
    import ScalarValues::*;

    // Item definition for light
    item def Light;

    // Port definitions
    port def ElectricalPowerPort {
        in item electricPower : Real;
    }

    port def LightPort {
        out item light : Light;
    }

    // Part definitions
    part def Battery {
        port powerOut : ElectricalPowerPort;
        attribute voltage : Real;
        attribute capacity : Real;
    }

    part def Bulb {
        port powerIn : ~ElectricalPowerPort;
        port lightOut : LightPort;
        attribute wattage : Real;
    }

    part def Switch {
        attribute isOn : Boolean;
    }

    part def FlashlightCase {
        attribute material : String;
        attribute length : ISQ::LengthValue;
    }

    // Main flashlight definition
    part def Flashlight {
        part battery : Battery;
        part bulb : Bulb;
        part switch : Switch;
        part case : FlashlightCase;

        connection batteryToBulb
            connect battery.powerOut to bulb.powerIn;
    }

    // Actions
    action def TurnOn {
        in switchState : Boolean;
        out lightState : Boolean;
    }

    action def TurnOff {
        in switchState : Boolean;
        out lightState : Boolean;
    }

    action def UseFlashlight {
        action turnOn : TurnOn;
        action turnOff : TurnOff;

        first turnOn then turnOff;
    }

    // States
    state def FlashlightStates {
        entry; then off;

        state off;
        state on;

        transition off_to_on
            first off
            accept switchOn
            then on;

        transition on_to_off
            first on
            accept switchOff
            then off;
    }

    // Requirements
    requirement def BatteryLifeReq {
        doc /* Battery shall last at least 4 hours of continuous use */
        subject flashlight : Flashlight;
        require constraint {
            flashlight.battery.capacity >= 4.0
        }
    }

    requirement def WeightReq {
        doc /* Flashlight shall weigh no more than 500 grams */
        subject flashlight : Flashlight;
    }

    // Verification
    verification case def TestBatteryLife {
        subject flashlight : Flashlight;
        objective {
            verify requirement BatteryLifeReq;
        }
    }

    satisfy requirement BatteryLifeReq by Flashlight;
    satisfy requirement WeightReq by Flashlight;
}
