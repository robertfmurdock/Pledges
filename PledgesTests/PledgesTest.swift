//
//  PledgeTests.swift
//  Squarmy
//
//  Created by Robert Murdock on 8/14/14.
//  Copyright (c) 2014 Armoria Software. All rights reserved.
//

import Foundation
import XCTest
import ArmorTestKit
import Pledges

class PledgeTests : XCTestCase {
    
    func testPromiseWillCallActionImmediatelyOnInit() {
        var actionWasCalled = false
        Pledge<String>() { (resolve, reject) in
            actionWasCalled = true
        }
        
        XCTAssertTrue(actionWasCalled)
    }
    
    func testWhenActionCallsResolveImmediatelyThenIsTriggeredAsSoonAsItIsAdded(){
        var wasCalled = false
        let expectedString = "12383y3461634"
        Pledge() { resolve, reject in resolve(value: expectedString) }
            .then { value in
                wasCalled = true
                XCTAssertEqual(expectedString, value)
        }
        
        XCTAssertTrue(wasCalled)
    }
    
    func testWhenActionCallsResolveDelayedMultipleThensAreTriggeredAsSoonAsTheyAreAddedExactlyOnce(){
        var then1CallCount = 0
        var then2CallCount = 0
        var then3CallCount = 0
        let expectedString = "asdfsd"
        var resolveCall : Pledge<String>.Resolve?  = nil
        Pledge() { resolve, reject in
            resolveCall = resolve
            }.then { value in
                then1CallCount++
                XCTAssertEqual(expectedString, value)
            }.then { value in
                then2CallCount++
                XCTAssertEqual(expectedString, value)
            }.then { value in
                then3CallCount++
                XCTAssertEqual(expectedString, value)
        }
        
        XCTAssertEqual(0, then1CallCount)
        XCTAssertEqual(0, then2CallCount)
        XCTAssertEqual(0, then3CallCount)
        
        assertNotNil(resolveCall) {
            withValue in
            withValue(value: expectedString)
        }
        
        XCTAssertEqual(1, then1CallCount)
        XCTAssertEqual(1, then2CallCount)
        XCTAssertEqual(1, then3CallCount)
    }
    
    func testWhenAPledgeIsResolvedASecondTimeNoThensAreCalledBecauseThePledgeWasAlreadyFulfilled(){
        var then1CallCount = 0
        let expectedString = "3423"
        var resolveCall : Pledge<String>.Resolve?  = nil
        Pledge()
            { resolve, reject in
                resolveCall = resolve
            }.then { value in
                then1CallCount++
                XCTAssertEqual(expectedString, value)
        }
        
        assertNotNil(resolveCall) {
            withValue in
            withValue(value: expectedString)
            withValue(value: "Bad String")
            withValue(value: "A second bad String")
        }
        
        XCTAssertEqual(1, then1CallCount)
    }
    
    func testWhenActionCallsRejectImmediatelyFailIsTriggeredAsSoonAsItIsAdded(){
        var error1CallCount = 0
        var error2CallCount = 0
        var error3CallCount = 0
        
        let expectedError = "38hfehf"
        Pledge<Int>() { resolve, reject in reject(error: expectedError) }
            .fail { error in
                error1CallCount++
                XCTAssertEqual(expectedError, error)
            }            .fail { error in
                error2CallCount++
                XCTAssertEqual(expectedError, error)
            }            .fail { error in
                error3CallCount++
                XCTAssertEqual(expectedError, error)
        }
        
        XCTAssertEqual(1, error1CallCount)
        XCTAssertEqual(1, error2CallCount)
        XCTAssertEqual(1, error3CallCount)
    }
    
    func testWhenActionCallsRejectDelayedMultipleThensAreTriggeredAsSoonRejectIsCalledExactlyOnce(){
        var then1CallCount = 0
        var then2CallCount = 0
        var then3CallCount = 0
        let expectedError = "asdfsd"
        var rejectCall : Pledge.Reject?  = nil
        Pledge<Double>() { resolve, reject in
            rejectCall = reject
            }.fail { value in
                then1CallCount++
                XCTAssertEqual(expectedError, value)
            }.fail{ value in
                then2CallCount++
                XCTAssertEqual(expectedError, value)
            }.fail{ value in
                then3CallCount++
                XCTAssertEqual(expectedError, value)
        }
        
        XCTAssertEqual(0, then1CallCount)
        XCTAssertEqual(0, then2CallCount)
        XCTAssertEqual(0, then3CallCount)
        
        assertNotNil(rejectCall){
            rejectCall in
            rejectCall(error: expectedError)
        }
        
        XCTAssertEqual(1, then1CallCount)
        XCTAssertEqual(1, then2CallCount)
        XCTAssertEqual(1, then3CallCount)
    }
    
    func testWhenAPledgeIsRejectedASecondTimeNoFailesAreCalledBecauseThePledgeWasAlreadyBroken(){
        var failCallCount = 0
        let expectedError = "3423"
        var rejectCall : Pledge.Reject?  = nil
        Pledge<Int>()
            { resolve, reject in
                rejectCall = reject
            }.fail { value in
                failCallCount++
                XCTAssertEqual(expectedError, value)
        }
        
        assertNotNil(rejectCall) {
            withValue in
            withValue(error: expectedError)
            withValue(error: "Bad String")
            withValue(error: "A second bad String")
        }
        
        XCTAssertEqual(1, failCallCount)
    }
    
    func testIfRejectIsCalledAfterResolveFailesAreNotInformed(){
        var failCallCount = 0
        var resolveCall : Pledge<Int>.Resolve?  = nil
        var rejectCall : Pledge.Reject?  = nil
        Pledge<Int>()
            { resolve, reject in
                resolveCall = resolve
                rejectCall = reject
            }.fail { error in
                failCallCount++
                return
        }
        
        assertNotNil(resolveCall){
            resolveCall in
            resolveCall(value: 384)
        }
        assertNotNil(rejectCall){
            rejectCall in
            rejectCall(error: "OH NO")
        }
        
        XCTAssertEqual(0, failCallCount)
    }
    
    func testPledgesThatDoNotResolveOrRejectByTimeoutWillReject_DefaultTimeoutIsTiny() {
        let failExpectation = expectationWithDescription("fail occurred")
        let startTime = NSDate()
        Pledge<Int> { resolve, reject in
            }.fail { error in
                let duration = NSDate().timeIntervalSinceDate(startTime)
                failExpectation.fulfill()
                XCTAssert( duration >= 0.01, "Duration was \(duration)")
                assertEquals("Pledge did not resolve or reject before timeout of 0.01 second.", error)
        }
        
        waitForExpectationsWithTimeout(0.05, nil)
    }
    
    func testPledgesThatDoNotResolveOrRejectByTimeoutWillReject_DefaultTimeoutCanBeChanged() {
        let failExpectation = expectationWithDescription("fail occurred")
        let startTime = NSDate()
        Pledge<Int>(timeout: 0.5) { resolve, reject in
            }.fail { error in
                let duration = NSDate().timeIntervalSinceDate(startTime)
                failExpectation.fulfill()
                XCTAssert( duration >= 0.5, "Duration was \(duration)")
                assertEquals("Pledge did not resolve or reject before timeout of 0.5 second.", error)
        }
        
        waitForExpectationsWithTimeout(0.6, nil)
    }
    
    func testPledgeThatDoesNotFailShortlyAfterBeingRejectedWillAutomaticallyUseFallback(){
        let printExpectation = expectationWithDescription("fail occurred")
        let expectedError = "Oh no!"
        let originalFallback = pledgeFallbackReject
        pledgeFallbackReject = { error in
            printExpectation.fulfill()
            assertEquals("Uncaught Pledge failure: \(expectedError)", error)
        }
        Pledge<Int>.reject(expectedError)
        waitForExpectationsWithTimeout(0.01, nil)
        pledgeFallbackReject = originalFallback
    }
    
    func testPendingPledgeWillDispatchOnDefaultGlobalQueueAndResolveOnMainQueue(){
        let expectedValue = "Amazing answer from another wooooorld!"
        let resolveExpectation = expectationWithDescription("resolve occurred")
        let thenExpectation = expectationWithDescription("then occurred")
        
        let action : Pledge<String>.Action = { resolve, reject in
            resolveExpectation.fulfill()
            resolve(value: expectedValue)
        }
        let pledge = runOnBackground(action).then { value in
            thenExpectation.fulfill()
            assertEquals(expectedValue, value)
        }
        
        waitForExpectationsWithTimeout(10, nil)
    }
    
    func testPendingPledgeWillDispatchOnDefaultGlobalQueueAndRejectOnMainQueue(){
        let expectedValue = "Amazing answer from another wooooorld!"
        let resolveExpectation = expectationWithDescription("resolve occurred")
        let failExpectation = expectationWithDescription("fail occurred")
        
        let action : Pledge<String>.Action = { resolve, reject in
            resolveExpectation.fulfill()
            reject(error: expectedValue)
        }
        let pledge = runOnBackground(action).fail { value in
            failExpectation.fulfill()
            assertEquals(expectedValue, value)
        }
        
        waitForExpectationsWithTimeout(10, nil)
    }
    
    func testAllWillResolveWhenAllPromisesCompleteImmediately(){
        let value1 = 37
        let value2 = "Bobberino"
        let value3 = 9.78
        let pledge1 = Pledge(){ resolve, reject in resolve(value: value1) }
        let pledge2 = Pledge(){ resolve, reject in resolve(value: value2) }
        let pledge3 = Pledge(){ resolve, reject in resolve(value: value3) }
        
        let pledges : [Promise] = [pledge1, pledge2, pledge3]
        
        var thenCallCount=0
        let allPledge = all(promises: pledges)
        allPledge.then { value in
            thenCallCount++
            assertEquals(value1, value[0] as? Int)
            assertEquals(value2, value[1] as? String)
            assertEquals(value3, value[2] as? Double)
        }
        
        assertEquals(1, thenCallCount)
    }
    
    func testAllWillResolveWhenAllPromisesCompleteDelayedInOddOrder(){
        let value1 = 3684
        let value2 = "plops"
        let value3 = 2.1
        var resolve1 : Pledge<Int>.Resolve? = nil
        var resolve2 : Pledge<String>.Resolve? = nil
        var resolve3 : Pledge<Double>.Resolve? = nil
        let pledge1 = Pledge(){ resolve, reject in resolve1 = resolve }
        let pledge2 = Pledge(){ resolve, reject in resolve2 = resolve }
        let pledge3 = Pledge(){ resolve, reject in resolve3 = resolve }
        
        let pledges : [Promise] = [pledge1, pledge2, pledge3]
        
        var thenCallCount=0
        let allPledge = all(promises: pledges)
        allPledge.then { value in
            thenCallCount++
            assertEquals(value1, value[0] as? Int)
            assertEquals(value2, value[1] as? String)
            assertEquals(value3, value[2] as? Double)
        }
        assertEquals(0, thenCallCount)
        
        resolve2?(value: value2)
        resolve1?(value: value1)
        resolve3?(value: value3)
        
        assertEquals(1, thenCallCount)
    }
    
    func testAllWillRejectImmediatelyInFailFastMode(){
        var reject2 : Pledge<String>.Reject? = nil
        let pledge1 = Pledge<Int>(){ resolve, reject in }
        let pledge2 = Pledge<String>(){ resolve, reject in reject2 = reject }
        let pledge3 = Pledge<Double>(){ resolve, reject in }
        
        let pledges : [Promise] = [pledge1, pledge2, pledge3]
        
        var failCallCount=0
        let allPledge = all(failFast: true, promises: pledges)
        let expectedError = "oh noes a kid kicked it"
        allPledge.fail { error in
            failCallCount++
            assertEquals(expectedError, error)
        }
        assertEquals(0, failCallCount)
        reject2?(error: expectedError)
        assertEquals(1, failCallCount)
    }
    
    func testAllInAllErrorsModeWillCombineErrors_EverythingFails() {
        var reject1 : Pledge<Int>.Reject? = nil
        var reject2 : Pledge<String>.Reject? = nil
        var reject3 : Pledge<Double>.Reject? = nil
        let pledge1 = Pledge<Int>(){ resolve, reject in reject1 = reject}
        let pledge2 = Pledge<String>(){ resolve, reject in reject2 = reject }
        let pledge3 = Pledge<Double>(){ resolve, reject in reject3 = reject}
        
        let pledges : [Promise] = [pledge1, pledge2, pledge3]
        
        var failCallCount=0
        let allPledge = all(promises: pledges)
        let expectedError = "[\noh noes\na kid\nkicked it\n]"
        allPledge.fail { error in
            failCallCount++
            assertEquals(expectedError, error)
        }
        assertEquals(0, failCallCount)
        reject2?(error: "a kid")
        reject1?(error: "oh noes")
        assertEquals(0, failCallCount)
        reject3?(error: "kicked it")
        assertEquals(1, failCallCount)
    }
    
    func testAllInAllErrorsModeWillCombineErrors_SomethingsFail() {
        var reject1 : Pledge<Int>.Reject? = nil
        var resolve2 : Pledge<String>.Resolve? = nil
        var reject3 : Pledge<Double>.Reject? = nil
        let pledge1 = Pledge<Int>(){ resolve, reject in reject1 = reject}
        let pledge2 = Pledge<String>(){ resolve, reject in resolve2 = resolve}
        let pledge3 = Pledge<Double>(){ resolve, reject in reject3 = reject}
        
        let pledges : [Promise] = [pledge1, pledge2, pledge3]
        
        var failCallCount=0
        let allPledge = all(promises: pledges)
        let expectedError = "[\noh noes a kid\nkicked it\n]"
        allPledge.fail { error in
            failCallCount++
            assertEquals(expectedError, error)
        }
        assertEquals(0, failCallCount)
        reject1?(error: "oh noes a kid")
        reject3?(error: "kicked it")
        assertEquals(0, failCallCount)
        resolve2?(value: "lolz")
        assertEquals(1, failCallCount)
    }
    
    
    func testPledgeAllCanResolveWithDoubleTuple(){
        let value1 = 3684.9
        let value2 = "plops"
        var resolve1 : Pledge<Double>.Resolve? = nil
        var resolve2 : Pledge<String>.Resolve? = nil
        let pledge1 = Pledge(){ resolve, reject in resolve1 = resolve }
        let pledge2 = Pledge(){ resolve, reject in resolve2 = resolve }
        
        
        var thenCallCount=0
        let allPledge = all(promises: (pledge1, pledge2))
        allPledge.then { value in
            thenCallCount++
            assertEquals(value1, value.0)
            assertEquals(value2, value.1)
        }
        assertEquals(0, thenCallCount)
        
        resolve2?(value: value2)
        resolve1?(value: value1)
        
        assertEquals(1, thenCallCount)
    }
    
    func testPledgeAllCanRejectInFailFastModeWithDoubleTuple(){
        var reject2 : Pledge<String>.Reject? = nil
        let pledge1 = Pledge<Int>(){ resolve, reject in }
        let pledge2 = Pledge<String>(){ resolve, reject in reject2 = reject }
        
        var failCallCount=0
        let allPledge = all(failFast: true, promises: (pledge1, pledge2))
        let expectedError = "oh noes a kid kicked it"
        allPledge.fail { error in
            failCallCount++
            assertEquals(expectedError, error)
        }
        assertEquals(0, failCallCount)
        reject2?(error: expectedError)
        assertEquals(1, failCallCount)
    }
    
    func testPledgeAllCanResolveWithTripleTuple(){
        let value1 = 3684
        let value2 = "plops"
        let value3 = 2.1
        var resolve1 : Pledge<Int>.Resolve? = nil
        var resolve2 : Pledge<String>.Resolve? = nil
        var resolve3 : Pledge<Double>.Resolve? = nil
        let pledge1 = Pledge(){ resolve, reject in resolve1 = resolve }
        let pledge2 = Pledge(){ resolve, reject in resolve2 = resolve }
        let pledge3 = Pledge(){ resolve, reject in resolve3 = resolve }
        
        
        var thenCallCount=0
        let allPledge = all(promises: (pledge1, pledge2, pledge3))
        allPledge.then { value in
            thenCallCount++
            assertEquals(value1, value.0)
            assertEquals(value2, value.1)
            assertEquals(value3, value.2)
        }
        assertEquals(0, thenCallCount)
        
        resolve2?(value: value2)
        resolve1?(value: value1)
        resolve3?(value: value3)
        
        assertEquals(1, thenCallCount)
    }
    
    func testPledgeAllCanRejectWithTripleTuple(){
        var reject2 : Pledge<String>.Reject? = nil
        let pledge1 = Pledge<Int>(){ resolve, reject in }
        let pledge2 = Pledge<String>(){ resolve, reject in reject2 = reject }
        let pledge3 = Pledge<Double>(){ resolve, reject in }
        
        var failCallCount=0
        let allPledge = all(failFast: true, promises: (pledge1, pledge2, pledge3))
        let expectedError = "oh noes a kid kicked it"
        allPledge.fail { error in
            failCallCount++
            assertEquals(expectedError, error)
        }
        assertEquals(0, failCallCount)
        reject2?(error: expectedError)
        assertEquals(1, failCallCount)
    }
    
    func testPledgeAllWithEmptyArrayWillSucceedImmediately(){
        var failCallCount = 0
        var thenCallCount = 0
        let allPledge = all(promises: [Pledge<String>]())
        let expectedError = "oh noes a kid kicked it"
        allPledge
            .then { value in
                assertEquals(0, value.count)
                thenCallCount++
            }
            .fail { error in
                failCallCount++
                return
        }
        assertEquals(1, thenCallCount)
        assertEquals(0, failCallCount)
    }
    
    func testPromiseAllWithEmptyArrayWillSucceedImmediately(){
        var failCallCount = 0
        var thenCallCount = 0
        let allPledge = all(promises: [Promise]())
        let expectedError = "oh noes a kid kicked it"
        allPledge
            .then { value in
                assertEquals(0, value.count)
                thenCallCount++
            }
            .fail { error in
                failCallCount++
                return
        }
        assertEquals(1, thenCallCount)
        assertEquals(0, failCallCount)
    }
    
}