//
//  File.swift
//
//
//  Created by Kjetil Hustveit on 11/07/2023.
//

import Foundation
import CellBase

struct DummyStruct {
//    func doSomething() {
//
//    }
}

class EventEmitterCell: GeneralCell {
    

    var running: Bool = false
    
    required init(owner: Identity) async {
        await super.init(owner: owner)
        self.agreementTemplate.addGrant("rw--", for: "start")
        self.agreementTemplate.addGrant("rw--", for: "stop")
        
        print("Initing Location Event Emitter")
       
        


        await setupPermissions(owner: owner)
        await setupKeys(owner: owner)
}

private func setupPermissions(owner: Identity) async  {
    self.agreementTemplate.addGrant("rw-", for: "mintVerifiableCredential")
    self.agreementTemplate.addGrant("r---", for: "state")
}

private func setupKeys(owner: Identity) async  {
        await addInterceptForGet(requester: owner, key: "state", getValueIntercept: { [weak self] _, requester in
            guard let self = self else { return .string("failure") }
            guard await self.validateAccess("r---", at: "state", for: requester) else { return .string("denied") }
            return self.stateValue()
        })

        
        await addInterceptForGet(requester: owner, key: "start", getValueIntercept:  {
            [weak self] keypath, requester  in
            guard let self = self else { return .string("failure")}
            guard await self.validateAccess("r---", at: "start", for: requester) else { return .string("denied") }
            return self.stateValue()
        })
        
        await addInterceptForGet(requester: owner, key: "stop", getValueIntercept:  {
            [weak self]  keypath, requester  in
            guard let self = self else { return .string("failure")}
            guard await self.validateAccess("r---", at: "stop", for: requester) else { return .string("denied") }
            return self.stateValue()
        })

        await addInterceptForSet(requester: owner, key: "start", setValueIntercept:  {
            [weak self] keypath, value, requester  in
            guard let self = self else { return .string("failure")}
            guard await self.validateAccess("rw--", at: "start", for: requester) else { return .string("denied") }
            await self.startEmitter()
            return self.stateValue()
        })

        await addInterceptForSet(requester: owner, key: "stop", setValueIntercept:  {
            [weak self] keypath, value, requester  in
            guard let self = self else { return .string("failure")}
            guard await self.validateAccess("rw--", at: "stop", for: requester) else { return .string("denied") }
            await self.stopEmitter()
            return self.stateValue()
        })
    }
    
    nonisolated required init(from decoder: Decoder) throws {
        fatalError("init(from:) has not been implemented")
    }
    
    
    func startEmitter() async {
        if running { return }
        print("Starting emitter")
        running = true
        await runEmitter()
    }
    
    func runEmitter() async {
        guard running else { return }

        var flowElement = FlowElement(id: UUID().uuidString, title: "TestEvent", content: .object(["key" : .string("value")]), properties: FlowElement.Properties(type: .content, contentType: .object)) // Remember to change to .event
        
        flowElement.topic = "test"
        if let vault = CellBase.defaultIdentityVault,
           let requester = await vault.identity(for: "private", makeNewIfNotFound: true ) {
            self.pushFlowElement(flowElement, requester: requester)
        }
        if running {
            DispatchQueue.global().asyncAfter(deadline: .now() + Double.random(in: 2..<10)) { [weak self] in
                Task {
                    guard let self = self else { return }
                    await self.runEmitter()
                }
            }
        }
    }
    
    
    func stopEmitter() async {
        self.running = false
    }

    private func stateValue() -> ValueType {
        .object(["running": .bool(running)])
    }
}
