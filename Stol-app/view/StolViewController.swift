import UIKit

import TwilioVideo
import RxCocoa
import RxSwift

let twimlParamTo = "to"

class StolViewController: UIViewController,UITableViewDelegate,UITableViewDataSource {
    //motion manager
    let motionManager = MotionManager()
    let firebaseManager = FirebaseManager()

    var disposeBag = DisposeBag()

    var calling: Bool = false
    
    var name_list = [String](){
        didSet {
            tableview?.reloadData()
        }
    }
    @IBOutlet weak var tableview: UITableView!

    let roomName = "a"

    @IBOutlet weak var outgoingTextField: UITextField!
    @IBOutlet weak var callButton: UIButton!
    @IBOutlet weak var callControlView: UIView!
    @IBOutlet weak var muteSwitch: UISwitch!
    @IBOutlet weak var speakerSwitch: UISwitch!
    @IBOutlet weak var playMusicButton: UIButton!
    @IBOutlet weak var statusLabel: UILabel!

    @IBOutlet weak var participant: UIView!
    @IBOutlet weak var muteButton: UIButton!
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    // MARK:- View Controller Members

    // Configure access token manually for testing, if desired! Create one manually in the console
    // at https://www.twilio.com/console/video/runtime/testing-tools
    var accessToken = "."
    // Configure remote URL to fetch token from
    var tokenUrl = "http://localhost:8000/token.php"

    // Video SDK components
    var room: Room?
    var camera: CameraSource?
    var localVideoTrack: LocalVideoTrack?
    var localAudioTrack: LocalAudioTrack?
    var remoteParticipant: RemoteParticipant?

    var isAutoConnect = true
    var isAutoDisconnect = true

    // MARK:- UIViewController
    override func viewDidLoad() {
        super.viewDidLoad()
        /*
        AVCaptureDevice.requestAccess(for: AVMediaType.audio, completionHandler: {(granted: Bool) in})
        AVAudioSession.requestRecordPermission(<#T##self: AVAudioSession##AVAudioSession#>)
         */
        self.title = "Stol"

        // Do any additional setup after loading the view.
        muteButton.setImage(UIImage(named: "Mute=false"), for: .normal);
        muteButton.setImage(UIImage(named: "Mute=true"), for: .selected)
        // participant.isHidden = true

        motionManager.motionRelay
                .subscribe(onNext: { motion in
                    if self.motionManager.getMotionThreshold(deviceMotion: motion!) > 2 {
                        self.firebaseManager.standUp()
                        self.statusLabel.text = "Standing"

                        if (self.isAutoConnect && !self.calling) {
                            //stopDevicemotion()
                            self.phoneCall()
                            self.calling = true
                        } else {
                            print("calling now")
                        }

                    } else {
                        self.firebaseManager.sitDown()
                        self.statusLabel.text = "Sitting"

                        print("sit down")
                    }
                })
                .disposed(by: disposeBag)

        if motionManager.motionManager.isDeviceMotionAvailable {
            firebaseManager.startReadStatus()
            firebaseManager.statusRelay
                    .subscribe(onNext: { status in
                        print(status)
                    })
                    .disposed(by: disposeBag)
        }
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

    @IBAction func callButtonTap(_ sender: UIButton) {
        // Configure access token either from server or manually.
        // If the default wasn't changed, try fetching from server.
        if !calling {
            phoneCall()
            let image = UIImage(named: "Connect=true")
            let state = UIControl.State.normal

            callButton.setImage(image, for: state)
        } else {
            calling = false
            self.room!.disconnect()

            let image = UIImage(named: "Connect=false")
            let state = UIControl.State.normal

            callButton.setImage(image, for: state)
        }
    }

    @IBAction func muteButton(_ sender: UIButton) {
        if (self.localAudioTrack != nil) {
            self.localAudioTrack?.isEnabled = !(self.localAudioTrack?.isEnabled)!
            sender.isSelected = !sender.isSelected;
        }
    }

    @IBAction func voicechatSwitchTapped(_ sender: UISwitch) {
        isAutoConnect = !isAutoConnect
    }

    @IBAction func disconnectSwitchTapped(_ sender: UISwitch) {
        isAutoDisconnect = !isAutoDisconnect
    }

    func phoneCall() {
        if calling {
            return
        }

        if (accessToken == "TWILIO_ACCESS_TOKEN") {
            do {
                accessToken = try TokenUtils.fetchToken(url: tokenUrl)
            } catch {
                let message = "Failed to fetch access token"
                logMessage(messageText: message)
                return
            }
        }

        calling = true

        // Prepare local media which we will share with Room Participants.
        self.prepareLocalMedia()

        // Preparing the connect options with the access token that we fetched (or hardcoded).
        let connectOptions = ConnectOptions(token: accessToken) { (builder) in

            // Use the local media that we prepared earlier.
            builder.audioTracks = self.localAudioTrack != nil ? [self.localAudioTrack!] : [LocalAudioTrack]()

            // Use the preferred audio codec
            if let preferredAudioCodec = Settings.shared.audioCodec {
                builder.preferredAudioCodecs = [preferredAudioCodec]
            }

            // Use the preferred encoding parameters
            if let encodingParameters = Settings.shared.getEncodingParameters() {
                builder.encodingParameters = encodingParameters
            }

            // Use the preferred signaling region
            if let signalingRegion = Settings.shared.signalingRegion {
                builder.region = signalingRegion
            }

            // The name of the Room where the Client will attempt to connect to. Please note that if you pass an empty
            // Room `name`, the Client will create one for you. You can get the name or sid from any connected Room.
            builder.roomName = self.roomName
        }

        // Connect to the Room using the options we provided.
        room = TwilioVideoSDK.connect(options: connectOptions, delegate: self)

        logMessage(messageText: "Attempting to connect to room")
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            return name_list.count;
        }
        // 追加④：セルに値を設定するデータソースメソッド（必須）
        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            // セルを取得する
            let cell: UITableViewCell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)

            // TableViewCellの中に配置したLabelを取得する
            let label1 = cell.contentView.viewWithTag(1) as! UILabel

            // Labelにテキストを設定する
            label1.text = name_list[indexPath.row]

            return cell
        }

    func prepareLocalMedia() {

        // We will share local audio and video when we connect to the Room.
        // Create an audio track.
        if (localAudioTrack == nil) {
            localAudioTrack = LocalAudioTrack(options: nil, enabled: true, name: "Microphone")

            if (localAudioTrack == nil) {
                logMessage(messageText: "Failed to create audio track")
            }
        }
    }

    func cleanupRemoteParticipant() {
        if self.remoteParticipant != nil {
            self.remoteParticipant = nil
        }
    }

    func logMessage(messageText: String) {
        NSLog(messageText)
    }
}

// MARK:- UITextFieldDelegate
extension StolViewController : UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.phoneCall()
        return true
    }
}

// MARK:- RoomDelegate
extension StolViewController : RoomDelegate {
    func roomDidConnect(room: Room) {
        logMessage(messageText: "Connected to room \(room.name) as \(room.localParticipant?.identity ?? "")")
        name_list.append((String(describing: room.localParticipant!.identity)))
        // This example only renders 1 RemoteVideoTrack at a time. Listen for all events to decide which track to render.
        for remoteParticipant in room.remoteParticipants {
            name_list.append(remoteParticipant.identity)
            
            remoteParticipant.delegate = self
        }
    }

    func roomDidDisconnect(room: Room, error: Error?) {
        logMessage(messageText: "Disconnected from room \(room.name), error = \(String(describing: error))")
        
        name_list=[String]()
        self.cleanupRemoteParticipant()
        self.room = nil
    }

    func roomDidFailToConnect(room: Room, error: Error) {
        logMessage(messageText: "Failed to connect to room with error = \(String(describing: error))")
        name_list=[String]()
        self.room = nil
    }

    func roomIsReconnecting(room: Room, error: Error) {
        logMessage(messageText: "Reconnecting to room \(room.name), error = \(String(describing: error))")
    }

    func roomDidReconnect(room: Room) {
        logMessage(messageText: "Reconnected to room \(room.name)")
    }

    func participantDidConnect(room: Room, participant: RemoteParticipant) {
        // Listen for events from all Participants to decide which RemoteVideoTrack to render.
        participant.delegate = self
        name_list.append(participant.identity)
        logMessage(messageText: "Participant \(participant.identity) connected with \(participant.remoteAudioTracks.count) audio and \(participant.remoteVideoTracks.count) video tracks")
    }

    func participantDidDisconnect(room: Room, participant: RemoteParticipant) {
        for i in 0...name_list.count{
            if(name_list[i]==participant.identity){
                name_list.remove(at: i)
                break
            }
        }
        logMessage(messageText: "Room \(room.name), Participant \(participant.identity) disconnected")

        // Nothing to do in this example. Subscription events are used to add/remove renderers.
    }
}

// MARK:- RemoteParticipantDelegate
extension StolViewController : RemoteParticipantDelegate {

    func remoteParticipantDidPublishVideoTrack(participant: RemoteParticipant, publication: RemoteVideoTrackPublication) {
        // Remote Participant has offered to share the video Track.

        logMessage(messageText: "Participant \(participant.identity) published \(publication.trackName) video track")
    }

    func remoteParticipantDidUnpublishVideoTrack(participant: RemoteParticipant, publication: RemoteVideoTrackPublication) {
        // Remote Participant has stopped sharing the video Track.
        logMessage(messageText: "Participant \(participant.identity) unpublished \(publication.trackName) video track")
    }

    func remoteParticipantDidPublishAudioTrack(participant: RemoteParticipant, publication: RemoteAudioTrackPublication) {
        // Remote Participant has offered to share the audio Track.
        logMessage(messageText: "Participant \(participant.identity) published \(publication.trackName) audio track")
    }

    func remoteParticipantDidUnpublishAudioTrack(participant: RemoteParticipant, publication: RemoteAudioTrackPublication) {
        // Remote Participant has stopped sharing the audio Track.
        logMessage(messageText: "Participant \(participant.identity) unpublished \(publication.trackName) audio track")
    }

    func didSubscribeToVideoTrack(videoTrack: RemoteVideoTrack, publication: RemoteVideoTrackPublication, participant: RemoteParticipant) {
        // The LocalParticipant is subscribed to the RemoteParticipant's video Track. Frames will begin to arrive now.
        logMessage(messageText: "Subscribed to \(publication.trackName) video track for Participant \(participant.identity)")
    }

    func didUnsubscribeFromVideoTrack(videoTrack: RemoteVideoTrack, publication: RemoteVideoTrackPublication, participant: RemoteParticipant) {
        // We are unsubscribed from the remote Participant's video Track. We will no longer receive the
        // remote Participant's video.

        logMessage(messageText: "Unsubscribed from \(publication.trackName) video track for Participant \(participant.identity)")

        if self.remoteParticipant == participant {
            cleanupRemoteParticipant()

            // Find another Participant video to render, if possible.
            if var remainingParticipants = room?.remoteParticipants,
               let index = remainingParticipants.firstIndex(of: participant) {
                remainingParticipants.remove(at: index)
            }
        }
    }

    func didSubscribeToAudioTrack(audioTrack: RemoteAudioTrack, publication: RemoteAudioTrackPublication, participant: RemoteParticipant) {
        // We are subscribed to the remote Participant's audio Track. We will start receiving the
        // remote Participant's audio now.

        logMessage(messageText: "Subscribed to \(publication.trackName) audio track for Participant \(participant.identity)")
    }

    func didUnsubscribeFromAudioTrack(audioTrack: RemoteAudioTrack, publication: RemoteAudioTrackPublication, participant: RemoteParticipant) {
        // We are unsubscribed from the remote Participant's audio Track. We will no longer receive the
        // remote Participant's audio.

        logMessage(messageText: "Unsubscribed from \(publication.trackName) audio track for Participant \(participant.identity)")
    }

    func remoteParticipantDidEnableVideoTrack(participant: RemoteParticipant, publication: RemoteVideoTrackPublication) {
        logMessage(messageText: "Participant \(participant.identity) enabled \(publication.trackName) video track")
    }

    func remoteParticipantDidDisableVideoTrack(participant: RemoteParticipant, publication: RemoteVideoTrackPublication) {
        logMessage(messageText: "Participant \(participant.identity) disabled \(publication.trackName) video track")
    }

    func remoteParticipantDidEnableAudioTrack(participant: RemoteParticipant, publication: RemoteAudioTrackPublication) {
        logMessage(messageText: "Participant \(participant.identity) enabled \(publication.trackName) audio track")
    }

    func remoteParticipantDidDisableAudioTrack(participant: RemoteParticipant, publication: RemoteAudioTrackPublication) {
        logMessage(messageText: "Participant \(participant.identity) disabled \(publication.trackName) audio track")
    }

    func didFailToSubscribeToAudioTrack(publication: RemoteAudioTrackPublication, error: Error, participant: RemoteParticipant) {
        logMessage(messageText: "FailedToSubscribe \(publication.trackName) audio track, error = \(String(describing: error))")
    }

    func didFailToSubscribeToVideoTrack(publication: RemoteVideoTrackPublication, error: Error, participant: RemoteParticipant) {
        logMessage(messageText: "FailedToSubscribe \(publication.trackName) video track, error = \(String(describing: error))")
    }
}

// MARK:- CameraSourceDelegate
extension StolViewController : CameraSourceDelegate {
    func cameraSourceDidFail(source: CameraSource, error: Error) {
        logMessage(messageText: "Camera source failed with error: \(error.localizedDescription)")
    }
}

