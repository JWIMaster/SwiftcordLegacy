import Foundation
import FoundationCompatKit
import UIKit

public struct Attachment {
    public let id: Snowflake?
    public let filename: String?
    public let url: URL?
    public let proxyURL: URL?
    public let size: Int?
    public let height: Int?
    public let width: Int?
    public let contentType: String?
    
    public init(_ json: [String: Any]) {
        self.id = Snowflake(json["id"])
        self.filename = json["filename"] as? String
        self.url = (json["url"] as? String).flatMap { URL(string: $0) }
        self.proxyURL = (json["proxy_url"] as? String).flatMap { URL(string: $0) }
        self.size = json["size"] as? Int
        self.height = json["height"] as? Int
        self.width = json["width"] as? Int
        self.contentType = json["content_type"] as? String
    }
}

import UIKit

public extension Attachment {
    
    /// Fetch this attachment asynchronously without caching.
    /// - Parameter completion: Called on the main thread with UIImage (if image) or Data (for other files)
    func fetch(completion: @escaping (Any?) -> Void) {
        guard let url = self.url else {
            DispatchQueue.main.async { completion(nil) }
            return
        }
        
        URLSessionCompat.shared.dataTask(with: URLRequest(url: url)) { data, _, error in
            guard let data = data, error == nil else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            var result: Any?
            if self.contentType?.starts(with: "image") == true {
                // Decode image inside an autoreleasepool to free memory ASAP
                autoreleasepool {
                    result = UIImage(data: data)
                }
            } else {
                result = data
            }
            
            DispatchQueue.main.async {
                completion(result)
            }
        }.resume()
    }
}


