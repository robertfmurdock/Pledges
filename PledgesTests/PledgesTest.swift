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
    
    func testNewPledgesAreCreatedWithAClosureThatIsCalledImmediately() {
        var actionWasCalled = false
        let _ = Pledge<String>(action: { (resolve, reject) in
            actionWasCalled = true
        })
        XCTAssertTrue(actionWasCalled)
    }
    
    func testNewPledgesCanBeCreatedWithTrailingClosuresToo() {
        var actionWasCalled = false
        let _ = Pledge<String>() { (resolve, reject) in
            actionWasCalled = true
        }
        XCTAssertTrue(actionWasCalled)
    }
    
    func testResolveThePledgeUsingTheResolveCallbackAndAnyThenClosuresWillResolveSubsequently(){
        var wasCalled = false
        let expectedString = "12383y3461634"
        Pledge() { resolve, reject in
            resolve(expectedString)
            }.then { value in
                wasCalled = true
                XCTAssertEqual(expectedString, value)
        }
        XCTAssertTrue(wasCalled)
    }
    
    func testTheResolveCallbackIsAlsoAccessibleViaThePledgeItself(){
        var wasCalled = false
        let expectedString = "12383y3461634"
        let pledge = Pledge<String>()
        XCTAssertFalse(wasCalled)

        pledge.resolve(expectedString)
        pledge.then { value in
                wasCalled = true
                XCTAssertEqual(expectedString, value)
        }
        
        XCTAssertTrue(wasCalled)
    }

    func testMultipleThenClosuresAreNotCalledUntilThePledgeResolves() {
        var thenCallCounters = [0, 0, 0]
        let expectedString = "asdfsd"
        let pledge = Pledge<String>()
        pledge.then { value in
            thenCallCounters[0] += 1
            XCTAssertEqual(expectedString, value)
        }.then { value in
            thenCallCounters[1] += 1
            XCTAssertEqual(expectedString, value)
        }.then { value in
            thenCallCounters[2] += 1
            XCTAssertEqual(expectedString, value)
        }

        for callCount in thenCallCounters {
            XCTAssertEqual(0, callCount)
        }

        pledge.resolve(expectedString)
        
        for callCount in thenCallCounters {
            XCTAssertEqual(1, callCount)
        }
    }
    
    func testWhenAPledgeIsResolvedASecondTimeThenClosuresAreNotCalled_PledgesOnlyFulfillOnce(){
        var thenCallCount = 0
        let expectedString = "3423"
        let pledge = Pledge<String>().then { value in
            thenCallCount+=1
            XCTAssertEqual(expectedString, value)
        }

        pledge.resolve(expectedString)
        pledge.resolve("Bad String")
        pledge.resolve("A second bad String")
        
        XCTAssertEqual(1, thenCallCount)
    }

    func testFailCallsAreResolvedImmediatelyWhenThePledgeIsAlreadyInError() {
        var errorCallCounters = [0, 0, 0]

        let expectedError = newError("38hfehf", code: 2)
        Pledge<Int>() { resolve, reject in
            reject(expectedError)
        }.fail { error in
            errorCallCounters[0] += 1
            XCTAssertEqual(expectedError, error)
        }.fail { error in
            errorCallCounters[1] += 1
            XCTAssertEqual(expectedError, error)
        }.fail { error in
            errorCallCounters[2] += 1
            XCTAssertEqual(expectedError, error)
        }

        for callCount in errorCallCounters {
            XCTAssertEqual(1, callCount)
        }
    }
    
    func testFailClosuresAreNotCalledUntilThePledgeRejects(){
        var errorCallCounters = [0, 0, 0]
        let expectedError = newError("asdfsd", code: 3)
        let pledge = Pledge<Double>().fail { value in
                errorCallCounters[0]+=1
                XCTAssertEqual(expectedError, value)
            }.fail{ value in
                errorCallCounters[1]+=1
                XCTAssertEqual(expectedError, value)
            }.fail{ value in
                errorCallCounters[2]+=1
                XCTAssertEqual(expectedError, value)
        }

        for callCount in errorCallCounters {
            XCTAssertEqual(0, callCount)
        }
        
        pledge.reject(expectedError)

        for callCount in errorCallCounters {
            XCTAssertEqual(1, callCount)
        }
    }
    
    func testWhenAPledgeIsRejectedASecondTimeNoFailesAreCalledBecauseThePledgeWasAlreadyBroken(){
        var failCallCount = 0
        let expectedError = newError("3423", code: 4)
        let pledge = Pledge<Int>().fail { value in
            failCallCount+=1
            XCTAssertEqual(expectedError, value)
        }
        
        pledge.reject(expectedError)
        pledge.reject(newError("Bad String", code: 5))
        pledge.reject(newError("A second bad String", code: 6))
        
        XCTAssertEqual(1, failCallCount)
    }
    
    func testIfRejectIsCalledAfterResolveFailClosuresAreNotInformed(){
        var failCallCount = 0
        let pledge = Pledge<Int>().fail { error in
            failCallCount+=1
            return
        }
        
        pledge.resolve(384)
        pledge.reject(newError("OH NO", code: 7))
        
        XCTAssertEqual(0, failCallCount)
    }
    
    func testAllWillResolveWhenAllPromisesCompleteImmediately(){
        let value1 = 37
        let value2 = "Bobberino"
        let value3 = 9.78
        let pledge1 = Pledge(){ resolve, reject in resolve(value1) }
        let pledge2 = Pledge(){ resolve, reject in resolve(value2) }
        let pledge3 = Pledge(){ resolve, reject in resolve(value3) }
        
        let pledges : [Promise] = [pledge1, pledge2, pledge3]
        
        var thenCallCount=0
        let allPledge = all(promises: pledges)
        allPledge.then { value in
            thenCallCount+=1
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
            thenCallCount+=1
            assertEquals(value1, value[0] as? Int)
            assertEquals(value2, value[1] as? String)
            assertEquals(value3, value[2] as? Double)
        }
        assertEquals(0, thenCallCount)
        
        resolve2?(value2)
        resolve1?(value1)
        resolve3?(value3)
        
        assertEquals(1, thenCallCount)
    }
    
    func testAllWillRejectImmediatelyInFailFastMode(){
        var reject2 : Pledge<String>.Reject? = nil
        let pledge1 = Pledge<Int>(){ resolve, reject in }
        let pledge2 = Pledge<String>(){ resolve, reject in reject2 = reject }
        let pledge3 = Pledge<Double>(){ resolve, reject in }
        
        let pledges : [Promise] = [pledge1, pledge2, pledge3]
        
        var failCallCount=0
        let allPledge = all(true, promises: pledges)
        let expectedError = newError("oh noes a kid kicked it", code: 11)
        allPledge.fail { error in
            failCallCount += 1
            assertEquals(expectedError, error)
        }
        assertEquals(0, failCallCount)
        reject2?(expectedError)
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
            failCallCount += 1
            assertEquals(expectedError, error.localizedDescription)
        }
        assertEquals(0, failCallCount)
        reject2?(newError("a kid", code: 12))
        reject1?(newError("oh noes", code: 13))
        assertEquals(0, failCallCount)
        reject3?(newError("kicked it", code: 14))
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
            failCallCount+=1
            assertEquals(expectedError, error.localizedDescription)
        }
        assertEquals(0, failCallCount)
        reject1?(newError("oh noes a kid", code: 15))
        reject3?(newError("kicked it", code: 14))
        assertEquals(0, failCallCount)
        resolve2?("lolz")
        assertEquals(1, failCallCount)
    }
    
    
    func testAllCanResolveWithDoubleTuple(){
        let value1 = 3684.9
        let value2 = "plops"
        var resolve1 : Pledge<Double>.Resolve? = nil
        var resolve2 : Pledge<String>.Resolve? = nil
        let pledge1 = Pledge(){ resolve, reject in resolve1 = resolve }
        let pledge2 = Pledge(){ resolve, reject in resolve2 = resolve }
        
        
        var thenCallCount=0
        let allPledge = all(promises: (pledge1, pledge2))
        allPledge.then { value in
            thenCallCount += 1
            assertEquals(value1, value.0)
            assertEquals(value2, value.1)
        }
        assertEquals(0, thenCallCount)
        
        resolve2?(value2)
        resolve1?(value1)
        
        assertEquals(1, thenCallCount)
    }
    
    func testAllCanRejectInFailFastModeWithDoubleTuple(){
        var reject2 : Pledge<String>.Reject? = nil
        let pledge1 = Pledge<Int>(){ resolve, reject in }
        let pledge2 = Pledge<String>(){ resolve, reject in reject2 = reject }
        
        var failCallCount=0
        let allPledge = all(true, promises: (pledge1, pledge2))
        let expectedError = newError("oh noes a kid kicked it", code: 16)
        allPledge.fail { error in
            failCallCount += 1
            assertEquals(expectedError, error)
        }
        assertEquals(0, failCallCount)
        reject2?(expectedError)
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
            thenCallCount+=1
            assertEquals(value1, value.0)
            assertEquals(value2, value.1)
            assertEquals(value3, value.2)
        }
        assertEquals(0, thenCallCount)
        
        resolve2?(value2)
        resolve1?(value1)
        resolve3?(value3)
        
        assertEquals(1, thenCallCount)
    }
    
    func testPledgeAllCanRejectWithTripleTuple(){
        var reject2 : Pledge<String>.Reject? = nil
        let pledge1 = Pledge<Int>(){ resolve, reject in }
        let pledge2 = Pledge<String>(){ resolve, reject in reject2 = reject }
        let pledge3 = Pledge<Double>(){ resolve, reject in }
        
        var failCallCount=0
        let allPledge = all(true, promises: (pledge1, pledge2, pledge3))
        let expectedError = newError("oh noes a kid kicked it", code: 19)
        allPledge.fail { error in
            failCallCount += 1
            assertEquals(expectedError, error)
        }
        assertEquals(0, failCallCount)
        reject2?(expectedError)
        assertEquals(1, failCallCount)
    }
    
    func testPledgeAllWithEmptyArrayWillSucceedImmediately(){
        var failCallCount = 0
        var thenCallCount = 0
        let allPledge = all(promises: [Pledge<String>]())
        allPledge
            .then { value in
                assertEquals(0, value.count)
                thenCallCount += 1
            }
            .fail { error in
                failCallCount+=1
                return
        }
        assertEquals(1, thenCallCount)
        assertEquals(0, failCallCount)
    }
    
    func testPromiseAllWithEmptyArrayWillSucceedImmediately(){
        var failCallCount = 0
        var thenCallCount = 0
        let allPledge = all(promises: [Promise]())

        allPledge
            .then { value in
                assertEquals(0, value.count)
                thenCallCount += 1
            }
            .fail { error in
                failCallCount+=1
                return
        }
        assertEquals(1, thenCallCount)
        assertEquals(0, failCallCount)
    }
    
    func testPendingPledgeWillDispatchOnDefaultGlobalQueueAndRejectOnMainQueue(){
        let expectedValue = newError("Amazing answer from another wooooorld!", code: 10)
        let resolveExpectation = expectation(description: "resolve occurred")
        let failExpectation = expectation(description: "fail occurred")
        
        let action : Pledge<String>.Action = { resolve, reject in
            resolveExpectation.fulfill()
            reject(expectedValue)
        }
        let _ = runOnBackground(action).fail { value in
            failExpectation.fulfill()
            assertEquals(expectedValue, value)
        }
        
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    func testPledgesThatDoNotResolveOrRejectByTimeoutWillReject_DefaultTimeoutIsShort() {
        let failExpectation = expectation(description: "fail occurred")
        let startTime = Date()
        Pledge<Int>().fail { error in
            let duration = NSDate().timeIntervalSince(startTime)
            failExpectation.fulfill()
            XCTAssert( duration >= 0.01, "Duration was \(duration)")
            assertEquals("Pledge did not resolve or reject before timeout of 0.01 second.", error.localizedDescription)
        }
        
        waitForExpectations(timeout: 0.05, handler: nil)
    }
    
    func testPledgesThatDoNotResolveOrRejectByTimeoutWillReject_TimeoutCanBeChanged() {
        let failExpectation = expectation(description: "fail occurred")
        let startTime = Date()
        Pledge<Int>(timeout: 0.5).fail { error in
            let duration = NSDate().timeIntervalSince(startTime)
            failExpectation.fulfill()
            XCTAssert( duration >= 0.5, "Duration was \(duration)")
            assertEquals("Pledge did not resolve or reject before timeout of 0.5 second.", error.localizedDescription)
        }
        
        waitForExpectations(timeout: 0.6, handler: nil)
    }
    
    func testPledgeThatDoesNotFailShortlyAfterBeingRejectedWillAutomaticallyUseFallback(){
        let printExpectation = expectation(description: "fail occurred")
        let expectedError = newError("Oh no!", code: 8)
        let originalFallback = pledgeFallbackReject
        pledgeFallbackReject = { error in
            printExpectation.fulfill()
            assertEquals("Uncaught Pledge failure: \(expectedError.localizedDescription)", error.localizedDescription)
        }
        _ = Pledge<Int>.reject(expectedError)
        waitForExpectations(timeout: 0.01, handler: nil)
        pledgeFallbackReject = originalFallback
    }
    
    func testPendingPledgeWillDispatchOnDefaultGlobalQueueAndResolveOnMainQueue(){
        let expectedValue = "Amazing answer from another wooooorld!"
        let resolveExpectation = expectation(description: "resolve occurred")
        let thenExpectation = expectation(description: "then occurred")
        
        let action : Pledge<String>.Action = { resolve, reject in
            resolveExpectation.fulfill()
            resolve(expectedValue)
        }
        let _ = runOnBackground(action)
            .then { value in
                thenExpectation.fulfill()
                assertEquals(expectedValue, value)
        }
        
        waitForExpectations(timeout: 10, handler: nil)
    }
}

func newError(_ description: String, code: Int) -> NSError {
    return NSError(domain: "PledgeTests", code: code, userInfo: [NSLocalizedDescriptionKey: description])
}
