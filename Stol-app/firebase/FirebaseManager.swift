//
// Created by YokoroKaito on 2021/09/18.
// Copyright (c) 2021 Oh-deers. All rights reserved.
//

import Foundation
import Firebase
import RxSwift
import RxCocoa

class FirebaseManager {

    var DBRef: DatabaseReference!

    var participantStatus: [String: [ String : String ]] = [:]
    var statusRelay = PublishRelay<[String: [ String : String ]]>()

    init() {
        DBRef = Database.database().reference()
    }

    func startReadStatus() {
        let period = DispatchTimeInterval.seconds(1)
        let defaultPlace = DBRef.child("status")

        let _ = Observable<Int>
                .interval(period, scheduler: MainScheduler.instance)
                .subscribe { _ in
                    var status: [String: [ String : String ]] = [:]
                    defaultPlace.getData { (error, snapshot) in
                        if let error = error {
                            print("Error getting data \(error)")
                        } else if snapshot.exists() {
                            status = snapshot.value! as! [String: [ String : String ]]
                            self.statusRelay.accept(status)
                        } else {
                            print("No data available")
                        }
                    }
                }

    }

    func standUp() {
        let data = [UIDevice.current.identifierForVendor!.uuidString: ["status": "standUp"]]
        DBRef.child("status").setValue(data)
    }

    func sitDown() {
        let data = [UIDevice.current.identifierForVendor!.uuidString: ["status": "sitDown"]]
        DBRef.child("status").setValue(data)
    }
}