//
//  ViewController.swift
//  AudioDeviceExample
//
//  Copyright © 2020 Twilio, Inc. All rights reserved.
//

import CallKit
import UIKit
import CoreMotion

import TwilioVoice

let twimlParamTo = "to"

class ViewController: UIViewController {
    //motion manager
    let motionManager = CMMotionManager()
    var sensorList: [Double] = []

    var accessToken: String? = ""

    var activeCall: Call?
    var audioDevice: ExampleAVAudioEngineDevice = ExampleAVAudioEngineDevice()
    var callKitProvider: CXProvider
    var callKitCallController: CXCallController
    var userInitiatedDisconnect: Bool = false
    var callKitCompletionCallback: ((Bool) -> Void)? = nil
    var calling: Bool = false

    @IBOutlet weak var outgoingTextField: UITextField!
    @IBOutlet weak var callButton: UIButton!
    @IBOutlet weak var callControlView: UIView!
    @IBOutlet weak var muteSwitch: UISwitch!
    @IBOutlet weak var speakerSwitch: UISwitch!
    @IBOutlet weak var playMusicButton: UIButton!

    @IBOutlet weak var participant: UIView!
    @IBOutlet weak var muteButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        muteButton.setImage(UIImage(named: "Mute=true"), for: .normal);
        muteButton.setImage(UIImage(named: "Mute=false"), for: .selected)
        participant.isHidden = true

        let intervalSeconds = 0.4
        // Do any additional setup after loading the view.
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = TimeInterval(intervalSeconds)

            motionManager.startDeviceMotionUpdates(to: OperationQueue.current!, withHandler: { (motion: CMDeviceMotion?, error: Error?) in
                self.getMotionData(deviceMotion: motion!)
            })
        }
    }

    func getMotionData(deviceMotion: CMDeviceMotion) {
        sensorList = []
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

        let intercept = -1.80131316
        var sum = intercept
        let coefficient = [0.30223284, -2.62991929, 1.52691657, -1.28418032, -0.1064995, -0.02088443, 3.26271071, 0.46824078, 0.22321698]

        for i in 0..<9 {
            sum = sum + coefficient[i] * sensorList[i]
        }

        print(sum)

        //接続の判定
        if sum > 2 && calling == false {
            print("stand up")

            //stopDevicemotion()
            phoneCall()
            calling = true

        } else {
            print("sit down")
        }

    }

    // センサー取得を止める場合
    func stopDevicemotion() {
        if (motionManager.isDeviceMotionActive) {
            motionManager.stopDeviceMotionUpdates()

        }
    }

    required init?(coder aDecoder: NSCoder) {
        let configuration = CXProviderConfiguration(localizedName: "Stol-app")
        configuration.maximumCallGroups = 1
        configuration.maximumCallsPerCallGroup = 1

        callKitProvider = CXProvider(configuration: configuration)
        callKitCallController = CXCallController()

        super.init(coder: aDecoder)

        callKitProvider.setDelegate(self, queue: nil)

        TwilioVoiceSDK.audioDevice = audioDevice
    }

    deinit {
        // CallKit has an odd API contract where the developer must call invalidate or the CXProvider is leaked.
        callKitProvider.invalidate()
    }

    func toggleUIState(isEnabled: Bool, showCallControl: Bool) {
        callButton.isEnabled = isEnabled
        callControlView.isHidden = !showCallControl;
        muteSwitch.isOn = !showCallControl;
        speakerSwitch.isOn = showCallControl;
    }

    // MARK: AVAudioSession
    func toggleAudioRoute(toSpeaker: Bool) {
        // The mode set by the Voice SDK is "VoiceChat" so the default audio route is the built-in receiver. Use port override to switch the route.
        do {
            try AVAudioSession.sharedInstance().overrideOutputAudioPort(toSpeaker ? .speaker : .none)
        } catch {
            NSLog(error.localizedDescription)
        }
    }

    func showMicrophoneAccessRequest(_ uuid: UUID, _ handle: String) {
        let alertController = UIAlertController(title: "Voice Quick Start",
                message: "Microphone permission not granted",
                preferredStyle: .alert)

        let continueWithoutMic = UIAlertAction(title: "Continue without microphone", style: .default) { [weak self] _ in
            self?.performStartCallAction(uuid: uuid, handle: handle)
        }

        let goToSettings = UIAlertAction(title: "Settings", style: .default) { _ in
            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!,
                    options: [UIApplication.OpenExternalURLOptionsKey.universalLinksOnly: false],
                    completionHandler: nil)
        }

        let cancel = UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.toggleUIState(isEnabled: true, showCallControl: false)
        }

        [continueWithoutMic, goToSettings, cancel].forEach {
            alertController.addAction($0)
        }

        present(alertController, animated: true, completion: nil)
    }

    func checkRecordPermission(completion: @escaping (_ permissionGranted: Bool) -> Void) {
        let permissionStatus = AVAudioSession.sharedInstance().recordPermission

        switch permissionStatus {
        case .granted:
            // Record permission already granted.
            completion(true)
        case .denied:
            // Record permission denied.
            completion(false)
        case .undetermined:
            // Requesting record permission.
            // Optional: pop up app dialog to let the users know if they want to request.
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                completion(granted)
            }
        default:
            completion(false)
        }
    }

    @IBAction func callButtonTapped(_ sender: Any) {
        guard activeCall == nil else {
            userInitiatedDisconnect = true
            performEndCallAction(uuid: activeCall!.uuid!)
            toggleUIState(isEnabled: false, showCallControl: false)

            return
        }

        checkRecordPermission { [weak self] permissionGranted in
            let uuid = UUID()
            let handle = "Voice Bot"

            guard !permissionGranted else {
                self?.performStartCallAction(uuid: uuid, handle: handle)
                return
            }

            self?.showMicrophoneAccessRequest(uuid, handle)
        }
    }

    @IBAction func callbuttonTap(_ sender: Any) {
        // TODO Call
    }

    @IBAction func muteSwitchToggled(_ sender: UISwitch) {
        guard let activeCall = activeCall else {
            return
        }

        activeCall.isMuted = sender.isOn
    }

    @IBAction func muteButton(_ sender: UIButton) {
        sender.isSelected = !sender.isSelected;
    }

    @IBAction func voicechatswitchTapped(_ sender: UISwitch) {
        toggleAudioRoute(toSpeaker: sender.isOn)
    }

    @IBAction func disconnectswitchTapped(_ sender: UISwitch) {
        audioDevice.playMusic()
    }
}

// MARK: - TVOCallDelegate
extension ViewController: CallDelegate {
    func callDidStartRinging(call: Call) {
        NSLog("callDidStartRinging:")

        callButton.setTitle("Ringing", for: .normal)
    }

    func callDidConnect(call: Call) {
        NSLog("callDidConnect:")

        if let callKitCompletionCallback = callKitCompletionCallback {
            callKitCompletionCallback(true)
        }

        callButton.setTitle("Hang Up", for: .normal)
        toggleUIState(isEnabled: true, showCallControl: true)
        toggleAudioRoute(toSpeaker: true)
    }

    func call(call: Call, isReconnectingWithError error: Error) {
        NSLog("call:isReconnectingWithError:")

        callButton.setTitle("Reconnecting", for: .normal)
        toggleUIState(isEnabled: false, showCallControl: false)
    }

    func callDidReconnect(call: Call) {
        NSLog("callDidReconnect:")

        callButton.setTitle("Hang Up", for: .normal)
        toggleUIState(isEnabled: true, showCallControl: true)
    }

    func callDidFailToConnect(call: Call, error: Error) {
        NSLog("Call failed to connect: \(error.localizedDescription)")

        if let completion = callKitCompletionCallback {
            completion(false)
        }

        performEndCallAction(uuid: call.uuid!)
        callDisconnected(call)
    }

    func callDidDisconnect(call: Call, error: Error?) {
        if let error = error {
            NSLog("Call failed: \(error.localizedDescription)")
        } else {
            NSLog("Call disconnected")
        }

        if !userInitiatedDisconnect {
            var reason = CXCallEndedReason.remoteEnded

            if error != nil {
                reason = .failed
            }

            callKitProvider.reportCall(with: call.uuid!, endedAt: Date(), reason: reason)
        }

        callDisconnected(call)
    }

    func callDisconnected(_ call: Call) {
        if call == activeCall {
            activeCall = nil
        }

        userInitiatedDisconnect = false

        toggleUIState(isEnabled: true, showCallControl: false)
        callButton.setTitle("Call", for: .normal)
        calling = false
    }
}

// MARK: - CXProviderDelegate
extension ViewController: CXProviderDelegate {
    func providerDidReset(_ provider: CXProvider) {
        NSLog("providerDidReset:")
        audioDevice.isEnabled = false
    }

    func providerDidBegin(_ provider: CXProvider) {
        NSLog("providerDidBegin")
    }

    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        NSLog("provider:didActivateAudioSession:")
        audioDevice.isEnabled = true
    }

    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        NSLog("provider:didDeactivateAudioSession:")
        audioDevice.isEnabled = false
    }

    func provider(_ provider: CXProvider, timedOutPerforming action: CXAction) {
        NSLog("provider:timedOutPerformingAction:")
    }

    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        NSLog("provider:performStartCallAction:")

        provider.reportOutgoingCall(with: action.callUUID, startedConnectingAt: Date())

        performVoiceCall(uuid: action.callUUID, client: "") { success in
            if success {
                provider.reportOutgoingCall(with: action.callUUID, connectedAt: Date())
                action.fulfill()
            } else {
                action.fail()
            }
        }
    }

    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        NSLog("provider:performEndCallAction:")

        if let call = activeCall {
            call.disconnect()
        }

        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
        NSLog("provider:performSetHeldAction:")

        if let call = activeCall {
            call.isOnHold = action.isOnHold
            action.fulfill()
        } else {
            action.fail()
        }
    }

    func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        NSLog("provider:performSetMutedAction:")

        if let call = activeCall {
            call.isMuted = action.isMuted
            action.fulfill()
        } else {
            action.fail()
        }
    }

    // MARK: Call Kit Actions
    func performStartCallAction(uuid: UUID, handle: String) {
        let callHandle = CXHandle(type: .generic, value: handle)
        let startCallAction = CXStartCallAction(call: uuid, handle: callHandle)
        let transaction = CXTransaction(action: startCallAction)

        callKitCallController.request(transaction) { error in
            if let error = error {
                NSLog("StartCallAction transaction request failed: \(error.localizedDescription)")
                return
            }

            NSLog("StartCallAction transaction request successful")

            let callUpdate = CXCallUpdate()

            callUpdate.remoteHandle = callHandle
            callUpdate.supportsDTMF = true
            callUpdate.supportsHolding = true
            callUpdate.supportsGrouping = false
            callUpdate.supportsUngrouping = false
            callUpdate.hasVideo = false

            self.callKitProvider.reportCall(with: uuid, updated: callUpdate)
        }
    }

    func reportIncomingCall(from: String, uuid: UUID) {
        let callHandle = CXHandle(type: .generic, value: from)

        let callUpdate = CXCallUpdate()

        callUpdate.remoteHandle = callHandle
        callUpdate.supportsDTMF = true
        callUpdate.supportsHolding = true
        callUpdate.supportsGrouping = false
        callUpdate.supportsUngrouping = false
        callUpdate.hasVideo = false

        callKitProvider.reportNewIncomingCall(with: uuid, update: callUpdate) { error in
            if let error = error {
                NSLog("Failed to report incoming call successfully: \(error.localizedDescription).")
            } else {
                NSLog("Incoming call successfully reported.")
            }
        }
    }

    func performEndCallAction(uuid: UUID) {

        let endCallAction = CXEndCallAction(call: uuid)
        let transaction = CXTransaction(action: endCallAction)

        callKitCallController.request(transaction) { error in
            if let error = error {
                NSLog("EndCallAction transaction request failed: \(error.localizedDescription).")
            } else {
                NSLog("EndCallAction transaction request successful")
            }
        }
    }

    func performVoiceCall(uuid: UUID, client: String?, completionHandler: @escaping (Bool) -> Void) {
        guard let token = accessToken, token.count > 0 else {
            completionHandler(false)
            return
        }

        let connectOptions = ConnectOptions(accessToken: token) { builder in
            builder.params = [twimlParamTo: self.outgoingTextField.text ?? ""]
            builder.uuid = uuid
        }

        let call = TwilioVoiceSDK.connect(options: connectOptions, delegate: self)
        activeCall = call
        callKitCompletionCallback = completionHandler
    }

    func phoneCall() {
        guard activeCall == nil else {
            userInitiatedDisconnect = true
            performEndCallAction(uuid: activeCall!.uuid!)
            toggleUIState(isEnabled: false, showCallControl: false)

            return
        }

        checkRecordPermission { [weak self] permissionGranted in
            let uuid = UUID()
            let handle = "Voice Bot"

            guard !permissionGranted else {
                self?.performStartCallAction(uuid: uuid, handle: handle)
                return
            }

            self?.showMicrophoneAccessRequest(uuid, handle)
        }
    }
}
