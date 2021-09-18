//
// Created by YokoroKaito on 2021/09/18.
// Copyright (c) 2021 Oh-deers. All rights reserved.
//

import Foundation
import Firebase

class FirebaseManager {

    var DBRef: DatabaseReference!

    init() {
        //インスタンスを作成
        DBRef = Database.database().reference()
    }

    func standUp() {
        let data = ["status": "standUp"]
        DBRef.child("").setValue(data)
    }

    func sitDown() {
        let data = ["status": "sitDown"]
        DBRef.child("").setValue(data)
    }
}