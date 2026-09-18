// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

//
//  BindingExternalURLOpener.swift
//  Binding
//
//  Opens a `mailto:` or `sms:` composer, and nothing else.
//
//  This exists because the last centimetre of "inviter Vegar" was missing: the
//  invitation cell produced a finished message and a handoff URL, and the
//  skeleton could only render it as text. `SkeletonButton` carries a static
//  `url`, but the URL here is data — it changes per invitation — and the
//  skeleton format has no `urlKeypath`. Rather than add renderer surface we
//  would then have to make every renderer honour, the cell opens it, from an
//  explicit press.
//
//  The scheme allow-list is the whole security story. A cell hands us a
//  string; only two prefixes ever reach the system opener.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

@MainActor
enum BindingExternalURLOpener {

    /// Composer schemes only. `http(s)` is deliberately absent: nothing in the
    /// invitation flow needs to send the person to a web page, and allowing it
    /// would turn a cell value into an arbitrary navigation.
    static let allowedSchemes: Set<String> = ["mailto", "sms"]

    @discardableResult
    static func open(_ urlString: String) async -> Bool {
        guard let url = URL(string: urlString),
              let scheme = url.scheme?.lowercased(),
              allowedSchemes.contains(scheme) else {
            CellBaseDiagnostics.log("Refused to open URL with disallowed scheme: \(urlString.prefix(24))")
            return false
        }

#if canImport(UIKit) && !os(watchOS)
        guard UIApplication.shared.canOpenURL(url) else { return false }
        return await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            UIApplication.shared.open(url, options: [:]) { success in
                continuation.resume(returning: success)
            }
        }
#elseif canImport(AppKit)
        return NSWorkspace.shared.open(url)
#else
        return false
#endif
    }
}

/// Tiny indirection so this file does not have to import CellBase just to log.
private enum CellBaseDiagnostics {
    static func log(_ message: String) {
        print("[BindingExternalURLOpener] \(message)")
    }
}
