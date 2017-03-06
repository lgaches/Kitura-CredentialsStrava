//
//  CredentialsStrava.swift
//  Kitura-CredentialsStrava
//
//  Created by Laurent Gaches on 06/03/2017.
//  Copyright (c) 2017 Laurent Gaches
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

import Foundation

import Kitura
import KituraNet
import LoggerAPI
import Credentials


import SwiftyJSON


public class CredentialsStrava: CredentialsPluginProtocol {
    
    private let clientId: String
    private let clientSecret: String
    private let callbackUrl: String
    
    public var scope: String?
    public var approvalPrompt: String?
    public var state: String?
    
    
    public init(clientID: String, clientSecret: String, callbackUrl: String) {
        self.clientId = clientID
        self.clientSecret = clientSecret
        self.callbackUrl = callbackUrl
    }
    
    /// The name of the plugin.
    public var name: String {
        return "Strava"
    }
    
    /// User profile cache.
    public var usersCache: NSCache<NSString, BaseCacheElement>?
    
    /// An indication as to whether the plugin is redirecting or not.
    public var redirecting: Bool {
        return true
    }
    
    /// A delegate for `UserProfile` manipulation.
    public var userProfileDelegate: UserProfileDelegate?
    
    /// Authenticate an incoming request.
    ///
    /// - Parameter request: The `RouterRequest` object used to get information
    ///                     about the request.
    /// - Parameter response: The `RouterResponse` object used to respond to the
    ///                       request.
    /// - Parameter options: The dictionary of plugin specific options.
    /// - Parameter onSuccess: The closure to invoke in the case of successful authentication.
    /// - Parameter onFailure: The closure to invoke in the case of an authentication failure.
    /// - Parameter onPass: The closure to invoke when the plugin doesn't recognize the
    ///                     authentication data (usually an authentication token) in the request.
    /// - Parameter inProgress: The closure to invoke to cause a redirect to the login page in the
    ///                     case of redirecting authentication.
    public func authenticate(request: RouterRequest,
                             response: RouterResponse,
                             options: [String:Any],
                             onSuccess: @escaping (UserProfile) -> Void,
                             onFailure: @escaping (HTTPStatusCode?, [String:String]?) -> Void,
                             onPass: @escaping (HTTPStatusCode?, [String:String]?) -> Void,
                             inProgress: @escaping () -> Void) {
        
        if let code = request.queryParameters["code"] {
            // Token exchange
            
            var requestOptions: [ClientRequest.Options] = []
            requestOptions.append(.schema("https://"))
            requestOptions.append(.hostname("www.strava.com"))
            requestOptions.append(.method("POST"))
            requestOptions.append(.path("/oauth/token?client_id=\(clientId)&client_secret=\(clientSecret)&code=\(code)"))
            
            
            var headers = [String:String]()
            headers["Accept"] = "application/json"
            requestOptions.append(.headers(headers))
            
            let requestForTokenExchange = HTTP.request(requestOptions, callback: { (clientResponse) in
                
                if clientResponse?.httpStatusCode == .OK {
                    do {
                        var data = Data()
                        try clientResponse?.readAllData(into: &data)
                        
                        let json = JSON(data: data)
                        if let userDictionary = json.dictionaryObject, let userProfile = self.createUserProfile(from: userDictionary) {
                            if let delegate = self.userProfileDelegate {
                                delegate.update(userProfile: userProfile, from: userDictionary)
                            }
                            onSuccess(userProfile)
                            return
                        }
                        
                        onFailure(nil, nil)
                        
                    } catch {
                        Log.error("Failed to read Strava response")
                        onFailure(nil, nil)
                    }
                } else {
                    onFailure(nil,nil)
                }
            })
            requestForTokenExchange.end()
            
        } else {
            // Request access
            var scopeParameters = ""
            if let scope = scope {
                scopeParameters = "&scope=\(scope)"
            }
            
            var approvalPromptParameter = ""
            if let approvalPrompt = approvalPrompt {
                approvalPromptParameter = "&approval_prompt=\(approvalPrompt)"
            }
           
            var stateParameter = ""
            if let state = state {
                stateParameter = "&state=\(state)"
            }
            
            do {
                try response.redirect("https://www.strava.com/oauth/authorize?client_id=\(clientId)&redirect_uri=\(callbackUrl)&response_type=code\(scopeParameters)\(approvalPromptParameter)\(stateParameter)")
                inProgress()
            }
            catch {
                Log.error("Failed to redirect to Strava login page")
            }
        }
        
    }
    
    private func createUserProfile(from userDictionary:[String: Any]) -> UserProfile? {
        
        guard let athlete = userDictionary["athlete"] as? Dictionary<String,Any> else {
            return nil
        }
        
        guard let id =  athlete["id"] as? Int else {
            return nil
        }
        
        let name = athlete["username"] as? String ?? ""
        
        var userProfileEmails: [UserProfile.UserProfileEmail]?
        
        if let email = athlete["email"] as? String {
            userProfileEmails = [UserProfile.UserProfileEmail(value: email, type:"public")]
        }
        
        
        var userProfilePhotos: [UserProfile.UserProfilePhoto]?
        
        if let photo = athlete["profile"] as? String {
            userProfilePhotos = [UserProfile.UserProfilePhoto(photo)]
        }
        
        
        
        var userProfileName: UserProfile.UserProfileName?
        
        if let firstName = athlete["firstname"]as? String, let lastName = athlete["lastname"] as? String {
            userProfileName = UserProfile.UserProfileName(familyName: lastName, givenName: firstName, middleName: "")
        }
        
        
        
        return UserProfile(id: String(id), displayName: name, provider: self.name, name: userProfileName, emails: userProfileEmails, photos: userProfilePhotos)
    }
}
