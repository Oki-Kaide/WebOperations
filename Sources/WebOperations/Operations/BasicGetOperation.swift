//
//  BasicGetOperation.swift
//  WebOperations
//
//  Created by Jacob Davis on 4/20/20.
//  Copyright (c) 2020 Proton Chain LLC, Delaware
//

import Foundation

class BasicGetOperation: BaseOperation {
    
    var urlString: String
    
    init(urlString: String) {
        self.urlString = urlString
    }
    
    override func main() {
        
        super.main()
        
        guard let url = URL(string: self.urlString) else {
            self.finish(retval: nil, error: WebError(message: "Unable to form URL for \(self.urlString)"))
            return
        }

        WebOperations.shared.request(url: url, errorModel: NilErrorModel.self) { (result: Result<[String: Any]?, WebError>) in
            switch result {
            case .success(let res):
                if let res = res {
                    self.finish(retval: res, error: nil)
                } else {
                    self.finish(retval: nil, error: WebError(message: "An error occured"))
                }
            case .failure(let error):
                self.finish(retval: nil, error: error)
            }
        }
        
    }
    
}
