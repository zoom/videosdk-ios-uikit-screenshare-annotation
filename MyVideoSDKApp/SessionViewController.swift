import UIKit
import PDFKit
import ZoomVideoSDK

enum ControlOption: Int {
    case toggleVideo, toggleAudio, toggleShare, leaveSession
}

enum ShareSelection {
    case InAppScreenShare
    case ShareWithView
}

class SessionViewController: UIViewController {
    // You should sign your JWT with a backend service in a production use-case
    let sdkKey = <#T##SDKKey##String#>
    let sdkSecret = <#T##SDKSecret##String#>
    let sessionName = <#Session Name#>
    let userName = <#Username#> // Display Name

    // MARK: - Properties
    let videoViewAspectRatio: CGFloat = 1.0
    var loadingLabel: UILabel = .init()
    var scrollView: UIScrollView = .init()
    var videoStackView: UIStackView = .init()
    var localView: UIView = .init()
    var localPlaceholder: UIView?
    var remoteUserViews: [Int: (view: UIView, placeholder: UIView)] = [:]
    var tabBar: UITabBar = .init()
    var toggleVideoBarItem: UITabBarItem = .init(title: "Stop Video", image: UIImage(systemName: "video.slash"), tag: ControlOption.toggleVideo.rawValue)
    var toggleAudioBarItem: UITabBarItem = .init(title: "Mute", image: UIImage(systemName: "mic.slash"), tag: ControlOption.toggleAudio.rawValue)
    var toggleShareBarItem: UITabBarItem = .init(title: "Share Locked", image: UIImage(systemName: "rectangle.on.rectangle.slash"), tag: ControlOption.toggleShare.rawValue)
    
    // For Screen Share and Annonotation purpose
    var sharerView: UIView = .init() // Share view when share is deducted
    var localViewDuringShare: UIView = .init() // Container UIView for actualLocalViewDuringShare
    var actualLocalViewDuringShare: (view: UIView, placeholder: UIView)? // Local user video view or placeholder view
    var chosenShareType: ShareSelection? // InAppScreenShare and ShareWithView
    var shareBtnStackView: UIStackView = .init() // StackView for holding PDF and Draw buttons
    var sharePDFBtn = UIButton(type: .system)
    var shareDrawBtn = UIButton(type: .system)
    let sharedPDFView = PDFView() // PDFView for local sharer
    var annotationStarted: Bool = false
    var annotationHelper: ZoomVideoSDKAnnotationHelper?

    // MARK: - Lifecycle Methods

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        ZoomVideoSDK.shareInstance()?.delegate = self
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Task {
            await joinSession()
        }
    }

    // MARK: - Private Methods

    private func joinSession() async {
        let sessionContext = ZoomVideoSDKSessionContext()
        do {
            let token = try await generateSignature(sessionName: sessionName, role: 1, sdkKey: sdkKey, sdkSecret: sdkSecret)
            sessionContext.token = token
            sessionContext.sessionName = sessionName
            sessionContext.userName = userName
            if ZoomVideoSDK.shareInstance()?.joinSession(sessionContext) == nil {
                print("Join session failed")
                showError(message: "Failed to join session")
                return
            }
        } catch {
            print("Error generating signature: \(error)")
            showError(message: "Failed to generate session token: \(error.localizedDescription)")
            return
        }
    }

    public func showError(message: String, dismiss: Bool = true) {
        Task { @MainActor in
            let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                if (dismiss) {
                    self.dismiss(animated: true)
                }
            })
            present(alert, animated: true)
        }
    }
}

// MARK: - ZoomVideoSDKDelegate

extension SessionViewController: ZoomVideoSDKDelegate {
    func onError(_ ErrorType: ZoomVideoSDKError, detail details: Int) {
        showError(message: "Error occured: \(ErrorType.rawValue)", dismiss: false)
    }
    
    func onSessionJoin() {
        addLocalViewToGrid()
        actualLocalViewDuringShare = addLocalViewDuringShare()
        self.loadingLabel.isHidden = true
        self.tabBar.isHidden = false
        
        if let localUserIsHost = ZoomVideoSDK.shareInstance()?.getSession()?.getMySelf()?.isHost(), localUserIsHost {
            ZoomVideoSDK.shareInstance()?.getShareHelper()?.enableMultiShare(false)
            ZoomVideoSDK.shareInstance()?.getShareHelper()?.lockShare(false)
        }
        
        if let shareHelper = ZoomVideoSDK.shareInstance()?.getShareHelper() {
            if shareHelper.isMultiShareEnabled() == false && !shareHelper.isShareLocked() {
                toggleShareBarItem.title = "Start Share"
                toggleShareBarItem.image = UIImage(systemName: "rectangle.on.rectangle")
            }
        }
    }

    func onUserJoin(_: ZoomVideoSDKUserHelper?, users: [ZoomVideoSDKUser]?) {
        guard let users = users,
              let myself = ZoomVideoSDK.shareInstance()?.getSession()?.getMySelf() else { return }

        for user in users where user.getID() != myself.getID() {
            let views = addRemoteUserView(for: user)
            remoteUserViews[user.getID()] = views

            if let remoteUserVideoCanvas = user.getVideoCanvas() {
                Task(priority: .background) {
                    views.placeholder.isHidden = remoteUserVideoCanvas.videoStatus()?.on ?? false
                    remoteUserVideoCanvas.subscribe(with: views.view, aspectMode: .panAndScan, andResolution: ._Auto)
                }
            }
        }
    }

    func onUserVideoStatusChanged(_: ZoomVideoSDKVideoHelper?, user: [ZoomVideoSDKUser]?) {
        guard let users = user,
              let myself = ZoomVideoSDK.shareInstance()?.getSession()?.getMySelf() else { return }
        
        for user in users {
            if user.getID() == myself.getID() {
                if let canvas = user.getVideoCanvas(),
                   let isVideoOn = canvas.videoStatus()?.on {
                    Task(priority: .background) {
                        if isVideoOn {
                            canvas.subscribe(with: self.localView, aspectMode: .panAndScan, andResolution: ._Auto)
                            canvas.subscribe(with: self.actualLocalViewDuringShare?.view, aspectMode: .panAndScan, andResolution: ._Auto)
                        } else {
                            canvas.unSubscribe(with: self.localView)
                            canvas.unSubscribe(with: self.actualLocalViewDuringShare?.view)
                        }
                        self.localPlaceholder?.isHidden = isVideoOn
                        self.toggleVideoBarItem.title = isVideoOn ? "Stop Video" : "Start Video"
                        self.toggleVideoBarItem.image = UIImage(systemName: isVideoOn ? "video.slash" : "video")
                        
                        self.actualLocalViewDuringShare?.placeholder.isHidden = isVideoOn
                    }
                }
            } else {
                if let canvas = user.getVideoCanvas(),
                   let isVideoOn = canvas.videoStatus()?.on,
                   let views = remoteUserViews[user.getID()] {
                    Task(priority: .background) {
                        views.placeholder.isHidden = isVideoOn
                    }
                }
            }
        }
    }
    
    func onShareSettingChanged(_ setting: ZoomVideoSDKShareSetting) {
        if setting == .singleShare {
            toggleShareBarItem.title = "Start Share"
            toggleShareBarItem.image = UIImage(systemName: "rectangle.on.rectangle")
        }
    }

    func onUserShareStatusChanged(_ helper: ZoomVideoSDKShareHelper?, user: ZoomVideoSDKUser?, shareAction: ZoomVideoSDKShareAction?) {
        guard let user = user, let myself = ZoomVideoSDK.shareInstance()?.getSession()?.getMySelf(), let shareAction = shareAction else { return }
        
        let shareStatus = shareAction.getShareStatus()
        
        if user.getID() == myself.getID() {
            // Local user share status changed
            if shareStatus == .start || shareStatus == .resume {
                sharerView.isHidden = true
                shareBtnStackView.isHidden = false
            } else {
                sharedPDFView.isHidden = true
                shareBtnStackView.isHidden = true
            }
        } else {
            // Remote user share status changed
            if shareStatus == .start || shareStatus == .resume {
                shareAction.getShareCanvas()?.subscribe(with: sharerView, aspectMode: .letterBox, andResolution: ._Auto)
                sharerView.isHidden = false
                shareBtnStackView.isHidden = false
                toggleShareBarItem.title = "Share Locked"
                toggleShareBarItem.image = UIImage(systemName: "rectangle.on.rectangle.slash")
            } else {
                shareAction.getShareCanvas()?.unSubscribe(with: sharerView)
                sharerView.isHidden = true
                shareBtnStackView.isHidden = true
            }
        }
        
        localViewDuringShare.isHidden = !(shareStatus == .start || shareStatus == .resume)
    }

    func onUserLeave(_: ZoomVideoSDKUserHelper?, users: [ZoomVideoSDKUser]?) {
        guard let users = users,
              let myself = ZoomVideoSDK.shareInstance()?.getSession()?.getMySelf() else { return }

        for user in users where user.getID() != myself.getID() {
            if let canvas = user.getVideoCanvas(),
               let views = remoteUserViews[user.getID()]
            {
                Task(priority: .background) {
                    canvas.unSubscribe(with: views.view)
                    if let container = views.view.superview {
                        container.removeFromSuperview()
                    }
                }
                remoteUserViews.removeValue(forKey: user.getID())
            }
        }
    }

    func onSessionLeave() {
        if let myCanvas = ZoomVideoSDK.shareInstance()?.getSession()?.getMySelf()?.getVideoCanvas() {
            Task(priority: .background) {
                myCanvas.unSubscribe(with: self.localView)
            }
        }

        ZoomVideoSDK.shareInstance()?.getSession()?.getRemoteUsers()?.forEach { user in
            if let canvas = user.getVideoCanvas() {
                Task(priority: .background) {
                    canvas.unSubscribe(with: self.videoStackView)
                }
            }
        }

        presentingViewController?.dismiss(animated: true)
    }
}

// MARK: - UITabBarDelegate

extension SessionViewController: UITabBarDelegate {
    func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        tabBar.selectedItem = nil

        switch item.tag {
        case ControlOption.toggleVideo.rawValue:
            handleVideoToggle(tabBar)
        case ControlOption.toggleAudio.rawValue:
            handleAudioToggle(tabBar)
        case ControlOption.toggleShare.rawValue:
            handleShareToggle(tabBar)
        case ControlOption.leaveSession.rawValue:
            tabBar.isUserInteractionEnabled = false
            ZoomVideoSDK.shareInstance()?.leaveSession(false)
        default:
            break
        }
    }

    private func handleVideoToggle(_ tabBar: UITabBar) {
        #if targetEnvironment(simulator)
        showError(message: "Simulator detected, video is not supported", dismiss: false)
        #else
        // your real device code
        toggleVideoBarItem.isEnabled = false
        
        guard let canvas = ZoomVideoSDK.shareInstance()?.getSession()?.getMySelf()?.getVideoCanvas(),
              let videoHelper = ZoomVideoSDK.shareInstance()?.getVideoHelper(),
              let isVideoOn = canvas.videoStatus()?.on else { return }
        
        Task(priority: .background) {
            let _ = isVideoOn ? videoHelper.stopVideo() : videoHelper.startVideo()
            // Update UI to reflect new video state
            let newVideoState = !isVideoOn
            self.toggleVideoBarItem.title = newVideoState ? "Stop Video" : "Start Video"
            self.toggleVideoBarItem.image = UIImage(systemName: newVideoState ? "video.slash" : "video")
            self.localPlaceholder?.isHidden = newVideoState
        }
        
        toggleVideoBarItem.isEnabled = true
        #endif
    }

    private func handleAudioToggle(_ tabBar: UITabBar) {
        toggleAudioBarItem.isEnabled = false

        guard let myUser = ZoomVideoSDK.shareInstance()?.getSession()?.getMySelf(),
              let audioStatus = myUser.audioStatus(),
              let audioHelper = ZoomVideoSDK.shareInstance()?.getAudioHelper() else { return }

        if audioStatus.audioType == .none {
            audioHelper.startAudio()
        } else {
            let _ = audioStatus.isMuted ? audioHelper.unmuteAudio(myUser) : audioHelper.muteAudio(myUser)
            toggleAudioBarItem.title = audioStatus.isMuted ? "Mute" : "Start Audio"
            toggleAudioBarItem.image = UIImage(systemName: audioStatus.isMuted ? "mic.slash" : "mic")
        }

        toggleAudioBarItem.isEnabled = true
    }
    
    private func handleShareToggle(_ tabBar: UITabBar) {
        #if targetEnvironment(simulator)
        showError(message: "Simulator detected, share is not supported", dismiss: false)
        #else
        guard let shareHelper = ZoomVideoSDK.shareInstance()?.getShareHelper() else { return }
        
        guard shareHelper.isMultiShareEnabled() != true || shareHelper.isShareLocked() else {
            showError(message: "Screen sharing is locked. Wait for host to be in.", dismiss: false)
            return
        }
        
        guard !shareHelper.isOtherSharing() else {
            showError(message: "Others is sharing. Only 1 share allowed.", dismiss: false)
            return
        }
        
        guard shareHelper.isSupportInAppScreenShare() else {
            showError(message: "In app screen share is not supported.", dismiss: false)
            return
        }
        
        toggleShareBarItem.isEnabled = false
        
        let alert = UIAlertController(
            title: "Screen share mode",
            message: "1. InAppScreenShare - Share your entire app + any system API UI (FilePicker, AlertBox and etc).\n2. ShareWithView - Share a specific view of your choice. In the sample app we have simplify the process with a sample_health_report.pdf.",
            preferredStyle: .alert
        )
        
        if shareHelper.isSharingOut() {
            let error = shareHelper.stopShare()
            if error == .Errors_Success {
                print("stopShare")
                toggleShareBarItem.title = "Start Share"
                toggleShareBarItem.image = UIImage(systemName: "rectangle.on.rectangle")
            } else {
                print("Fail stopShare")
            }
        } else {
            alert.addAction(UIAlertAction(title: "InAppScreenShare", style: .default, handler: { _ in
                self.handleShareSelection(with: .InAppScreenShare)
            }))
            
            alert.addAction(UIAlertAction(title: "ShareWithView", style: .default, handler: { _ in
                self.handleShareSelection(with: .ShareWithView)
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in
                print("Cancel share")
            }))
            
            present(alert, animated: true, completion: nil)
        }
        
        toggleShareBarItem.isEnabled = true
        #endif
    }
    
    func handleShareSelection(with chosenShare: ShareSelection) {
        guard let shareHelper = ZoomVideoSDK.shareInstance()?.getShareHelper() else { return }
        chosenShareType = chosenShare
        
        var error = ZoomVideoSDKError.Errors_Audio_Module_Error
        switch chosenShare {
        case .InAppScreenShare:
            error = shareHelper.startInAppScreenShare()
            if error == .Errors_Success {
                print("startInAppScreenShare")
            } else {
                print("Fail startInAppScreenShare")
            }
        case .ShareWithView:
            openBundledPDF()
            error = shareHelper.startShare(with: sharedPDFView)
            if error == .Errors_Success {
                print("startShareWithView")
            } else {
                print("Fail startShareWithView")
            }
        }
        
        if error == .Errors_Success {
            toggleShareBarItem.title = "Stop Share"
            toggleShareBarItem.image = UIImage(systemName: "rectangle.on.rectangle.slash")
        }
    }
}
