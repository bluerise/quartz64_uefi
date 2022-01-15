/** @file
*  eMMC Controller devices.
*
*  Copyright (c) 2022, Jared McNeill <jmcneill@invisible.ca>
*
*  SPDX-License-Identifier: BSD-2-Clause-Patent
**/

#include <IndustryStandard/Acpi60.h>

// eMMC Controller
Device (EMMC) {
    Name (_HID, "RKCP0D40")
    Name (_UID, 0)
    Name (_CCA, Zero)

    Name (_DSD, Package () {
        ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"),
        Package () {
            // Package () { "sdhci-caps-mask", 0x70000FF00 },   // Bits [15:8]: BASE_CLK_FREQ
            //                                                  // Bit [32]: SDR50_SUPPORT
            //                                                  // Bit [33]: SDR104_SUPPORT
            //                                                  // Bit [34]: DDR50_SUPPORT
            // Package () { "sdhci-caps", 0x3200 }              // BASE_CLK_FREQ = 50 MHz
        }
    })

    // CRU_CLKSEL_CON28
    OperationRegion (CRU, SystemMemory, 0xFDD20170, 0x4)
    Field (CRU, DWordAcc, NoLock, Preserve) {
        CS28,   32
    }

    // EMMC_AT_CTRL
    OperationRegion (VEND, SystemMemory, 0xFE310540, 0x4)
    Field (VEND, DWordAcc, NoLock, Preserve) {
        VATC,   32
    }

    // EMMC_DLL registers
    OperationRegion (DLL, SystemMemory, 0xFE310800, 0x48)
    Field (DLL, DWordAcc, NoLock, Preserve) {
        DCTL,   32,
        DRXC,   32,
        DTXC,   32,
        DSTR,   32,
        Offset  (0x40),
        DST0,   32
    }

    Method (_DSM, 4) {
        If (LEqual (Arg0, ToUUID("434addb0-8ff3-49d5-a724-95844b79ad1f"))) {
            Switch (ToInteger (Arg2)) {
                Case (0) {
                    Return (0x3)
                }
                Case (1) {
                    Local0 = DerefOf (Arg3 [0])     // Target frequency
                    Local1 = 0;                     // Actual frequency

                    // RX clock
                    DRXC = 0x8000000

                    If (Local0 >= 200000000) {
                        CS28 = 0x70001000
                        Local1 = 200000000
                    } ElseIf (Local0 >= 150000000) {
                        CS28 = 0x70002000
                        Local1 = 150000000
                    } ElseIf (Local0 >= 100000000) {
                        CS28 = 0x70003000
                        Local1 = 100000000
                    } ElseIf (Local0 >= 50000000) {
                        CS28 = 0x70004000
                        Local1 = 50000000
                    } ElseIf (Local0 >= 24000000) {
                        CS28 = 0x70000000
                        Local1 = 24000000
                    } ElseIf (Local0 >= 375000) {
                        CS28 = 0x70005000
                        Local1 = 375000
                    }

                    If (Local1 <= 52000000) {
                        // Disable DLL
                        DCTL = 0
                        DRXC = 0x20000000
                        DTXC = 0
                        DSTR = 0
                    } else {
                        // Reset DLL
                        DCTL = 2
                        Stall (1)
                        DCTL = 0
                        // Enable DLL
                        DCTL = 0x00050201
                        // Wait for lock
                        While ((DST0 & 0x100) == 0) {
                            Stall (1)
                        }
                        // Tuning
                        VATC = 0x1D0000
                        // Delays
                        DTXC = 0x9000008
                        DSTR = 0x9000008
                    }

                    Return (Local1)
                }
            }
        }
        Return (0)
    }

    Method (_CRS, 0x0, Serialized) {
        Name (RBUF, ResourceTemplate() {
            Memory32Fixed (ReadWrite, 0xFE310000, 0x100)
            Interrupt (ResourceConsumer, Level, ActiveHigh, Exclusive) { 51 }
        })
        Return (RBUF)
    }
}