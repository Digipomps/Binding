// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

import Foundation
#if canImport(Darwin)
import Darwin
#endif

/// Cumulative link-layer counters for one interface, read natively from the
/// kernel via getifaddrs (AF_LINK / if_data). No privileges, no subprocess.
struct InterfaceCounterReading: Sendable, Equatable {
    var ipackets: UInt64
    var opackets: UInt64
    var ibytes: UInt64
    var obytes: UInt64
    var ierrors: UInt64
    var oerrors: UInt64
}

enum InterfaceCounters {
    /// Returns the cumulative counters for `interface` (e.g. "en0"), or nil if
    /// the interface is not present / has no link-layer data.
    static func read(interface: String) -> InterfaceCounterReading? {
        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPtr) == 0 else { return nil }
        defer { freeifaddrs(ifaddrPtr) }

        var cursor = ifaddrPtr
        while let current = cursor {
            let ifa = current.pointee
            defer { cursor = ifa.ifa_next }

            guard let namePtr = ifa.ifa_name,
                  String(cString: namePtr) == interface,
                  let addr = ifa.ifa_addr,
                  Int32(addr.pointee.sa_family) == AF_LINK,
                  let dataPtr = ifa.ifa_data else {
                continue
            }

            let data = dataPtr.assumingMemoryBound(to: if_data.self).pointee
            return InterfaceCounterReading(
                ipackets: UInt64(data.ifi_ipackets),
                opackets: UInt64(data.ifi_opackets),
                ibytes: UInt64(data.ifi_ibytes),
                obytes: UInt64(data.ifi_obytes),
                ierrors: UInt64(data.ifi_ierrors),
                oerrors: UInt64(data.ifi_oerrors)
            )
        }
        return nil
    }
}
