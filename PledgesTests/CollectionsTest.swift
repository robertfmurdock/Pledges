//
//  CollectionsTests.swift
//  Squarmy
//
//  Created by Robert Murdock on 8/10/14.
//  Copyright (c) 2014 Armoria Software. All rights reserved.
//

import Foundation
import Pledges
import XCTest
import ArmorTestKit

class IterableRollTest : XCTestCase {
    
    class StubObject {
    }
    
    func testBunchStartsEmpty()  {
        let bunch : IterableRoll<StubObject> = IterableRoll()
        
        var generator = bunch.makeIterator()
        XCTAssertTrue(generator.next() == nil)
    }
    
    func testAdd()  {
        let bunch = IterableRoll<StubObject>()
        let items = [ StubObject(), StubObject(), StubObject() ]
        for  item in items {
            bunch.add(item)
        }
        assert(expectedArray: items, hasSameContentsAs: Array(bunch))
    }
    
    func testRemove()  {
        let bunch = IterableRoll<StubObject>()
        let object1 = StubObject()
        let object2 = StubObject()
        bunch.add(object1)
        bunch.add(object2)
        bunch.remove(object1)
        let expected = [ object2 ]
        assert(expectedArray: expected, hasSameContentsAs: Array(bunch))
    }
    
    func testCanRemoveAndAddWhileIteratingSafely_AddedItemsAreNotIteratedOver()
    {
        let bunch = IterableRoll<StubObject>()
        let object1 = StubObject()
        let object2 = StubObject()
        
        bunch.add(object1)
        bunch.add(object2)
        
        var iteratedObjects = [StubObject]()
        for object in bunch {
            bunch.remove(object2)
            bunch.add(StubObject())
            
            iteratedObjects.append(object)
        }
        
        assert(expectedArray: [object1, object2], hasSameContentsAs: iteratedObjects)
    }
    
}
