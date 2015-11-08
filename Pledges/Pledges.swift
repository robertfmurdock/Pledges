//
//  Pledge.swift
//  Squarmy
//
//  Created by Robert Murdock on 8/14/14.
//  Copyright (c) 2014 Armoria Software. All rights reserved.
//
import Foundation

public protocol Promise {
    func when(then then : ( value: Any) -> Void) -> Promise
    func when(fail fail : ( error : NSError) -> Void) -> Promise
}

public func runOnBackground<T>(action : Pledge<T>.Action) -> Pledge<T> {
    
    func backgroundAction(resolve: Pledge<T>.Resolve, reject : Pledge<T>.Reject){
        let mainQueueResolve : Pledge<T>.Resolve = { value in
            dispatch_async(dispatch_get_main_queue()) {
                resolve(value: value)
            }
        }
        
        let mainQueueReject : Pledge<T>.Reject = { error in
            dispatch_async(dispatch_get_main_queue()) {
                reject(error: error)
            }
        }
        
        let globalQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
        dispatch_async(globalQueue){
            action(resolve: mainQueueResolve, reject: mainQueueReject)
        }
    }
    
    return Pledge(action: backgroundAction)
}

public var pledgeFallbackReject: Pledge.Reject = { print($0) }

public class Pledge <T> : Promise {
    
    public class func resolve(value: T) -> Pledge<T> {
        return Pledge { resolve, reject in resolve(value: value) }
    }
    
    public class func reject(error: NSError) -> Pledge<T> {
        return Pledge { resolve, reject in reject(error: error)}
    }
    
    public class func isNil(value: T?) -> Pledge<T> {
        return isNil(value, error: NSError(domain: "Value was nil", code: 1, userInfo: nil))
    }
    
    public class func isNil(value: T?, error: NSError) -> Pledge<T> {
        return Pledge<T> { resolve, reject in
            if let theValue = value {
                resolve(value: theValue)
            } else {
                reject(error: error)
            }
        }
    }
    
    public typealias Return = T
    public typealias Resolve = (value: T) -> Void
    public typealias Reject = (error : NSError) -> Void
    public typealias Action = (resolve : Resolve, reject : Reject) -> Void

    public private(set) var resolve : Resolve = { value in return }
    public private(set) var reject : Reject = { error in return }
    private let action : Action
    private var thenQueue = [Resolve]()
    private var failQueue = [Reject]()
    private var potentialResult : T?
    private var potentialError : NSError?
    private var failWasHandled = false
    
    public convenience init() {
        self.init(action: {reject, resolve in return })
    }
    
    public convenience init(action: Action){
        self.init(timeout: 0.01, action: action)
    }
    
    public convenience init(timeout: Double, timeoutQueue: dispatch_queue_t = dispatch_get_main_queue()){
        self.init(timeout: timeout, action: {reject, resolve in return })
    }
    
    public init(timeout: Double, timeoutQueue: dispatch_queue_t = dispatch_get_main_queue(), action : Action) {
        self.action = action
        self.resolve = { (value : T) in
            self.potentialResult = value
            
            for then in self.thenQueue {
                then(value:value)
            }
            self.thenQueue.removeAll(keepCapacity: false)
        }
        self.reject = { (error : NSError ) in
            if self.potentialResult == nil {
                let hasNotAlreadyFailed = self.potentialError == nil
                if hasNotAlreadyFailed && self.failQueue.count == 0 {
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(timeout * 1000000000)), timeoutQueue) {
                        if !self.failWasHandled {
                            pledgeFallbackReject(error: Error("Uncaught Pledge failure: \(error.localizedDescription)", code: 12, userInfo: error.userInfo))
                        }
                    }
                }
                self.potentialError = error
                
                for fail in self.failQueue {
                    fail(error: error)
                }
                self.failQueue.removeAll(keepCapacity: false)
            }
        }
        
        action(resolve : self.resolve, reject: self.reject)
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(timeout * 1000000000)), timeoutQueue) {
            if self.potentialResult == nil && self.potentialError == nil {
                self.reject(error: Error("Pledge did not resolve or reject before timeout of \(timeout) second.", code: 2))
            }
        }
    }
    
    public func then(then : Resolve) -> Pledge <T> {
        if let promiseResult = potentialResult {
            then(value : promiseResult)
        } else {
            thenQueue.append(then)
        }
        return self
    }
    
    public func then<K>(errorWrapper: String = "", _ convert: (value: T) -> K) -> Pledge<K> {
        return Pledge<K> { resolveAgain, rejectAgain in
            self.then { value in resolveAgain(value: convert(value: value)) }
            self.fail { error in
                rejectAgain(error: wrapError(errorWrapper, error: error)) }
        }
    }
    
    public func thenPledge<K>(errorWrapper: String = "", _ convert: (value: T) -> Pledge<K>) -> Pledge<K> {
        return Pledge<K> { resolveAgain, rejectAgain in
            self.then { value in
                let pledge = convert(value: value)
                pledge.then(resolveAgain).fail { error in
                    rejectAgain(error: wrapError(errorWrapper, error: error))
                }
            }
            self.fail { error in
                rejectAgain(error: wrapError(errorWrapper, error: error))
            }
        }
    }
    
    public func thenPledge<K>(errorWrapper: String = "", convert: (value: T, resolve : Pledge<K>.Resolve, reject : Pledge<K>.Reject) -> Void) -> Pledge<K> {
        return Pledge<K> { resolveAgain, rejectAgain in
            self.then { value in convert(value: value, resolve: resolveAgain, reject: rejectAgain) }
            self.fail { error in rejectAgain(error: wrapError(errorWrapper, error: error)) }
        }
    }
    
    public func fail(fail : Reject) -> Pledge <T> {
        if let error = potentialError {
            failWasHandled = true
            fail(error: error)
        } else {
            failQueue.append(fail)
        }
        
        return self
    }
    
    public func when(then then : ( value: Any) -> Void) -> Promise {
        let wrappedThen : Resolve = { value in
            then(value: value)
        }
        return self.then(wrappedThen)
    }
    
    public func when(fail fail : ( error : NSError) -> Void) -> Promise {
        return self.fail(fail)
    }
    
}

public func all<T1, T2>(failFast: Bool = false, promises : (Pledge<T1>, Pledge<T2>)) -> Pledge<(T1, T2)> {
    return Pledge() { resolve, reject in
        all(failFast, promises: [promises.0, promises.1])
            .then { value in resolve(value: (value[0] as! T1, value[1] as! T2)) }
            .fail(reject)
        return
    }
}

public func all<T1, T2, T3>(failFast: Bool = false, promises : (Pledge<T1>, Pledge<T2>, Pledge<T3>)) -> Pledge<(T1, T2, T3)> {
    return Pledge() { resolve, reject in
        all(failFast, promises: [promises.0, promises.1, promises.2])
            .then { value in resolve(value: (value[0] as! T1, value[1] as! T2, value[2] as! T3)) }
            .fail(reject)
        return
    }
}

public func all<T1, T2, T3, T4>(failFast: Bool = false, promises : (Pledge<T1>, Pledge<T2>, Pledge<T3>, Pledge<T4>))
    -> Pledge<(T1, T2, T3, T4)> {
        return Pledge() { resolve, reject in
            all(promises: [promises.0, promises.1, promises.2, promises.3])
                .then { value in
                    resolve(value: (value[0] as! T1, value[1] as! T2, value[2] as! T3, value[3] as! T4))
                }
                .fail(reject)
            return
        }
}

public func all<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10>(failFast: Bool = false, promises :
    (Pledge<T1>, Pledge<T2>, Pledge<T3>, Pledge<T4>, Pledge<T5>,
    Pledge<T6>, Pledge<T7>, Pledge<T8>, Pledge<T9>, Pledge<T10>)) -> Pledge<(T1, T2, T3, T4, T5, T6, T7, T8, T9, T10)> {
        return Pledge() { resolve, reject in
            all(failFast, promises: [promises.0, promises.1, promises.2, promises.3, promises.4, promises.5, promises.6, promises.7, promises.8, promises.9])
                .then { value in
                    let value1 = value[0] as! T1
                    let value2 = value[1] as! T2
                    let value3 = value[2] as! T3
                    let value4 = value[3] as! T4
                    let value5 = value[4] as! T5
                    let value6 = value[5] as! T6
                    let value7 = value[6] as! T7
                    let value8 = value[7] as! T8
                    let value9 = value[8] as! T9
                    let value10 = value[9] as! T10
                    resolve( value: (value1, value2, value3, value4, value5, value6, value7, value8, value9, value10))
                }
                .fail(reject)
            return
        }
}

public func all<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11>(failFast: Bool = false, promises :
    (Pledge<T1>, Pledge<T2>, Pledge<T3>, Pledge<T4>, Pledge<T5>,
    Pledge<T6>, Pledge<T7>, Pledge<T8>, Pledge<T9>, Pledge<T10>, Pledge<T11>)) -> Pledge<(T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11)> {
        return Pledge() { resolve, reject in
            all(promises: [promises.0, promises.1, promises.2, promises.3, promises.4, promises.5, promises.6, promises.7, promises.8, promises.9, promises.10])
                .then { value in
                    let value1 = value[0] as! T1
                    let value2 = value[1] as! T2
                    let value3 = value[2] as! T3
                    let value4 = value[3] as! T4
                    let value5 = value[4] as! T5
                    let value6 = value[5] as! T6
                    let value7 = value[6] as! T7
                    let value8 = value[7] as! T8
                    let value9 = value[8] as! T9
                    let value10 = value[9] as! T10
                    let value11 = value[10] as! T11
                    resolve( value: (value1, value2, value3, value4, value5, value6, value7, value8, value9, value10, value11))
                }
                .fail(reject)
            return
        }
}

public typealias AnyErrorDescriber = (index: Int, errorDescription: String) -> String

public func all<T>(failFast: Bool = false, pledges : [Pledge<T>], errorWrapper: String = "Array error", describeErr: AnyErrorDescriber = { index, error in " [\(index)] <\(error)>"})
    -> Pledge<[T]> {
        if pledges.count == 0 {
            return Pledge.resolve([T]())
        } else {
            return connectPledges(failFast, pledges: pledges, errorWrapper: errorWrapper, describeErr: describeErr)
        }
}

private func connectPledges<T>(failFast: Bool, pledges : [Pledge<T>], errorWrapper: String, describeErr: AnyErrorDescriber) -> Pledge<[T]>
{
    return Pledge<[T]> { resolve, reject in
        var results = [Int : T]()
        var errors = [Int: NSError]()
        for (index, promise) in pledges.enumerate() {
            promise
                .then { value in
                    results[index] = value
                    if pledges.count == results.count {
                        resolve(value: convertIndexDictionaryToArray(results))
                    } else {
                        reportCumulativeError(results, errors: errors, pledgeCount: pledges.count, reject: reject)
                    }
                }
                .fail { error in
                    if failFast {
                        reject(error: wrap(errorWrapper, error: error, index: index, describeErr: describeErr))
                    } else {
                        errors[index] = wrap(errorWrapper, error: error, index: index, describeErr: describeErr)
                        reportCumulativeError(results, errors: errors, pledgeCount: pledges.count, reject: reject)
                    }
            }
        }
    }
}

public func wrapError(message: String, error: NSError) -> NSError {
    if message == "" {
        return error
    } else {
        var userInfo = error.userInfo ?? [:]
        userInfo[NSUnderlyingErrorKey] = error
        return Error(message + error.localizedDescription, code: error.code, userInfo: userInfo)
    }
}

private func wrap(message: String, error: NSError, index: Int, describeErr: AnyErrorDescriber) -> NSError {
    let description = "\(message)\(describeErr(index: index, errorDescription: error.localizedDescription))"
    if message == "" || description == error.localizedDescription {
        return error
    } else {
        var userInfo = error.userInfo ?? [:]
        userInfo[NSUnderlyingErrorKey] = error
        return Error(description, code:  error.code, userInfo: userInfo)
    }
}

private func convertIndexDictionaryToArray<T>(dictionary: [Int: T]) -> [T] {
    var finalResults = [T]()
    var keys = Array(dictionary.keys)
    keys.sortInPlace({ $0 < $1 })
    for key in keys {
        if let value = dictionary[key] {
            finalResults.append(value)
        }
    }
    return finalResults
}

private func reportCumulativeError<T>(results: [Int: T], errors: [Int: NSError], pledgeCount: Int, reject : Pledge<[T]>.Reject) {
    if (errors.count + results.count) == pledgeCount {
        if errors.count == 1 {
            reject(error: errors.values.first!)
        } else {
            var cumulativeError = "[\n"
            let errorArray = convertIndexDictionaryToArray(errors)
            for error in errorArray {
                cumulativeError += error.localizedDescription
                cumulativeError += "\n"
            }
            cumulativeError += "]"
            reject(error: Error(cumulativeError,code:  99, userInfo: [NSUnderlyingErrorKey: errorArray]))
        }
    }
}

private func Error(description: String, code: Int, userInfo: [NSObject : AnyObject]? = nil) -> NSError {
    var revisedUserInfo: [NSObject : AnyObject] = userInfo ?? [:]
    revisedUserInfo[NSLocalizedDescriptionKey] = description
    return NSError(domain: "Pledges", code: code, userInfo: revisedUserInfo)
}

public func all(failFast: Bool = false, promises : [Promise]) -> Pledge<[Any]>
{
    let pledges = promises.map { promise in
        Pledge<Any> { resolve, reject in
            promise.when(then: resolve)
            promise.when(fail: reject)
        }
    }
    return all(failFast, pledges: pledges, errorWrapper: "", describeErr: { index, error in error })
}

