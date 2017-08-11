//
//  Collections.swift
//
//  Created by Robert Murdock on 8/10/14.
//  Copyright (c) 2014 Armoria Software. All rights reserved.
//

import Foundation

open class IterableRoll<T : AnyObject> : Sequence {
    public typealias Element = T
    
    fileprivate var items = [T]()
    
    public init(){
    }
    
    open func makeIterator() -> IndexingIterator<[T]> {
        return items.makeIterator()
    }
    
    open func add(_ item : T) {
        self.items.append(item);
    }
    
    open func remove(_ item : T) {
        for (index, itemCandidate) in self.items.enumerated() {
            if itemCandidate === item {
                items.remove(at: index)
            }
        }
    }
    
    open var isEmpty: Bool {
        get { return items.isEmpty}
    }
}

public func containsObject<Seq : Sequence> (_ list : Seq, _ item : Seq.Iterator.Element) -> Bool where Seq.Iterator.Element : AnyObject {
    if let _ = firstIndexOf(item, inList: list){
        return true
    } else {
        return false
    }
}

public func isContainedIn<Seq : Sequence>(_ list: Seq, that matches: (Seq.Iterator.Element) -> Bool) -> Bool {
    if findWithIndexIn(list, that: matches) == nil {
        return false
    } else {
        return true
    }
}

public func findIn<Seq : Sequence>(_ list: Seq, that matches: (Seq.Iterator.Element) -> Bool) -> Seq.Iterator.Element? {
    if let result = findWithIndexIn(list, that: matches) {
        return result.item
    } else {
        return nil
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

public func firstIndexOf<Seq : Sequence> (_ item : Seq.Iterator.Element, inList list : Seq) -> Int? where Seq.Iterator.Element : AnyObject {
    for (index, candidate) in list.enumerated() {
        if candidate === item {
            return index
        }
    }
    return nil
}
