//
// Created by YokoroKaito on 2021/09/16.
// Copyright (c) 2021 Oh-deers. All rights reserved.
//

import Foundation
import CoreMotion
import RxSwift
import RxCocoa

class MotionManager {

    //motion manager
    let motionManager = CMMotionManager()

    var motion: CMDeviceMotion?

    let motionRelay = PublishRelay<CMDeviceMotion?>()

    private let disposeBag = DisposeBag()

    init() {
        let intervalSeconds = 0.4
        // Do any additional setup after loading the view.
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = TimeInterval(intervalSeconds)

            motionManager.startDeviceMotionUpdates(to: OperationQueue.current!, withHandler: { (motion: CMDeviceMotion?, error: Error?) in
                self.motionRelay.accept(motion)
            })
        }
    }

    // センサー取得を止める場合
    func stopDevicemotion() {
        if (motionManager.isDeviceMotionActive) {
            motionManager.stopDeviceMotionUpdates()
        }
    }

    let coefficient = [0.30223284, -2.62991929, 1.52691657, -1.28418032, -0.1064995, -0.02088443, 3.26271071, 0.46824078, 0.22321698]

    func getMotionThreshold(deviceMotion: CMDeviceMotion)-> Double {
        var sensorList: [Double] = []
        var sum: Double = -1.80131316

        //重力センサ
        sensorList.append(deviceMotion.gravity.x)
        sensorList.append(deviceMotion.gravity.y)
        sensorList.append(deviceMotion.gravity.z)

        sensorList.append(deviceMotion.rotationRate.x)
        sensorList.append(deviceMotion.rotationRate.y)
        sensorList.append(deviceMotion.rotationRate.z)

        sensorList.append(deviceMotion.attitude.pitch)
        sensorList.append(deviceMotion.attitude.roll)
        sensorList.append(deviceMotion.attitude.yaw)

        for i in 0..<9 {
            sum = sum + coefficient[i] * sensorList[i]
        }

        print(sum)
        return sum
    }
}
