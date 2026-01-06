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
    
    do {
//        let grantSaveVCCondition = GrantCondition(requestedGrant: "identity.proofs.smi.products.purchased", requestedPermission: "-w-")
//        try self.agreementTemplate.addCondition(grantSaveVCCondition)
    } catch {
        print("SMICell setupPermissions conditions failed with error: \(error)")
    }
}

private func setupKeys(owner: Identity) async  {
    

        
        await addInterceptForGet(requester: owner, key: "start", getValueIntercept:  {
            [weak self] keypath, requester  in
            guard let self = self else { return .string("failure")}
            var resultString = "denied"
            if await self.validateAccess("r---", at: "start", for: requester) {
                do {
                    try await self.startEmitter()
                    resultString = "ok"
                } catch {
                        resultString = "error: \(error)"
                }


            }
            return .string(resultString)
        })
        
        await addInterceptForGet(requester: owner, key: "stop", getValueIntercept:  {
            [weak self]  keypath, requester  in
            guard let self = self else { return .string("failure")}
            var resultString = "denied"
            if await self.validateAccess("r---", at: "stop", for: requester) {
                do {
                    try await self.stopEmitter()
                    resultString = "ok"
                } catch {
//                        resultString = "error: \(error)"
                }
                
                
            }
            return .string(resultString)
        })
    }
    
    nonisolated required init(from decoder: Decoder) throws {
        fatalError("init(from:) has not been implemented")
    }
    
    
    func startEmitter() async throws {
        print("Starting emitter")
        running = true
        await runEmitter()
    }
    
    func runEmitter() async {
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
    
    
    func stopEmitter() async throws {
        self.running = false
    }
}

