// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

//
//  HavenInviteTicket.swift
//  Binding
//
//  MOVED. These types now live in CellProtocol:
//
//      CellProtocol/Sources/CellBase/Invitation/HavenInviteTicket.swift
//          HavenSignatureProof, HavenInviteTicket, HavenInviteLink,
//          HavenInviteVerifier
//
//      CellProtocol/Sources/CellBase/Invitation/HavenInvitePublication.swift
//          HavenInviteCopy (was HavenInviteComposer), HavenInvitePublication,
//          HavenInviteRevocationNotice, HavenInviteStatusReport,
//          HavenInviteContactRequest, HavenInvitePublicationVerifier
//
//  They had to move because the invitee's side of an invitation does not run
//  in this app. It runs on a landing page in CellScaffold, on a device that
//  has never seen HAVEN. Two implementations of "is this invitation valid"
//  drift apart; one shared type cannot.
//
//  Binding gets all of it through `import CellBase`. This file is left as a
//  signpost so the next person looking for the ticket in Cells/ finds it.
//
