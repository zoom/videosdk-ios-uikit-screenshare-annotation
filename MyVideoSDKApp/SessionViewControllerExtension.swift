import UIKit
import UniformTypeIdentifiers
import PDFKit
import ZoomVideoSDK

extension SessionViewController: UIDocumentPickerDelegate {
    func setupUI() {
        setupViews()
        setupConstraints()
        setupTabBar()
    }

    private func setupViews() {
        // Setup scroll view
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = true
        scrollView.alwaysBounceVertical = true

        // Setup video stack view
        videoStackView.axis = .vertical
        videoStackView.spacing = 8
        videoStackView.alignment = .fill
        videoStackView.distribution = .fillEqually

        for item in [loadingLabel, scrollView, tabBar] {
            item.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(item)
        }

        scrollView.addSubview(videoStackView)
        videoStackView.translatesAutoresizingMaskIntoConstraints = false
        
        sharerView.isHidden = true
        shareBtnStackView.isHidden = true
        shareBtnStackView.spacing = 20
        sharedPDFView.isHidden = true
        view.addSubview(sharerView)
        sharerView.translatesAutoresizingMaskIntoConstraints = false
        
        // Setup share related view
        sharerView.backgroundColor = .black
        view.addSubview(sharedPDFView)
        sharedPDFView.autoScales = true
        sharedPDFView.translatesAutoresizingMaskIntoConstraints = false
        
        shareBtnStackView.backgroundColor = .white.withAlphaComponent(0.8)
        shareBtnStackView.axis = .vertical
        
        sharePDFBtn.setImage(UIImage(systemName: "doc")?.withConfiguration(UIImage.SymbolConfiguration(pointSize: 30, weight: .regular)), for: .normal)
        sharePDFBtn.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
        sharePDFBtn.addTarget(self, action: #selector(pickPDF), for: .touchUpInside)
        shareBtnStackView.addArrangedSubview(sharePDFBtn)
        
        shareDrawBtn.setImage(UIImage(systemName: "pencil")?.withConfiguration(UIImage.SymbolConfiguration(pointSize: 30, weight: .regular)), for: .normal)
        shareDrawBtn.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
        shareDrawBtn.addTarget(self, action: #selector(toggleDraw), for: .touchUpInside)
        shareBtnStackView.addArrangedSubview(shareDrawBtn)
        
        view.addSubview(shareBtnStackView)
        shareBtnStackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Setup local view during share
        localViewDuringShare.isHidden = true
        view.addSubview(localViewDuringShare)
        localViewDuringShare.translatesAutoresizingMaskIntoConstraints = false
        localViewDuringShare.layer.cornerRadius = 15
        localViewDuringShare.clipsToBounds = true

        loadingLabel.text = "Loading Session..."
        loadingLabel.textColor = .white
    }

    private func setupConstraints() {
        // Main container constraints
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: tabBar.topAnchor),

            videoStackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 8),
            videoStackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 8),
            videoStackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -8),
            videoStackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -8),
            videoStackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -16),
            
            // sharerView is for viewer
            sharerView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, multiplier: 1),
            sharerView.heightAnchor.constraint(equalTo: scrollView.heightAnchor, multiplier: 1),
            sharerView.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            sharerView.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor),
            
            // sharedPDFView is for sharer
            sharedPDFView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            sharedPDFView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            sharedPDFView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            sharedPDFView.bottomAnchor.constraint(equalTo: tabBar.topAnchor),
            
            shareBtnStackView.centerYAnchor.constraint(equalTo: sharerView.centerYAnchor),
            shareBtnStackView.leadingAnchor.constraint(equalTo: sharerView.leadingAnchor, constant: 8),
            shareBtnStackView.widthAnchor.constraint(equalToConstant: 40),
            
            // localViewDuringShare is for local user during screen sharing
            localViewDuringShare.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 5),
            localViewDuringShare.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            localViewDuringShare.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.55),
            localViewDuringShare.heightAnchor.constraint(equalTo: localViewDuringShare.widthAnchor, multiplier: 9/16),

            tabBar.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            tabBar.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            tabBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])

        // Loading label
        loadingLabel.center(in: view, yOffset: -30)
    }

    private func setupTabBar() {
        tabBar.delegate = self
        tabBar.isHidden = true
        let leaveSessionBarItem = UITabBarItem(title: "Leave Session", image: UIImage(systemName: "phone.down"), tag: ControlOption.leaveSession.rawValue)
        tabBar.items = [toggleVideoBarItem, toggleAudioBarItem, toggleShareBarItem, leaveSessionBarItem]
    }

    func addLocalViewToGrid() {
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = .black

        localView.translatesAutoresizingMaskIntoConstraints = false
        let placeholder = createPlaceholderView(with: userName)
        localPlaceholder = placeholder

        containerView.addSubview(localView)
        containerView.addSubview(placeholder)

        NSLayoutConstraint.activate([
            containerView.heightAnchor.constraint(equalTo: containerView.widthAnchor, multiplier: 1.0 / videoViewAspectRatio),

            localView.topAnchor.constraint(equalTo: containerView.topAnchor),
            localView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            localView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            localView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),

            placeholder.topAnchor.constraint(equalTo: containerView.topAnchor),
            placeholder.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            placeholder.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            placeholder.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        ])

        videoStackView.addArrangedSubview(containerView)
    }
    
    func addLocalViewDuringShare() -> (view: UIView, placeholder: UIView) {
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = .black

        let userView = UIView()
        let placeholderView = createPlaceholderView(with: userName)

        userView.translatesAutoresizingMaskIntoConstraints = false
        placeholderView.translatesAutoresizingMaskIntoConstraints = false

        containerView.addSubview(userView)
        containerView.addSubview(placeholderView)
        
        localViewDuringShare.addSubview(containerView)

        NSLayoutConstraint.activate([
            containerView.heightAnchor.constraint(equalTo: localViewDuringShare.heightAnchor),
            containerView.widthAnchor.constraint(equalTo: localViewDuringShare.widthAnchor),
            
            userView.topAnchor.constraint(equalTo: containerView.topAnchor),
            userView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            userView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            userView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),

            placeholderView.topAnchor.constraint(equalTo: containerView.topAnchor),
            placeholderView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            placeholderView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            placeholderView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        ])
        
        return (userView, placeholderView)
    }

    func addRemoteUserView(for user: ZoomVideoSDKUser) -> (view: UIView, placeholder: UIView) {
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = .black

        let userView = UIView()
        let placeholderView = createPlaceholderView(with: user.getName() ?? "")

        userView.translatesAutoresizingMaskIntoConstraints = false
        placeholderView.translatesAutoresizingMaskIntoConstraints = false

        containerView.addSubview(userView)
        containerView.addSubview(placeholderView)

        NSLayoutConstraint.activate([
            containerView.heightAnchor.constraint(equalTo: containerView.widthAnchor, multiplier: 1.0 / videoViewAspectRatio),

            userView.topAnchor.constraint(equalTo: containerView.topAnchor),
            userView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            userView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            userView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),

            placeholderView.topAnchor.constraint(equalTo: containerView.topAnchor),
            placeholderView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            placeholderView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            placeholderView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        ])

        videoStackView.addArrangedSubview(containerView)

        return (userView, placeholderView)
    }
    
    @objc func pickPDF() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.pdf])
        picker.delegate = self
        present(picker, animated: true)
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        // Gain temporary read access to files outside your sandbox.
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
        
        // Coordinate reading (helps with iCloud/third-party providers ensuring the file is available).
        let coordinator = NSFileCoordinator()
        var coordError: NSError?
        
        var readableURL: URL?
        
        coordinator.coordinate(readingItemAt: url, options: [], error: &coordError) { securedURL in
            // Copy to a local temp URL you fully control (robust across providers).
            let tmpURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("pdf")
            do {
                // If the provider streams the file, copying forces a local, complete file.
                try FileManager.default.copyItem(at: securedURL, to: tmpURL)
                readableURL = tmpURL
            } catch {
                // If copy fails (e.g., already local), fall back to using the securedURL directly.
                readableURL = securedURL
            }
        }
        
        if let e = coordError {
            print("NSFileCoordinator error: \(e)")
        }
        
        guard let openURL = readableURL else {
            print("No readable URL resolved.")
            return
        }
        
        // Try opening with URL first.
        if let doc = PDFDocument(url: openURL) {
            sharedPDFView.document = doc
            sharedPDFView.autoScales = true
            sharedPDFView.isHidden = false
            shareBtnStackView.isHidden = false
        }
    }
    
    func openBundledPDF() {
        // Make sure your PDF is added to the project and "Target Membership" is checked
        if let pdfURL = Bundle.main.url(forResource: "sample_health_report", withExtension: "pdf") {
            if let pdfDoc = PDFDocument(url: pdfURL) {
                sharedPDFView.autoScales = true
                sharedPDFView.document = pdfDoc
                sharedPDFView.isHidden = false
                shareBtnStackView.isHidden = true
            }
        } else {
            print("Could not find PDF in bundle")
        }
    }
    
    @objc func toggleDraw() {
        guard let shareHelper = ZoomVideoSDK.shareInstance()?.getShareHelper() else { return }
        
        shareHelper.disableViewerAnnotation(false)
        
        guard shareHelper.isAnnotationFeatureSupport(), !shareHelper.isViewerAnnotationDisabled() else {
            showError(message: "Annotation is not supported", dismiss: false)
            return
        }
        
        if annotationHelper != nil {
            shareHelper.destroy(annotationHelper)
        }
        
        if shareHelper.isSharingOut() {
            guard sharedPDFView.document != nil else {
                showError(message: "Select a PDF first.", dismiss: false)
                return
            }
            annotationHelper = shareHelper.createAnnotationHelper(nil) // Nil for self sharing as mentioned for shareHelper.createAnnotationHelper
        } else if shareHelper.isOtherSharing() {
            annotationHelper = shareHelper.createAnnotationHelper(sharerView)
        }
        
        guard let annotationHelper = annotationHelper else {
            showError(message: "You are not allowed to annotate", dismiss: false)
            return
        }
        
        if annotationStarted {
            let error = annotationHelper.stopAnnotation()
            if error == .Errors_Success {
                shareDrawBtn.setImage(UIImage(systemName: "pencil")?.withConfiguration(UIImage.SymbolConfiguration(pointSize: 30, weight: .regular)), for: .normal)
                annotationStarted = false
            }
        } else {
            let error = annotationHelper.startAnnotation()
            if error == .Errors_Success {
                var errorInAppAnnotationResult: ZoomVideoSDKError?
                switch chosenShareType {
                case .InAppScreenShare:
                    if (shareHelper.isSharingOut()) {
                        errorInAppAnnotationResult = shareHelper.setAnnotationView(sharedPDFView)
                    } else {
                        errorInAppAnnotationResult = shareHelper.setAnnotationView(sharerView)
                    }
                    if errorInAppAnnotationResult == .Errors_Success {
                        annotationHelper.setToolType(.pen)
                        annotationHelper.setToolColor(.red)
                        annotationHelper.setToolWidth(2)
                        shareDrawBtn.setImage(UIImage(systemName: "pencil.slash")?.withConfiguration(UIImage.SymbolConfiguration(pointSize: 30, weight: .regular)), for: .normal)
                    } else {
                        print("Fail to set annotation")
                    }
                case .ShareWithView:
                    annotationHelper.setToolType(.pen)
                    annotationHelper.setToolColor(.red)
                    annotationHelper.setToolWidth(2)
                    shareDrawBtn.setImage(UIImage(systemName: "pencil.slash")?.withConfiguration(UIImage.SymbolConfiguration(pointSize: 30, weight: .regular)), for: .normal)
                default:
                    return
                }
                annotationStarted = true
            } else {
                print("Fail to start annotation")
            }
        }
    }
}

func createPlaceholderView(with name: String) -> UIView {
    let placeholderView = UIView()
    placeholderView.translatesAutoresizingMaskIntoConstraints = false
    placeholderView.backgroundColor = .darkGray
    
    let stackView = UIStackView()
    stackView.axis = .vertical
    stackView.spacing = 8
    stackView.alignment = .center
    stackView.translatesAutoresizingMaskIntoConstraints = false
    
    let imageView = UIImageView(image: UIImage(systemName: "person.fill"))
    imageView.contentMode = .scaleAspectFit
    imageView.tintColor = .white
    imageView.translatesAutoresizingMaskIntoConstraints = false
    
    let label = UILabel()
    label.text = name
    label.textColor = .white
    label.font = .systemFont(ofSize: 16, weight: .medium)
    label.translatesAutoresizingMaskIntoConstraints = false
    
    stackView.addArrangedSubview(imageView)
    stackView.addArrangedSubview(label)
    placeholderView.addSubview(stackView)
    
    NSLayoutConstraint.activate([
        imageView.heightAnchor.constraint(equalToConstant: 50),
        imageView.widthAnchor.constraint(equalToConstant: 50),

        stackView.centerXAnchor.constraint(equalTo: placeholderView.centerXAnchor),
        stackView.centerYAnchor.constraint(equalTo: placeholderView.centerYAnchor),
    ])

    return placeholderView
}

// Helper extensions
extension UIView {
    func center(in view: UIView, yOffset: CGFloat = 0) {
        translatesAutoresizingMaskIntoConstraints = false
        centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: yOffset).isActive = true
    }

    func pinToSafeArea(of view: UIView) {
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
    }

    func anchor(top: NSLayoutYAxisAnchor? = nil, trailing: NSLayoutXAxisAnchor? = nil, padding: UIEdgeInsets = .zero, size: CGSize) {
        translatesAutoresizingMaskIntoConstraints = false
        
        if let top = top {
            topAnchor.constraint(equalTo: top, constant: padding.top).isActive = true
        }
        if let trailing = trailing {
            trailingAnchor.constraint(equalTo: trailing, constant: -padding.right).isActive = true
        }
        
        widthAnchor.constraint(equalToConstant: size.width).isActive = true
        heightAnchor.constraint(equalToConstant: size.height).isActive = true
    }
}
