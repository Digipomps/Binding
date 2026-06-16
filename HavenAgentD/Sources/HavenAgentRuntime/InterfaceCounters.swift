// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

import Foundation
#if canImport(Darwin)
import Darwin
#endif

/// Cumulative link-layer counters for one interface, read natively from the
/// kernel via getifaddrs (AF_LINK / if_data). No privileges, no subprocess.
public struct InterfaceCounterReading: Sendable, Equatable {
    public var ipackets: UInt64
    public var opackets: UInt64
    public var ibytes: UInt64
    public var obytes: UInt64
    public var ierrors: UInt64
    public var oerrors: UInt64

    public init(
        ipackets: UInt64,
        opackets: UInt64,
        ibytes: UInt64,
        obytes: UInt64,
        ierrors: UInt64,
        oerrors: UInt64
    ) {
        self.ipackets = ipackets
        self.opackets = opackets
        self.ibytes = ibytes
        self.obytes = obytes
        self.ierrors = ierrors
        self.oerrors = oerrors
    }
}

public enum InterfaceCounters {
    /// Returns the cumulative counters for `interface` (e.g. "en0"), or nil if
    /// the interface is not present / has no link-layer data.
    public static func read(interface: String) -> InterfaceCounterReading? {
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

    /// Enumerates all interfaces natively (name, up/down, MAC, IPv4/IPv6).
    public static func allInterfaces() -> [InterfaceInfo] {
        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPtr) == 0 else { return [] }
        defer { freeifaddrs(ifaddrPtr) }

        struct Builder { var isUp = false; var mac: String?; var v4: [String] = []; var v6: [String] = [] }
        var builders: [String: Builder] = [:]
        var order: [String] = []

        var cursor = ifaddrPtr
        while let current = cursor {
            let ifa = current.pointee
            defer { cursor = ifa.ifa_next }
            guard let namePtr = ifa.ifa_name else { continue }
            let name = String(cString: namePtr)
            if builders[name] == nil { builders[name] = Builder(); order.append(name) }
            builders[name]?.isUp = (ifa.ifa_flags & UInt32(IFF_UP)) != 0

            guard let addr = ifa.ifa_addr else { continue }
            switch Int32(addr.pointee.sa_family) {
            case AF_INET:
                if let text = address(from: addr, family: AF_INET, length: INET_ADDRSTRLEN) {
                    builders[name]?.v4.append(text)
                }
            case AF_INET6:
                if let text = address(from: addr, family: AF_INET6, length: INET6_ADDRSTRLEN) {
                    builders[name]?.v6.append(text)
                }
            case AF_LINK:
                if let mac = macAddress(from: addr) { builders[name]?.mac = mac }
            default:
                break
            }
        }

        return order.compactMap { name in
            guard let builder = builders[name] else { return nil }
            let addresses = builder.v4 + builder.v6
            let summary = addresses.isEmpty ? (builder.mac ?? "—") : addresses.joined(separator: " · ")
            return InterfaceInfo(
                name: name,
                isUp: builder.isUp,
                macAddress: builder.mac,
                ipv4: builder.v4,
                ipv6: builder.v6,
                addressSummary: summary
            )
        }
    }

    private static func address(from addr: UnsafeMutablePointer<sockaddr>, family: Int32, length: Int32) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(length))
        let ok: Bool
        if family == AF_INET {
            ok = addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { sin in
                withUnsafePointer(to: &sin.pointee.sin_addr) { inet_ntop(AF_INET, $0, &buffer, socklen_t(length)) != nil }
            }
        } else {
            ok = addr.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { sin6 in
                withUnsafePointer(to: &sin6.pointee.sin6_addr) { inet_ntop(AF_INET6, $0, &buffer, socklen_t(length)) != nil }
            }
        }
        guard ok else { return nil }
        return buffer.withUnsafeBufferPointer { pointer in
            pointer.baseAddress.map { String(cString: $0) }
        } ?? nil
    }

    private static func macAddress(from addr: UnsafeMutablePointer<sockaddr>) -> String? {
        addr.withMemoryRebound(to: sockaddr_dl.self, capacity: 1) { dlPtr -> String? in
            let dl = dlPtr.pointee
            guard Int(dl.sdl_alen) == 6 else { return nil }
            let nlen = Int(dl.sdl_nlen)
            let macBytes: [UInt8] = withUnsafeBytes(of: dl.sdl_data) { raw in
                var out = [UInt8]()
                for index in 0..<6 {
                    let offset = nlen + index
                    guard offset >= 0, offset < raw.count else { return [] }
                    out.append(raw[offset])
                }
                return out
            }
            guard macBytes.count == 6, macBytes.contains(where: { $0 != 0 }) else { return nil }
            return macBytes.map { String(format: "%02x", $0) }.joined(separator: ":")
        }
    }
}
