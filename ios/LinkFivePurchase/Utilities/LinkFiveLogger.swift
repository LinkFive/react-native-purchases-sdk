//
//  LinkFiveLogger.swift
//  
//
//  Created by Tan Nghia La on 20.07.21.
//

import Foundation

struct LinkFiveLogger {
    
    /// Prints the given `object` only in debug mode.
    /// - Parameters:
    ///     - object: The object to print.
    static func debug(_ object: Any) {
        #if DEBUG
            debugPrint(object)
        #endif
    }
}
