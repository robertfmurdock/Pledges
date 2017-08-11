//
//  Pledge.swift
//  Squarmy
//
//  Created by Robert Murdock on 8/14/14.
//  Copyright (c) 2014 Armoria Software. All rights reserved.
//
import Foundation

public protocol Promise {
    @discardableResult func when(then : @escaping ( _ value: Any) -> Void) -> Promise
    @discardableResult func when(fail : @escaping ( _ error : NSError) -> Void) -> Promise
}

public func runOnBackground<T>(_ action : @escaping Pledge<T>.Action) -> Pledge<T> {
    
    func backgroundAction(_ resolve: @escaping Pledge<T>.Resolve, reject : @escaping Pledge<T>.Reject){
        let mainQueueResolve : Pledge<T>.Resolve = { value in
            DispatchQueue.main.async {
                resolve(value)
            }
        }
        
        let mainQueueReject : Pledge<T>.Reject = { error in
            DispatchQueue.main.async {
                reject(error)
            }
        }
        
        let globalQueue = DispatchQueue.global()
        globalQueue.async{
            action(mainQueueResolve, mainQueueReject)
        }
    }
    
    return Pledge(action: backgroundAction)
}

public var pledgeFallbackReject: Pledge.Reject = { print($0) }

open class Pledge <T> : Promise {
    
    open class func resolve(_ value: T) -> Pledge<T> {
        return Pledge { resolve, reject in resolve( value) }
    }
    
    open class func reject(_ error: NSError) -> Pledge<T> {
        return Pledge { resolve, reject in reject(error)}
    }
    
    open class func isNil(_ value: T?) -> Pledge<T> {
        return isNil(value, error: NSError(domain: "Value was nil", code: 1, userInfo: nil))
    }
    
    open class func isNil(_ value: T?, error: NSError) -> Pledge<T> {
        return Pledge<T> { resolve, reject in
            if let theValue = value {
                resolve(theValue)
            } else {
                reject(error)
            }
        }
    }
    
    public typealias Return = T
    public typealias Resolve = (_ value: T) -> Void
    public typealias Reject = (_ error : NSError) -> Void
    public typealias Action = ( _ resolve : @escaping Resolve, _ reject : @escaping Reject) -> Void

    open fileprivate(set) var resolve : Resolve = { value in return }
    open fileprivate(set) var reject : Reject = { error in return }
    fileprivate let action : Action
    fileprivate var thenQueue = [Resolve]()
    fileprivate var failQueue = [Reject]()
    fileprivate var potentialResult : T?
    fileprivate var potentialError : NSError?
    fileprivate var failWasHandled = false
    
    public convenience init() {
        self.init(action: {reject, resolve in return })
    }
    
    public convenience init(action: @escaping Action){
        self.init(timeout: 0.01, action: action)
    }
    
    public convenience init(timeout: Double, timeoutQueue: DispatchQueue = DispatchQueue.main){
        self.init(timeout: timeout, action: {reject, resolve in return })
    }
    
    public init(timeout: Double, timeoutQueue: DispatchQueue = DispatchQueue.main, action : @escaping Action) {
        self.action = action
        self.resolve = { (value : T) in
            self.potentialResult = value
            
            for then in self.thenQueue {
                then(value)
            }
            self.thenQueue.removeAll(keepingCapacity: false)
        }
        self.reject = { (error : NSError ) in
            if self.potentialResult == nil {
                let hasNotAlreadyFailed = self.potentialError == nil
                if hasNotAlreadyFailed && self.failQueue.count == 0 {
                    timeoutQueue.asyncAfter(deadline: DispatchTime.now() + Double(Int64(timeout * 1000000000)) / Double(NSEC_PER_SEC)) {
                        if !self.failWasHandled {
                            pledgeFallbackReject(Error("Uncaught Pledge failure: \(error.localizedDescription)", code: 12, userInfo: error.userInfo))
                        }
                    }
                }
                self.potentialError = error
                
                for fail in self.failQueue {
                    fail(error)
                }
                self.failQueue.removeAll(keepingCapacity: false)
            }
        }
        
        action(self.resolve, self.reject)
        timeoutQueue.asyncAfter(deadline: DispatchTime.now() + Double(Int64(timeout * 1000000000)) / Double(NSEC_PER_SEC)) {
            if self.potentialResult == nil && self.potentialError == nil {
                self.reject(Error("Pledge did not resolve or reject before timeout of \(timeout) second.", code: 2))
            }
        }
    }
    
    @discardableResult open func then(_ then : @escaping Resolve) -> Pledge <T> {
        if let promiseResult = potentialResult {
            then(promiseResult)
        } else {
            thenQueue.append(then)
        }
        return self
    }
    
    @discardableResult open func then<K>(_ errorWrapper: String = "", _ convert: @escaping (_ value: T) -> K) -> Pledge<K> {
        return Pledge<K> { resolveAgain, rejectAgain in
            self.then { value in resolveAgain(convert(value)) }
            self.fail { error in
                rejectAgain(wrapError(errorWrapper, error: error)) }
        }
    }
    
    open func thenPledge<K>(_ errorWrapper: String = "", _ convert: @escaping (_ value: T) -> Pledge<K>) -> Pledge<K> {
        return Pledge<K> { resolveAgain, rejectAgain in
            self.then { value in
                let pledge = convert(value)
                pledge.then(resolveAgain).fail { error in
                    rejectAgain(wrapError(errorWrapper, error: error))
                }
            }
            self.fail { error in
                rejectAgain(wrapError(errorWrapper, error: error))
            }
        }
    }
    
    open func thenPledge<K>(_ errorWrapper: String = "", convert: @escaping (_ value: T, _ resolve : Pledge<K>.Resolve, _ reject : Pledge<K>.Reject) -> Void) -> Pledge<K> {
        return Pledge<K> { resolveAgain, rejectAgain in
            self.then { value in convert(value, resolveAgain, rejectAgain) }
            self.fail { error in rejectAgain(wrapError(errorWrapper, error: error)) }
        }
    }
    
    @discardableResult open func fail(_ fail : @escaping Reject) -> Pledge <T> {
        if let error = potentialError {
            failWasHandled = true
            fail(error)
        } else {
            failQueue.append(fail)
        }
        
        return self
    }
    
    open func when(then : @escaping ( _ value: Any) -> Void) -> Promise {
        let wrappedThen : Resolve = { value in
            then(value: value)
        }
        return self.then(wrappedThen)
    }
    
    open func when(fail : @escaping ( _ error : NSError) -> Void) -> Promise {
        return self.fail(fail)
    }
    
}

public func all<T1, T2>(_ failFast: Bool = false, promises : (Pledge<T1>, Pledge<T2>)) -> Pledge<(T1, T2)> {
    return Pledge() { resolve, reject in
        all(failFast, promises: [promises.0, promises.1])
            .then { value in resolve((value[0] as! T1, value[1] as! T2)) }
            .fail(reject)
        return
    }
}

public func all<T1, T2, T3>(_ failFast: Bool = false, promises : (Pledge<T1>, Pledge<T2>, Pledge<T3>)) -> Pledge<(T1, T2, T3)> {
    return Pledge() { resolve, reject in
        all(failFast, promises: [promises.0, promises.1, promises.2])
            .then { value in resolve((value[0] as! T1, value[1] as! T2, value[2] as! T3)) }
            .fail(reject)
        return
    }
}

public func all<T1, T2, T3, T4>(_ failFast: Bool = false, promises : (Pledge<T1>, Pledge<T2>, Pledge<T3>, Pledge<T4>))
    -> Pledge<(T1, T2, T3, T4)> {
        return Pledge() { resolve, reject in
            all(promises: [promises.0, promises.1, promises.2, promises.3])
                .then { value in
                    resolve((value[0] as! T1, value[1] as! T2, value[2] as! T3, value[3] as! T4))
                }
                .fail(reject)
            return
        }
}

public func all<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10>(_ failFast: Bool = false, promises :
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
                    resolve( (value1, value2, value3, value4, value5, value6, value7, value8, value9, value10))
                }
                .fail(reject)
            return
        }
}

public func all<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11>(_ failFast: Bool = false, promises :
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
                    resolve( (value1, value2, value3, value4, value5, value6, value7, value8, value9, value10, value11))
                }
                .fail(reject)
            return
        }
}

public typealias AnyErrorDescriber = (_ index: Int, _ errorDescription: String) -> String

public func all<T>(_ failFast: Bool = false, pledges : [Pledge<T>], errorWrapper: String = "Array error", describeErr: @escaping AnyErrorDescriber = { index, error in " [\(index)] <\(error)>"})
    -> Pledge<[T]> {
        if pledges.count == 0 {
            return Pledge.resolve([T]())
        } else {
            return connectPledges(failFast, pledges: pledges, errorWrapper: errorWrapper, describeErr: describeErr)
        }
}

private func connectPledges<T>(_ failFast: Bool, pledges : [Pledge<T>], errorWrapper: String, describeErr: @escaping AnyErrorDescriber) -> Pledge<[T]>
{
    return Pledge<[T]> { resolve, reject in
        var results = [Int : T]()
        var errors = [Int: NSError]()
        for (index, promise) in pledges.enumerated() {
            promise
                .then { value in
                    results[index] = value
                    if pledges.count == results.count {
                        resolve(convertIndexDictionaryToArray(results))
                    } else {
                        reportCumulativeError(results, errors: errors, pledgeCount: pledges.count, reject: reject)
                    }
                }
                .fail { error in
                    if failFast {
                        reject(wrap(errorWrapper, error: error, index: index, describeErr: describeErr))
                    } else {
                        errors[index] = wrap(errorWrapper, error: error, index: index, describeErr: describeErr)
                        reportCumulativeError(results, errors: errors, pledgeCount: pledges.count, reject: reject)
                    }
            }
        }
    }
}

public func wrapError(_ message: String, error: NSError) -> NSError {
    if message == "" {
        return error
    } else {
        var userInfo = error.userInfo
        userInfo[NSUnderlyingErrorKey] = error
        return Error(message + error.localizedDescription, code: error.code, userInfo: userInfo)
    }
}

private func wrap(_ message: String, error: NSError, index: Int, describeErr: AnyErrorDescriber) -> NSError {
    let description = "\(message)\(describeErr(index, error.localizedDescription))"
    if message == "" || description == error.localizedDescription {
        return error
    } else {
        var userInfo = error.userInfo
        userInfo[NSUnderlyingErrorKey] = error
        return Error(description, code:  error.code, userInfo: userInfo)
    }
}

private func convertIndexDictionaryToArray<T>(_ dictionary: [Int: T]) -> [T] {
    var finalResults = [T]()
    var keys = Array(dictionary.keys)
    keys.sort(by: { $0 < $1 })
    for key in keys {
        if let value = dictionary[key] {
            finalResults.append(value)
        }
    }
    return finalResults
}

private func reportCumulativeError<T>(_ results: [Int: T], errors: [Int: NSError], pledgeCount: Int, reject : Pledge<[T]>.Reject) {
    if (errors.count + results.count) == pledgeCount {
        if errors.count == 1 {
            reject(errors.values.first!)
        } else {
            var cumulativeError = "[\n"
            let errorArray = convertIndexDictionaryToArray(errors)
            for error in errorArray {
                cumulativeError += error.localizedDescription
                cumulativeError += "\n"
            }
            cumulativeError += "]"
            reject(Error(cumulativeError,code:  99, userInfo: [NSUnderlyingErrorKey: errorArray]))
        }
    }
}

private func Error(_ description: String, code: Int, userInfo: [AnyHashable: Any]? = nil) -> NSError {
    var revisedUserInfo: [AnyHashable: Any] = userInfo ?? [:]
    revisedUserInfo[NSLocalizedDescriptionKey] = description
    return NSError(domain: "Pledges", code: code, userInfo: revisedUserInfo)
}

public func all(_ failFast: Bool = false, promises : [Promise]) -> Pledge<[Any]>
{
    let pledges = promises.map { promise in
        Pledge<Any> { resolve, reject in
            promise.when(then: resolve)
            promise.when(fail: reject)
        }
    }
    return all(failFast, pledges: pledges, errorWrapper: "", describeErr: { index, error in error })
}

