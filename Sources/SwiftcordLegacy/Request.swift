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
        
        request.addValue(
          "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) discord/1.0.9211 Chrome/134.0.6998.205 Electron/35.3.0 Safari/537.36",
          forHTTPHeaderField: "User-Agent"
        )
        
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
