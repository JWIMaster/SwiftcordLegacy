//
//  File.swift
//  
//
//  Created by JWI on 15/10/2025.
//

import Foundation
import FoundationCompatKit

public extension SLClient {
    
    // Store rate limit info per endpoint
    private struct RateLimitInfo {
        var remaining: Int
        var reset: TimeInterval
        var retryAfter: TimeInterval
    }
    
    private static var rateLimits: [String: RateLimitInfo] = [:]

    func request(_ endpoint: Endpoint, body: [String: Any]? = nil, completion: @escaping (Any?, Error?) -> ()) {
        
        // Check if we have rate limit info for this endpoint
        if let limitInfo = Self.rateLimits[endpoint.httpInfo.url] {
            let now = Date().timeIntervalSince1970
            if limitInfo.remaining <= 0 && now < limitInfo.reset {
                let waitTime = limitInfo.reset - now
                NSLog("[RateLimit] Waiting \(waitTime) seconds to respect rate limit for \(endpoint.httpInfo.url)")
                DispatchQueue.global(qos: .default).asyncAfter(deadline: .now() + waitTime) {
                    self.request(endpoint, body: body, completion: completion)
                }
                return
            }
        }
        
        guard let url = URL(string: "https://discordapp.com/api/v9\(endpoint.httpInfo.url)") else {
            completion(nil, NSError(domain: "SLClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
            return
        }
        
        var request = URLRequest(url: url)
        request.addValue(self.token, forHTTPHeaderField: "Authorization")
        request.addValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.httpMethod = endpoint.httpInfo.method.rawValue
        
        if let body = body {
            request.httpBody = body.createBody()
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        
        let task = self.session.dataTask(with: request) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse {
                self.logRateLimitInfo(response: httpResponse)
                
                // Update rate limit info
                let remaining = Int(httpResponse.allHeaderFields["X-RateLimit-Remaining"] as? String ?? "1") ?? 1
                let reset = TimeInterval(httpResponse.allHeaderFields["X-RateLimit-Reset"] as? String ?? "0") ?? 0
                let retryAfter = TimeInterval(httpResponse.allHeaderFields["Retry-After"] as? String ?? "0") ?? 0
                
                Self.rateLimits[endpoint.httpInfo.url] = RateLimitInfo(
                    remaining: remaining,
                    reset: reset,
                    retryAfter: retryAfter
                )
                
                // If server tells us to retry after, schedule retry
                if retryAfter > 0 {
                    DispatchQueue.global(qos: .default).asyncAfter(deadline: .now() + retryAfter) {
                        self.request(endpoint, body: body, completion: completion)
                    }
                    return
                }
            }
            
            if let data = data {
                do  {
                    let json = try JSONSerialization.jsonObject(with: data)
                    completion(json, nil)
                } catch {
                    NSLog("Failed to parse JSON: \(error)")
                    completion(nil, error)
                }
            } else if let error = error {
                completion(nil, error)
            }
        }
        
        task.resume()
    }
    
    
    func logRateLimitInfo(response: HTTPURLResponse) {
        if let limit = response.allHeaderFields["X-RateLimit-Limit"] {
            print("[RateLimit] Limit:", limit)
            logger.log("[RateLimit] Limit: \(limit)")
        }
        if let remaining = response.allHeaderFields["X-RateLimit-Remaining"] {
            print("[RateLimit] Remaining:", remaining)
            logger.log("[RateLimit] Remaining: \(remaining)")
        }
        if let reset = response.allHeaderFields["X-RateLimit-Reset"] {
            print("[RateLimit] Reset:", reset)
            logger.log("[RateLimit] Reset: \(reset)")
        }
        if let retryAfter = response.allHeaderFields["Retry-After"] {
            print("[RateLimit] Retry-After (ms):", retryAfter)
            logger.log("[RateLimit] Retry-After (ms): \(retryAfter)")
        }
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
