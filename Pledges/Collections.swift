//
//  Collections.swift
//
//  Created by Robert Murdock on 8/10/14.
//  Copyright (c) 2014 Armoria Software. All rights reserved.
//

import Foundation

public class IterableRoll<T : AnyObject> : SequenceType {
    public typealias Element = T
    
    private var items = [T]()
    
    public init(){
    }
    
    public func generate() -> IndexingGenerator<[T]> {
        return items.generate()
    }
    
    public func add(item : T) {
        self.items.append(item);
    }
    
    public func remove(item : T) {
        for (index, itemCandidate) in enumerate(self.items) {
            if itemCandidate === item {
                items.removeAtIndex(index)
            }
        }
    }
    
    public var isEmpty: Bool {
        get { return items.isEmpty}
    }
}

public func containsObject<Seq : SequenceType where Seq.Generator.Element : AnyObject> (list : Seq, item : Seq.Generator.Element) -> Bool {
    if let index = firstIndexOf(item, inList: list){
        return true
    } else {
        return false
    }
}

public func isContainedIn<Seq : SequenceType>(list: Seq, that matches: (Seq.Generator.Element) -> Bool) -> Bool {
    if findWithIndexIn(list, that: matches) == nil {
        return false
    } else {
        return true
    }
}

public func findIn<Seq : SequenceType>(list: Seq, that matches: (Seq.Generator.Element) -> Bool) -> Seq.Generator.Element? {
    if let result = findWithIndexIn(list, that: matches) {
        return result.item
    } else {
        return nil
    }
}

public func findWithIndexIn<Seq : SequenceType>(list: Seq, that matches: (Seq.Generator.Element) -> Bool) -> (item: Seq.Generator.Element, index: Int)? {
    for (index, candidate) in enumerate(list) {
        if matches(candidate) {
            return (candidate, index)
        }
    }
    return nil
}

public func firstIndexOf<Seq : SequenceType where Seq.Generator.Element : AnyObject> (item : Seq.Generator.Element, inList list : Seq) -> Int? {
    for (index, candidate) in enumerate(list) {
        if candidate === item {
            return index
        }
    }
    return nil
}