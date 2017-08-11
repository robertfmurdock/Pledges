//
//  ArmorTestKit.swift
//  Pledges
//
//  Created by Robert Murdock on 1/24/15.
//  Copyright (c) 2015 Armoria Software. All rights reserved.
//
import XCTest

public func assertEquals <T : Equatable> (_ expected: T, actual:T?, file: StaticString = #file, line: UInt = #line ) {
    XCTAssert(expected == actual, "Expected: \(expected) was not: \(String(describing: actual))", file: file, line: line)
}

public func assertEquals <T : Equatable> (_ expected: T, _ actual:T, file: StaticString = #file, line: UInt = #line ) where T : CustomStringConvertible {
    XCTAssert(expected == actual, "Expected: \(expected.description) was not: \(actual.description)", file: file, line: line)
}

public func assertEquals <T : Equatable> (_ expected: T, _ actual:T?, file: StaticString = #file, line: UInt = #line ) where T : CustomStringConvertible {
    XCTAssert(expected == actual, "Expected: \(expected.description) was not: \(String(describing: actual?.description ?? nil))", file: file, line: line)
}

public func assertEquals <T : Equatable, K> (_ expected: T, _ actual:K , file: StaticString = #file, line: UInt = #line ) {
    if let checkedActual = actual as? T {
        XCTAssert(expected == checkedActual, "Expected: \(expected) was not: \(checkedActual)", file: file, line: line)
    } else {
        XCTFail("These were not of the same type \(expected) \(actual).", file: file, line: line)
    }
}

public func assertEquals <T : Equatable, K> (_ expected: T, _ actual:K? , file: StaticString = #file, line: UInt = #line ) {
    if let checkedActual = actual as? T {
        XCTAssert(expected == checkedActual, "Expected: \(expected) was not: \(checkedActual)", file: file, line: line)
    } else {
        XCTFail("These were not of the same type \(expected) \(String(describing: actual)).", file: file, line: line)
    }
}

public func assertSame <T : AnyObject> (_ expected: T, _ actual: T, file: StaticString = #file, line: UInt = #line ) {
    XCTAssert(expected === actual, "Expected: \(expected) was not: \(actual)", file: file, line: line)
}

public func assertSame <T : AnyObject, K> (_ expected: T, _ actual: K!, file: StaticString = #file, line: UInt = #line ) {
    if let checkedActual = actual as? T {
        XCTAssert(expected === checkedActual, "Expected: \(expected) was not: \(checkedActual)", file: file, line: line)
    } else {
        XCTFail("These were not of the same type. Expected: \(expected) Actual: \(actual)", file: file, line: line)
    }
}

public func assert <T : AnyObject> (expectedArray expected: Array<T>, hasSameContentsAs actual : Array<T>, file: StaticString = #file, line: UInt = #line ){
    assertSimilarArrays(expected, actual: actual, file: file, line: line, checkSimilarity: { expected, actual -> Bool in expected === actual })
}

public func assert <T : Equatable> (expectedArray expected: Array<T>, hasEqualContentsAs actual : Array<T>, file: StaticString = #file, line: UInt = #line ){
    assertSimilarArrays(expected, actual: actual, file: file, line: line, checkSimilarity: { expected, actual -> Bool in  expected == actual })
}

private func assertSimilarArrays<T>(_ expected : Array<T>, actual : Array<T>, file: StaticString = #file, line: UInt = #line, checkSimilarity: (T, T) -> Bool){
    if(expected.count == actual.count){
        for index in 0 ..< expected.count {
            let expectedItem = expected[index]
            let actualItem = actual[index]
            XCTAssert(checkSimilarity(expectedItem, actualItem), file: file, line: line)
        }
    } else {
        XCTFail("Unequal counts \(expected.count) vs \(actual.count)", file: file, line: line)
    }
}

public func assertEquals (_ expected: Double, _ actual : Double, delta: Double, file: StaticString = #file, line: UInt = #line ) {
    XCTAssert(abs(expected - actual) <= delta, "Actual: \(actual) was not within \(delta) of \(expected)", file: file, line: line)
}

public func assertEqualsImplementation <T : Equatable> (_ original : T, _ equal : T, _ notEqualObjects : [T], file: StaticString = #file, line: UInt = #line) {
    assertEquals(original, actual: original, file: file, line: line)
    assertEquals(original, actual: equal, file: file, line: line)
    assertEquals(equal, actual: original, file: file, line: line)
    
    for notEqual in notEqualObjects {
        XCTAssert(original != notEqual, "", file: file, line: line)
        XCTAssert(notEqual != original, "", file: file, line: line)
    }
}

public func assertNotNil <T>( _ candidate : T?, file: StaticString = #file, line: UInt = #line, _ andContinue : (_ withValue : T) -> Void = { value in return }) {
    if let value = candidate {
        andContinue(value)
    } else {
        XCTFail("Value was nil but should not have been.", file: file, line: line)
    }
}

public func assert<T : AnyObject>(_ collection: [T], hasOnlyThisObject expected: T, file: StaticString = #file, line: UInt = #line) {
    if collection.count == 1 && expected === collection[0] {
        return
    } else {
        XCTFail("Collection did not have that value: \(collection)", file: file, line: line)
    }
}

public func assertHasOneElement<Seq : Sequence>(_ collection: Seq, file: StaticString = #file, line: UInt = #line, _ andContinue : (_ withValue : Seq.Iterator.Element) -> Void = { value in return }) {
    
    let array = Array(collection)
    if array.count == 1 {
        andContinue(array[0])
    } else {
        XCTFail("Collection did not have that value: \(collection)", file: file, line: line)
    }
}

public func assertHasOneOfType<T, Seq : Sequence>(_ values: Seq, file: StaticString = #file, line: UInt = #line, _ andContinue : (_ withValue : T) -> Void = { value in return }) {
    for value in values {
        if let value = value as? T {
            andContinue(value)
            return
        }
    }
    XCTFail("Collection did not have value of type \(T.self).", file: file, line: line)
}

public struct ReturnWhen<Args, Return> {
    public typealias WhenMatches = (_ args: Args) -> Bool
    public let value: Return
    public let when: [WhenMatches]
}

public struct Spy<Args, Return> {
    public typealias WhenMatches = (_ args: Args) -> Bool
    public typealias Comparison = (_ expectedArgs: Args, _ candidateArgs: Args) -> Bool
    public var calls = [Args]()
    
    public var returnValuesWhen = [ReturnWhen<Args, Return>]()
    
    public var defaultReturn: Return
    public var standardArgsComparators: [Comparison]?
    
    public init(defaultReturn: Return, argComparators: [Comparison]? = nil){
        self.defaultReturn = defaultReturn
        self.standardArgsComparators = argComparators
    }
    
    public mutating func call(args: Args) -> Return {
        calls.append(args)
        
        for returnWhen in returnValuesWhen {
            if allMatch(returnWhen, args: args) {
                return returnWhen.value
            }
        }
        
        return self.defaultReturn
    }
    
    public var wasCalled: Bool {
        get { return calls.count > 0 }
    }
    
    fileprivate func allMatch(_ matchRequirements: ReturnWhen<Args, Return>, args: Args) -> Bool{
        for requirement in matchRequirements.when {
            if !requirement(args) {
                return false
            }
        }
        return true
    }
    
    fileprivate func allMatch(_ matchRequirements: [WhenMatches]) -> WhenMatches {
        return {
            for when in matchRequirements {
                if !when($0) {
                    return false
                }
            }
            return true
        }
    }
    
    public mutating func returnValue(_ value: Return, when matchRequirements: WhenMatches...){
        let tuple = ReturnWhen(value: value, when: matchRequirements)
        self.returnValuesWhen.append(tuple)
    }
    
    public mutating func returnValue(_ value: Return, whenCalledWith args: Args){
        if let standardArgsComparisons = self.standardArgsComparators {
            let matchers = convertComparisonsToMatchers(args, argsComparisons: standardArgsComparisons)
            let tuple = ReturnWhen(value: value, when: matchers)
            self.returnValuesWhen.append(tuple)
        }
        else {
            XCTFail("Unless you set the standard argument matchers, you can't use the simple return/value/when method. Sorry!")
        }
    }
    
    public func verify(wasCalledWithArgsThatMatch argsMatchers: [WhenMatches], file: StaticString = #file, line: UInt = #line) {
        XCTAssertTrue(isContainedIn(self.calls, that: allMatch(argsMatchers)),"Spy was not called with those args.", file: file, line: line)
    }
    
    public func isContainedIn<Seq : Sequence>(_ list: Seq, that matches: (Seq.Iterator.Element) -> Bool) -> Bool {
        if findWithIndexIn(list, that: matches) == nil {
            return false
        } else {
            return true
        }
    }
    
    public func findWithIndexIn<Seq : Sequence>(_ list: Seq, that matches: (Seq.Iterator.Element) -> Bool) -> (item: Seq.Iterator.Element, index: Int)? {
        for (index, candidate) in list.enumerated() {
            if matches(candidate) {
                return (candidate, index)
            }
        }
        return nil
    }
    
    public func verify(_ wasCalledWithArgs: Args, file: StaticString = #file, line: UInt = #line){
        if let standardArgsComparisons = self.standardArgsComparators {
            if self.calls.isEmpty {
                XCTFail("Spy was not called.", file: file, line: line)
            } else {
                let matchers = convertComparisonsToMatchers(wasCalledWithArgs, argsComparisons: standardArgsComparisons)
                verify(wasCalledWithArgsThatMatch: matchers, file: file, line: line)
            }
        } else {
            XCTFail("Unless you set the standard argument matchers, you can't use the simple verify method. Sorry!", file: file, line: line)
        }
    }
    
    public func convertComparisonsToMatchers(_ expectedArgs: Args, argsComparisons: [Comparison]) -> [WhenMatches] {
        return argsComparisons.map { comparison in
            return { candidateArgs in
                comparison(expectedArgs, candidateArgs)
            }
        }
    }
    
    public func verifyLastCallWas(_ wasCalledWithArgs: Args, file: StaticString = #file, line: UInt = #line){
        if let standardArgsComparisons = self.standardArgsComparators {
            
            let matchers = convertComparisonsToMatchers(wasCalledWithArgs, argsComparisons: standardArgsComparisons)
            if let last = self.calls.last {
                let matchCheck = allMatch(matchers)
                let success = matchCheck(last)
                XCTAssertTrue(success, "Last call did not match arguments. Expected: \(wasCalledWithArgs) Last: \(last)", file: file, line: line)
            } else {
                XCTFail("Spy was not called.", file: file, line: line)
            }
        } else {
            XCTFail("Unless you set the standard argument matchers, you can't use the simple verify method. Sorry!", file: file, line: line)
        }
    }
}
