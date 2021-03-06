//
//  FriendsFinderHelper.swift
//  Unplanned
//
//  Created by True Metal on 5/26/16.
//  Copyright © 2016 matata. All rights reserved.
//

import Foundation
import DigitsKit
import Parse
import APAddressBook
import GCDSwift

class FriendsFinderHelper
{
    static var digitsContacts : DGTContacts? = nil

    static let addressBook = APAddressBook()

    class func startObservingAddressBookChanges () {

        addressBook.startObserveChangesWithCallback({

            FriendsFinderHelper.startMatchingParseFriendsWithDigits(sendNotificationsToMatchedUsers: false, completionBlock: {

            });
        });
    }

    class func startMatchingParseFriendsWithDigits(sendNotificationsToMatchedUsers sendNotifications: Bool, completionBlock: VoidBlock) {

        GCDQueue.mainQueue.queueBlock({
            guard let session = Digits.sharedInstance().session() else {
                completionBlock();
                print("Failed to create digits session")
                return
            }

            digitsContacts = DGTContacts(userSession: session)
            digitsContacts!.startContactsUploadWithCompletion {
                result, error in
                guard let result = result else {
                    completionBlock()
                    UIMsg("Failed to upload contacts \(error.localizedDescription ?? "")")
                    return
                }

                print("Total contacts: \(result.totalContacts), uploaded successfully: \(result.numberOfUploadedContacts)")
                self.findDigitsFriends(session, sendNotifications: sendNotifications, completionBlock: completionBlock)
            }

        }, afterDelay: 0.5)
    }

    class func findDigitsFriends(session: DGTSession, sendNotifications: Bool,completionBlock:VoidBlock)
    {
        // TODO: add matching for next batch for > 100 matches
        
        digitsContacts!.lookupContactMatchesWithCursor(nil) { (matches, nextCursor, error) -> Void in
            guard let matches = matches as? [DGTUser] else {
                completionBlock()
                UIMsg("Error matching friends \(error.localizedDescription ?? "")")
                return
            }
            
            print("matched \(matches.count) friends")
            
            self.saveParseUsers(matches.map { $0.userID }, sendNotifications: sendNotifications, completionBlock: completionBlock)
        }
    }
    
    
    
    class func saveParseUsers(digitIds:[String], sendNotifications : Bool, completionBlock:VoidBlock)
    {
        guard let user = UserModel.currentUser(), query = UserModel.query() else { return }
        
        query.whereKey("digitsUserId", containedIn: digitIds)
        query.findObjectsInBackgroundWithBlock { (users, error) in
            guard let users = users as? Array<UserModel> else {
                completionBlock()
                UIMsg("Failed to find parse users \(error?.localizedDescription ?? "")")
                return
            }
            
            //user.allFriends = users
            
            
            var fullName = ""
            if let fName = PFUser.currentUser()!.valueForKey("firstName") as? String {
                if let lName = PFUser.currentUser()!.valueForKey("lastName") as? String {
                    fullName = "\(fName) \(lName)"
                }
            }
            
            var usersArray = [String]()
            
            for user : UserModel in users {
                if sendNotifications {
                    sendPushNotificationToUser(user.username!, title: "Attention", message: "Your friend \(fullName) is now using UnPlanned", pushType: "message")
                }
                usersArray.append(user.username!)
            }
            
            user.setObject(usersArray, forKey: "allFriends")
            
            user.saveInBackgroundWithBlock({ (success, error) in
                guard success else {
                    completionBlock()
                    UIMsg("Failed to save parse friends \(error?.localizedDescription ?? "")")
                    return
                }
                
                completionBlock()
            })
        }
    }
}
