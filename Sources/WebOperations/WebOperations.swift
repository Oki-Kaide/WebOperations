//
//  WebOperations.swift
//  WebOperations
//
//  Created by Jacob Davis on 4/20/20.
//  Copyright (c) 2020 Proton Chain LLC, Delaware
//

import Foundation

public class WebOperations: NSObject, ObservableObject {
    
    public var operationQueueSeq: OperationQueue
    public var operationQueueMulti: OperationQueue
    public var customOperationQueues: [String: OperationQueue]
    public var session: URLSession
    
    @Published public var totalOperationCount = 0
    
    public enum RequestMethod: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case patch = "PATCH"
    }
    
    public enum Auth: String {
        case basic = "Basic"
        case bearer = "Bearer"
        case none = "none"
    }
    
    public enum ContentType: String {
        case applicationJson = "application/json"
        case none = ""
    }
    
    public static let shared = WebOperations()
    
    private override init() {

        session = URLSession(configuration: URLSessionConfiguration.default)
        
        operationQueueSeq = OperationQueue()
        operationQueueSeq.qualityOfService = .utility
        operationQueueSeq.maxConcurrentOperationCount = 1
        operationQueueSeq.name = "\(UUID()).seq"
        
        operationQueueMulti = OperationQueue()
        operationQueueMulti.qualityOfService = .utility
        operationQueueMulti.name = "\(UUID()).multi"
        
        customOperationQueues = [:]
        
    }
    
//    public func dbug() {
//        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
//
//            print("======")
//            print("SEQ => \(String(describing: self?.operationQueueSeq.operationCount))")
//            print("MULTI => \(String(describing: self?.operationQueueMulti.operationCount))")
//
//            if let customQueues = self?.customOperationQueues {
//                for queue in customQueues {
//                    print("CUSTOM => \(queue.key), \(queue.value.operationCount)")
//                    for op in queue.value.operations {
//                        print("CUSTOM OPERATION CLASS \(op)")
//                    }
//                }
//            }
//
//        }
//    }
    
    // MARK: - Operation Services
    
    public func addSeq(_ operation: BaseOperation,
                completion: ((Result<Any?, WebError>) -> Void)?) {
        
        operation.completion = completion
        operationQueueSeq.addOperation(operation)
        totalOperationCount += 1
        
    }
    
    public func addMulti(_ operation: BaseOperation,
                  completion: ((Result<Any?, WebError>) -> Void)?) {
        
        operation.completion = completion
        operationQueueMulti.addOperation(operation)
        totalOperationCount += 1
    }
    
    public func add(_ operation: BaseOperation,
                    toCustomQueueNamed queueName: String,
                    completion: ((Result<Any?, WebError>) -> Void)?) {
        
        if let queue = customOperationQueues[queueName] {
            operation.completion = completion
            queue.addOperation(operation)
            totalOperationCount += 1
        } else {
            completion?(.failure(WebError(message: "Custom Queue not found")))
        }
        
    }
    
    public func addCustomQueue(_ queue: OperationQueue, forKey key: String) {
        if let foundQueue = customOperationQueues.removeValue(forKey: key) {
            foundQueue.cancelAllOperations()
            queue.name = "\(key).\(UUID())"
            
        }
        customOperationQueues[key] = queue
    }
    
    public func removeCustomQueue(forKey key: String) {
        if let queue = customOperationQueues.removeValue(forKey: key) {
            queue.cancelAllOperations()
        }
    }
    
    public func suspendAllQueues(_ isSuspended: Bool) {
        operationQueueSeq.isSuspended = isSuspended
        operationQueueMulti.isSuspended = isSuspended
        for pair in customOperationQueues {
            pair.value.isSuspended = isSuspended
        }
    }
    
    public func cancelAllQueues() {
        operationQueueSeq.cancelAllOperations()
        operationQueueMulti.cancelAllOperations()
        for pair in customOperationQueues {
            pair.value.cancelAllOperations()
        }
    }
    
    public func cancel(queueForKey key: String) {
        if let foundQueue = customOperationQueues.removeValue(forKey: key) {
            foundQueue.cancelAllOperations()
        }
    }
    
    // MARK: - HTTP Base Requests
    
    public func request<E: Codable>(method: RequestMethod = .get, auth: Auth = .none, authValue: String? = nil, contentType: ContentType = .applicationJson, url: URL, parameters: [String: Any]? = nil, acceptableResponseCodeRange: ClosedRange<Int> = (200...299), timeoutInterval: TimeInterval = 30, errorModel: E.Type, completion: ((Result<Data?, WebError>) -> Void)?) {

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.timeoutInterval = timeoutInterval
        
        if let authValue = authValue, auth != .none {
            request.addValue("\(auth.rawValue) \(authValue)", forHTTPHeaderField: "Authorization")
        }

        if contentType == .applicationJson {
            request.addValue(contentType.rawValue, forHTTPHeaderField: "Content-Type")
            request.addValue(contentType.rawValue, forHTTPHeaderField: "Accept")
        }

        if let parameters = parameters, !parameters.isEmpty {
            do {
                let body = try JSONSerialization.data(withJSONObject: parameters, options: [])
                request.httpBody = body
            } catch {
                completion?(.failure(WebError(message: "Unable to construct body")))
                return
            }
        }

        let task = session.dataTask(with: request) { data, response, error in

            if let error = error {
                completion?(.failure(WebError(message: error.localizedDescription)))
                return
            }

            guard let data = data else {
                completion?(.failure(WebError(message: "No data")))
                return
            }

            guard let response = response as? HTTPURLResponse else {
                completion?(.failure(WebError(message: "No response")))
                return
            }

            if !acceptableResponseCodeRange.contains(response.statusCode) {
                
                if errorModel != NilErrorModel.self {

                    do {
                        let decoder = JSONDecoder()
                        let res = try decoder.decode(errorModel, from: data)
                        completion?(.failure(WebError(message: (res as? ErrorModelMessageProtocol)?.getMessage() ?? "", response: res, statusCode: response.statusCode)))
                    } catch {
                        completion?(.failure(WebError(message: "Unable to parse error response into object type given", statusCode: response.statusCode)))
                    }

                } else {
                    
                    var message: String = "Unacceptable response code: \(response.statusCode)"
                    
                    do {
                        let res = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                        if let res = res {
                            message = res.description
                        }
                    } catch {
                        print(error.localizedDescription)
                    }
                    
                    completion?(.failure(WebError(message: message, statusCode: response.statusCode)))
                    
                }
                
            } else {
                completion?(.success(data))
            }

        }

        task.resume()
        
    }

    public func request<T: Any, E: Codable>(method: RequestMethod = .get, auth: Auth = .none, authValue: String? = nil, contentType: ContentType = .applicationJson, url: URL, parameters: [String: Any]? = nil, acceptableResponseCodeRange: ClosedRange<Int> = (200...299), timeoutInterval: TimeInterval = 30, errorModel: E.Type, completion: ((Result<T?, WebError>) -> Void)?) {

        request(method: method, auth: auth, authValue: authValue, contentType: contentType, url: url, parameters: parameters, acceptableResponseCodeRange: acceptableResponseCodeRange, timeoutInterval: timeoutInterval, errorModel: errorModel) { result in

            switch result {

            case .success(let data):

                guard let data = data else {
                    completion?(.failure(WebError(message: "No data")))
                    return
                }

                do {
                    let json = try JSONSerialization.jsonObject(with: data, options: [])
                    completion?(.success(json as? T))
                } catch {
                    completion?(.failure(WebError(message: error.localizedDescription)))
                }

            case .failure(let error):
                completion?(.failure(error))

            }

        }

    }
    
    public func request<T: Codable, E: Codable>(method: RequestMethod = .get, auth: Auth = .none, authValue: String? = nil, contentType: ContentType = .applicationJson, url: URL, parameters: [String: Any]? = nil, acceptableResponseCodeRange: ClosedRange<Int> = (200...299), timeoutInterval: TimeInterval = 30, keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy = .useDefaultKeys, errorModel: E.Type, completion: ((Result<T, WebError>) -> Void)?) {

        request(method: method, auth: auth, authValue: authValue, contentType: contentType, url: url, parameters: parameters, acceptableResponseCodeRange: acceptableResponseCodeRange, timeoutInterval: timeoutInterval, errorModel: errorModel) { result in

            switch result {

            case .success(let data):

                guard let data = data else {
                    completion?(.failure(WebError(message: "No data")))
                    return
                }

                do {
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = keyDecodingStrategy
                    let res = try decoder.decode(T.self, from: data)
                    completion?(.success(res))
                } catch {
                    completion?(.failure(WebError(message: error.localizedDescription)))
                }

            case .failure(let error):
                completion?(.failure(error))
            }

        }

    }
    
    deinit {
        self.cancelAllQueues()
    }
}

public struct WebError: Error, LocalizedError {
    
    public let message: String
    public let response: Codable?
    public let statusCode: Int?

    public var errorDescription: String? {
        if let response = self.response as? ErrorModelMessageProtocol {
            return response.getMessage()
        } else {
            return message
        }
    }
    
    public init(message: String, response: Codable? = nil, statusCode: Int? = nil) {
        self.message = message
        self.statusCode = statusCode
        self.response = response
    }
    
}

public protocol ErrorModelMessageProtocol {
    func getMessage() -> String
}

public struct NilErrorModel: Codable {}
