//
//  Post.swift
//  Hacker Swifter
//
//  Created by Thomas Ricouard on 11/07/14.
//  Copyright (c) 2014 Thomas Ricouard. All rights reserved.
//

import Foundation

@objc(Post) open class Post: NSObject, NSCoding {
    
    open var id: Int?
    open var title: String?
    open var username: String?
    open var url: URL?
    open var domain: String? {
        get {
            if let realUrl = self.url {
                if let host = realUrl.host {
                    if (host.hasPrefix("www")) {
                        return host.substring(from: host.characters.index(host.startIndex, offsetBy: 4))
                    }
                    return host
                }
            }
            return ""
        }
    }
    open var points: Int = 0
    open var commentsCount: Int = 0
    open var postId: String?
    open var prettyTime: String?
    open var upvoteURL: String?
    open var type: PostFilter?
    open var kids: [Int]?
    open var score: Int?
    open var time: Int?
    open var dead: Bool = false
    
    public enum PostFilter: String {
        case Top = ""
        case Default = "default"
        case Ask = "ask"
        case New = "newest"
        case Jobs = "jobs"
        case Best = "best"
        case Show = "show"
    }
    
    internal enum serialization: String {
        case title = "title"
        case username = "username"
        case url = "url"
        case points = "points"
        case commentsCount = "commentsCount"
        case postId = "postId"
        case prettyTime = "prettyTime"
        case upvoteURL = "upvoteURL"
        
        static let values = [title, username, url, points, commentsCount, postId, prettyTime, upvoteURL]
    }
    
    internal enum JSONField: String {
        case id = "id"
        case by = "by"
        case descendants = "descendants"
        case kids = "kids"
        case score = "score"
        case time = "time"
        case title = "title"
        case type = "type"
        case url = "url"
        case dead = "dead"
    }
    
    public override init(){
        super.init()
    }
    
    public init(html: String) {
        super.init()
        self.parseHTML(html)
    }
    
    public init(json: NSDictionary) {
        super.init()
        self.parseJSON(json)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init()
        
        for key in serialization.values {
            setValue(aDecoder.decodeObject(forKey: key.rawValue), forKey: key.rawValue)
        }
    }
    
    open func encode(with aCoder: NSCoder) {
        for key in serialization.values {
            if let value: AnyObject = self.value(forKey: key.rawValue) as AnyObject? {
                aCoder.encode(value, forKey: key.rawValue)
            }
        }
    }
    
    fileprivate func encode(_ object: AnyObject!, key: String, coder: NSCoder) {
        if let _: AnyObject = object {
            coder.encode(object, forKey: key)
        }
    }
}

//MARK: Equatable implementation
public func ==(larg: Post, rarg: Post) -> Bool {
    return larg.postId == rarg.postId
}

//MARK: Network
public extension Post {
    
    public typealias Response = (_ posts: [Post]?, _ error: Fetcher.ResponseError?, _ local: Bool) -> Void
    public typealias ResponsePost = (_ post: Post?, _ error: Fetcher.ResponseError?, _ local: Bool) -> Void
    public typealias ResponsePosts = (_ post: [Int]?, _ error: Fetcher.ResponseError?, _ local: Bool) -> Void
    
    public class func fetch(_ filter: PostFilter, page: Int, completion: @escaping Response) {
        Fetcher.Fetch(filter.rawValue + "?p=\(page)",
            parsing: {(html) in
                if let realHtml = html {
                    let posts = self.parseCollectionHTML(realHtml)
                    return posts as AnyObject!
                } else {
                    return nil
                }
            },
            completion: {(object, error, local) in
                if let realObject: AnyObject = object {
                    completion(realObject as? [Post], error, local)
                }
                else {
                    completion(nil, error, local)
                }
        })
    }
    
    public class func fetch(_ filter: PostFilter, completion: @escaping Response) {
        fetch(filter, page: 1, completion: completion)
    }
    
    public class func fetch(_ user: String, page: Int, lastPostId:String?, completion: @escaping Response) {
        var additionalParameters = ""
        if let lastPostIdInt = Int(lastPostId ?? "") {
            additionalParameters = "&next=\(lastPostIdInt-1)"
        }
        Fetcher.Fetch("submitted?id=" + user + additionalParameters,
            parsing: {(html) in
                if let realHtml = html {
                    let posts = self.parseCollectionHTML(realHtml)
                    return posts as AnyObject!
                } else {
                    return nil
                }
            },
            completion: {(object, error, local) in
                if let realObject: AnyObject = object {
                    completion(realObject as? [Post], error, local)
                }
                else {
                    completion(nil, error, local)
                }
        })
    }
    
    public class func fetch(_ user: String, completion: @escaping Response) {
        fetch(user, page: 1, lastPostId:nil, completion: completion)
    }
    
    public class func fetchPost(_ completion: @escaping ResponsePosts) {
        Fetcher.FetchJSON(.Top, ressource: nil, parsing: { (json) -> AnyObject! in
            if let _ = json as? [Int] {
                return json
            }
            return nil
            }) { (object, error, local) -> Void in
                completion(object as? [Int] , error, local)
        }
    }
    public class func fetchPost(_ post: Int, completion: @escaping ResponsePost) {
        Fetcher.FetchJSON(.Post, ressource: String(post), parsing: { (json) -> AnyObject! in
            if let dic = json as? NSDictionary {
                return Post(json: dic)
            }
            return nil
            })
            { (object, error, local) -> Void in
                completion(object as? Post, error, local)
        }
    }
}

//MARK: JSON

internal extension Post {
    internal func parseJSON(_ json: NSDictionary) {
        self.id = json[JSONField.id.rawValue] as? Int
        if let kids = json[JSONField.kids.rawValue] as? [Int] {
            self.kids = kids
        }
        self.title = json[JSONField.title.rawValue] as? String
        self.score = json[JSONField.score.rawValue] as? Int
        self.username = json[JSONField.by.rawValue] as? String
        self.time = json[JSONField.time.rawValue] as? Int
        self.url = URL(string: (json[JSONField.url.rawValue] as? String)!)
        if let commentsCount = json[JSONField.descendants.rawValue] as? Int {
            self.commentsCount = commentsCount
        }
        if let _ = json[JSONField.dead.rawValue] as? Bool {
            self.dead = true
        }
    }
}

//MARK: HTML
internal extension Post {
    
    internal class func parseCollectionHTML(_ html: String) -> [Post] {
        let components = html.components(separatedBy: "<td align=\"right\" valign=\"top\" class=\"title\">")
        var posts: [Post] = []
        if (components.count > 0) {
            var index = 0
            for component in components {
                if index != 0 {
                    posts.append(Post(html: component))
                }
                index += 1
            }
        }
        return posts
    }
    
    internal func parseHTML(_ html: String) {
        let scanner = Scanner(string: html)
        
        if (html.range(of: "<td class=\"title\"> [dead] <a") == nil) {
            
            self.url = URL(string: scanner.scanTag("<a href=\"", endTag: "\""))
            self.title = scanner.scanTag(">", endTag: "</a>")
            
            var temp: NSString = scanner.scanTag("<span class=\"score\" id=\"score_", endTag: "</span>") as NSString
            let range = temp.range(of: ">")
            if (range.location != NSNotFound) {
                let tmpPoint: Int? = Int(temp.substring(from: range.location + 1)
                    .replacingOccurrences(of: " points", with: "", options: NSString.CompareOptions.caseInsensitive, range: nil))
                if let points = tmpPoint {
                    self.points = points
                }
                else {
                    self.points = 0
                }
            }
            else {
                self.points = 0
            }
            self.username = scanner.scanTag("<a href=\"user?id=", endTag: "\"")
            if self.username == nil {
                self.username = "HN"
            }
            self.postId = scanner.scanTag("<a href=\"item?id=", endTag: "\">")
            self.prettyTime = scanner.scanTag(">", endTag: "</a>")
            
            temp = scanner.scanTag("\">", endTag: "</a>") as NSString
            if (temp == "discuss") {
                self.commentsCount = 0
            }
            else {
                self.commentsCount = temp.integerValue
            }
            if (self.username == nil && self.commentsCount == 0 && self.postId == nil) {
                self.type = PostFilter.Jobs
                self.username = "Jobs"
            }
            else if (self.url?.absoluteString.localizedCaseInsensitiveCompare("http") == nil) {
                self.type = PostFilter.Ask
                if let realURL = self.url {
                    let url = realURL.absoluteString
                    self.url = URL(string: "https://news.ycombinator.com/" + url)
                }
            }
            else {
                self.type = PostFilter.Default
            }
        }
    }
}
