//
//  File.swift
//  
//
//  Created by JWI on 15/10/2025.
//

import Foundation
import FoundationCompatKit

public extension SwiftcordLegacy {
    func request(_ endpoint: Endpoint, completion: @escaping (Any?, Error?) -> ()) {
        
        let url = URL(string: "https://discordapp.com/api/v9\(endpoint.httpInfo.url)")
        
        var request = URLRequest(url: url!)
        request.addValue(self.token, forHTTPHeaderField: "Authorization")
        request.httpMethod = endpoint.httpInfo.method.rawValue
        
        let task = self.session.dataTask(with: request) { data, response, error in
            if let data = data {
                do  {
                    let json = try JSONSerialization.jsonObject(with: data)
                    completion(json, nil)
                } catch {
                    
                }
            }
        }
        
        task.resume()
    }
}
