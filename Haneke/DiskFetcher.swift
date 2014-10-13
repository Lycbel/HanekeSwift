//
//  DiskFetcher.swift
//  Haneke
//
//  Created by Joan Romano on 9/16/14.
//  Copyright (c) 2014 Haneke. All rights reserved.
//

import Foundation

extension Haneke {

    // It'd be better to define this in the DiskFetcher class but Swift doesn't allow to declare an enum in a generic type
    public struct DiskFetcherGlobals {
        
        public enum ErrorCode : Int {
            case InvalidData = -500
        }
        
    }
    
}

public class DiskFetcher<T : DataConvertible> : Fetcher<T> {
    
    let path : String
    var cancelled = false
    
    public init(path : String) {
        self.path = path
        let key = path
        super.init(key: key)
    }
    
    // MARK: Fetcher
    
    public override func fetch(failure fail : ((NSError?) -> ()), success succeed : (T.Result) -> ()) {
        self.cancelled = false
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), { [weak self] in
            if let strongSelf = self {
                strongSelf.privateFetch(fail, succeed)
            }
        })
    }
    
    public override func cancelFetch() {
        self.cancelled = true
    }
    
    // MARK: Private
    
    private func privateFetch(failure fail : ((NSError?) -> ()), success succeed : (T.Result) -> ()) {
        if self.cancelled {
            return
        }
        
        var error: NSError?
        let data = NSData.dataWithContentsOfFile(self.path, options: NSDataReadingOptions.allZeros, error: &error)
        if data == nil {
            dispatch_async(dispatch_get_main_queue()) {
                fail(error)
            }
            return
        }
        
        if self.cancelled {
            return
        }
        
        let thing : T.Result? = T.convertFromData(data)
        
        if thing == nil {
            let localizedFormat = NSLocalizedString("Failed to convert value from data at path %@", comment: "Error description")
            let description = String(format:localizedFormat, self.path)
            let error = Haneke.errorWithCode(Haneke.DiskFetcherGlobals.ErrorCode.InvalidData.toRaw(), description: description)
            dispatch_async(dispatch_get_main_queue()) {
                fail(error)
            }
            return
        }
        
        dispatch_async(dispatch_get_main_queue(), {
            if self.cancelled {
                return
            }
            succeed(thing!)
        })
        
        
    }
}

public extension Cache {
    
    public func fetch(#path : String, formatName : String = Haneke.CacheGlobals.OriginalFormatName,  failure fail : Fetch<T>.Failer? = nil, success succeed : Fetch<T>.Succeeder? = nil) -> Fetch<T> {
        let fetcher = DiskFetcher<T>(path: path)
        return self.fetch(fetcher: fetcher, formatName: formatName, failure: fail, success: succeed)
    }
    
}