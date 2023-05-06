//
//  BaseOperation
//  WebOperations
//
//  Created by Jacob Davis on 4/20/20.
//  Copyright (c) 2020 Proton Chain LLC, Delaware
//

import Foundation

/**
Create your own Operations be inheriting from BaseOperation. Checkout BasicGetOperation.swift for an example
*/
open class BaseOperation: Operation {
    
    public var baseOperation: BaseOperation!
    public var completion: ((Result<Any?, WebError>) -> Void)!
    
    public override init() {}
    
    public convenience init(_ completion: @escaping ((Result<Any?, WebError>) -> Void)) {
        self.init()
        self.completion = completion
    }
    
    private var _executing: Bool = false
    open override var isExecuting: Bool {
        get { return _executing }
        set {
            guard _executing != newValue else { return }
            willChangeValue(forKey: "isExecuting")
            _executing = newValue
            didChangeValue(forKey: "isExecuting")
        }
    }

    private var _finished: Bool = false
    open override var isFinished : Bool {
        get { return _finished }
        set {
            guard _finished != newValue else { return }
            willChangeValue(forKey: "isFinished")
            _finished = newValue
            didChangeValue(forKey: "isFinished")
        }
    }
    
    private var _cancelled: Bool = false
    open override var isCancelled: Bool {
        get { return _cancelled }
        set {
            guard _cancelled != newValue else { return }
            willChangeValue(forKey: "isCancelled")
            _cancelled = newValue
            didChangeValue(forKey: "isCancelled")
        }
    }
    
    open override func main() {
        
        guard isCancelled == false else {
            finish()
            return
        }
        
        isExecuting = false
        
    }

    open func finish(retval: Any? = nil, error: WebError? = nil) {
        DispatchQueue.main.async {
            if self.isCancelled {
                self.completion?(.failure(WebError(message: "Operation Cancelled")))
            } else if let error = error {
                self.completion?(.failure(error))
            } else {
                self.completion?(.success(retval))
            }
            WebOperations.shared.totalOperationCount -= 1
        }
        isExecuting = false
        isFinished = true

    }
    
    open func finish<T: Codable>(retval: T? = nil, error: WebError? = nil) {
        DispatchQueue.main.async {
            if self.isCancelled {
                self.completion?(.failure(WebError(message: "Operation Cancelled")))
            } else if let error = error {
                self.completion?(.failure(error))
            } else {
                self.completion?(.success(retval))
            }
            WebOperations.shared.totalOperationCount -= 1
        }
        isExecuting = false
        isFinished = true
    }
    
}
