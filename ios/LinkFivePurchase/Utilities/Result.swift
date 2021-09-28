//
//  Result.swift
//  LinkFivePurchases
//
//  Created by Tan Nghia La on 14.07.21.
//  Copyright © 2021 LinkFive. All rights reserved.
//

import Foundation

public enum Result<T> {
    
    case success(T)
    case failure(Error)
    
    /// The value of the result.
    public var value: T? {
        switch self {
        case .success(let value):
            return value
        default:
            return nil
        }
    }
    
    /// The error of the result.
    public var error: Error? {
        switch self {
        case .failure(let error):
            return error
        default:
            return nil
        }
    }
}
