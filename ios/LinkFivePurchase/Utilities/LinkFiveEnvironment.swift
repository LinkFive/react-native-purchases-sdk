//
//  LinkFiveEnvironment.swift
//  LinkFivePurchases
//
//  Created by Tan Nghia La on 14.07.21.
//  Copyright © 2021 LinkFive. All rights reserved.
//

import Foundation

public enum LinkFiveEnvironment {
    case production
    case staging
    
    /// The url for the environment.
    var url: URL {
        switch self {
        case .production:
            return URL(string: "https://api.linkfive.io/api/")!
        case .staging:
            return URL(string: "https://api.staging.linkfive.io/api/")!
        }
    }
}
