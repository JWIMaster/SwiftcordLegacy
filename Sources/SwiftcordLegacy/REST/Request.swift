//
//  File.swift
//  
//
//  Created by JWI on 15/10/2025.
//

import Foundation
import FoundationCompatKit

public extension SLClient {
    func request(_ endpoint: Endpoint, body: [String: Any]? = nil, completion: @escaping (Any?, Error?) -> ()) {
        
        let url = URL(string: "https://discordapp.com/api/v9\(endpoint.httpInfo.url)")
        
        var request = URLRequest(url: url!)
        request.addValue(self.token, forHTTPHeaderField: "Authorization")
        
        request.addValue(
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) discord/1.0.9211 Chrome/134.0.6998.205 Electron/35.3.0 Safari/537.36",
            forHTTPHeaderField: "User-Agent"
        )
        
        request.httpMethod = endpoint.httpInfo.method.rawValue
        
        if let body = body {
            request.httpBody = body.createBody()
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        
        let task = self.session.dataTask(with: request) { data, response, error in
            if let data = data {
                do  {
                    let json = try JSONSerialization.jsonObject(with: data)
                    completion(json, nil)
                } catch {
                    NSLog("erm whoops")
                }
            }
        }
        
        task.resume()
    }
}


protocol JSONEncodable {
    func encode() -> String
    func createBody() -> Data?
}

extension Dictionary: JSONEncodable {}
extension Array: JSONEncodable {}

/// Make Dictionary & Array conform to Encodable
extension JSONEncodable {
    
    /// Encode Array | Dictionary -> JSON String
    func encode() -> String {
        let data = try? JSONSerialization.data(withJSONObject: self, options: [])
        return String(data: data!, encoding: .utf8)!
    }
    
    /// Create Data from Array | Dictionary to send over HTTP
    func createBody() -> Data? {
        let json = self.encode()
        return json.data(using: .utf8)
    }
}
