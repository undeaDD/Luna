//
//  PlayerViewController.swift
//  test
//
//  Created by Francesco on 28/09/25.
//

import UIKit
import SwiftUI
import AVFoundation

final class PlayerViewController: UIViewController {
    private let videoContainer: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    
    private let displayLayer = AVSampleBufferDisplayLayer()
    
    private let centerPlayPauseButton: UIButton = {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        let configuration = UIImage.SymbolConfiguration(pointSize: 44, weight: .bold)
        let image = UIImage(systemName: "play.fill", withConfiguration: configuration)
        b.setImage(image, for: .normal)
        b.tintColor = .white
        b.clipsToBounds = true
        return b
    }()
    
    private let controlsOverlayView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = UIColor(white: 0.0, alpha: 0.4)
        v.alpha = 0.0
        v.isUserInteractionEnabled = false
        return v
    }()
    
    private let closeButton: UIButton = {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        let cfg = UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
        let img = UIImage(systemName: "xmark", withConfiguration: cfg)
        b.setImage(img, for: .normal)
        b.tintColor = .white
        b.alpha = 0.0
        return b
    }()
    
    private let pipButton: UIButton = {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        let cfg = UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
        let img = UIImage(systemName: "pip.enter", withConfiguration: cfg)
        b.setImage(img, for: .normal)
        b.tintColor = .white
        b.alpha = 0.0
        return b
    }()
    
    private let progressContainer: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = .clear
        return v
    }()
    private var progressHostingController: UIHostingController<AnyView>?
    private var lastHostedDuration: Double = 0
    
    class ProgressModel: ObservableObject {
        @Published var position: Double = 0
        @Published var duration: Double = 1
    }
    private var progressModel = ProgressModel()
    
    private lazy var renderer: MPVSoftwareRenderer = {
        let r = MPVSoftwareRenderer(displayLayer: displayLayer)
        r.delegate = self
        return r
    }()
    
    private var isSeeking = false
    private var cachedDuration: Double = 0
    private var cachedPosition: Double = 0
    private var pipController: PiPController?
    private var initialURL: URL?
    private var initialPreset: PlayerPreset?
    
    private var controlsHideWorkItem: DispatchWorkItem?
    private var controlsVisible: Bool = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupLayout()
        setupActions()
        
        do {
            try renderer.start()
        } catch {
            print("Failed to start MPV renderer: \(error)")
        }
        
        displayLayer.videoGravity = .resizeAspect
        pipController = PiPController(sampleBufferDisplayLayer: displayLayer)
        pipController?.delegate = self
        
        showControlsTemporarily()
        
        if let url = initialURL, let preset = initialPreset {
            load(url: url, preset: preset)
        }
        
        updateProgressHostingController()
        
        NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        displayLayer.frame = videoContainer.bounds
    }
    
    deinit {
        pipController?.delegate = nil
        if pipController?.isPictureInPictureActive == true {
            pipController?.stopPictureInPicture()
        }
        pipController?.invalidate()
        renderer.stop()
        displayLayer.removeFromSuperlayer()
        NotificationCenter.default.removeObserver(self)
    }
    
    convenience init(url: URL, preset: PlayerPreset) {
        self.init(nibName: nil, bundle: nil)
        self.initialURL = url
        self.initialPreset = preset
    }
    
    func load(url: URL, preset: PlayerPreset) {
        renderer.load(url: url, with: preset)
    }
    
    private func setupLayout() {
        view.addSubview(videoContainer)
        videoContainer.layer.addSublayer(displayLayer)
        videoContainer.addSubview(controlsOverlayView)
        videoContainer.addSubview(centerPlayPauseButton)
        videoContainer.addSubview(progressContainer)
        videoContainer.addSubview(closeButton)
        videoContainer.addSubview(pipButton)
        
        NSLayoutConstraint.activate([
            videoContainer.topAnchor.constraint(equalTo: view.topAnchor),
            videoContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            videoContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            videoContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            progressContainer.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
            progressContainer.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12),
            progressContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            progressContainer.heightAnchor.constraint(equalToConstant: 44),
            
            controlsOverlayView.topAnchor.constraint(equalTo: videoContainer.topAnchor),
            controlsOverlayView.leadingAnchor.constraint(equalTo: videoContainer.leadingAnchor),
            controlsOverlayView.trailingAnchor.constraint(equalTo: videoContainer.trailingAnchor),
            controlsOverlayView.bottomAnchor.constraint(equalTo: videoContainer.bottomAnchor),
        ])
        
        NSLayoutConstraint.activate([
            centerPlayPauseButton.centerXAnchor.constraint(equalTo: videoContainer.centerXAnchor),
            centerPlayPauseButton.centerYAnchor.constraint(equalTo: videoContainer.centerYAnchor),
            centerPlayPauseButton.widthAnchor.constraint(equalToConstant: 72),
            centerPlayPauseButton.heightAnchor.constraint(equalToConstant: 72),
            
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            closeButton.leadingAnchor.constraint(equalTo: progressContainer.leadingAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 24),
            closeButton.heightAnchor.constraint(equalToConstant: 24),
            
            pipButton.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),
            pipButton.leadingAnchor.constraint(equalTo: closeButton.trailingAnchor, constant: 12),
            pipButton.widthAnchor.constraint(equalToConstant: 36),
            pipButton.heightAnchor.constraint(equalToConstant: 30),
        ])
    }
    
    private func setupActions() {
        centerPlayPauseButton.addTarget(self, action: #selector(centerPlayPauseTapped), for: .touchUpInside)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        pipButton.addTarget(self, action: #selector(pipTapped), for: .touchUpInside)
        let tap = UITapGestureRecognizer(target: self, action: #selector(containerTapped))
        videoContainer.addGestureRecognizer(tap)
    }
    
    @objc private func playPauseTapped() {
        if renderer.isPausedState {
            renderer.play()
            updatePlayPauseButton(isPaused: false)
        } else {
            renderer.pausePlayback()
            updatePlayPauseButton(isPaused: true)
        }
    }
    
    @objc private func centerPlayPauseTapped() {
        playPauseTapped()
    }
    
    private func updateProgressHostingController() {
        struct ProgressHostView: View {
            @ObservedObject var model: ProgressModel
            var onEditingChanged: (Bool) -> Void
            var body: some View {
                MusicProgressSlider(value: Binding(get: { model.position }, set: { model.position = $0 }), inRange: 0...max(model.duration, 1.0), activeFillColor: .white, fillColor: .white, textColor: .white.opacity(0.7), emptyColor: .white.opacity(0.3), height: 33, onEditingChanged: onEditingChanged)
            }
        }
        
        if progressHostingController != nil {
            return
        }
        
        let host = UIHostingController(rootView: AnyView(ProgressHostView(model: progressModel, onEditingChanged: { [weak self] editing in
            guard let self = self else { return }
            self.isSeeking = editing
            if !editing {
                self.renderer.seek(to: max(0, self.progressModel.position))
            }
        })))
        
        progressHostingController = host
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.backgroundColor = .clear
        host.view.isOpaque = false
        progressContainer.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: progressContainer.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: progressContainer.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: progressContainer.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: progressContainer.trailingAnchor),
        ])
        host.didMove(toParent: self)
    }
    
    private func updatePlayPauseButton(isPaused: Bool) {
        DispatchQueue.main.async {
            let config = UIImage.SymbolConfiguration(pointSize: 44, weight: .bold)
            let name = isPaused ? "play.fill" : "pause.fill"
            let img = UIImage(systemName: name, withConfiguration: config)
            self.centerPlayPauseButton.setImage(img, for: .normal)
            self.centerPlayPauseButton.isHidden = false
            self.showControlsTemporarily()
        }
    }
    
    @objc private func containerTapped() {
        if controlsVisible {
            hideControls()
        } else {
            showControlsTemporarily()
        }
    }
    
    private func showControlsTemporarily() {
        controlsHideWorkItem?.cancel()
        controlsVisible = true
        DispatchQueue.main.async {
            UIView.animate(withDuration: 0.15) {
                self.centerPlayPauseButton.alpha = 1.0
                self.controlsOverlayView.alpha = 1.0
                self.progressContainer.alpha = 1.0
                self.closeButton.alpha = 1.0
                self.pipButton.alpha = 1.0
            }
        }
        let work = DispatchWorkItem { [weak self] in
            self?.hideControls()
        }
        controlsHideWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: work)
    }
    
    private func hideControls() {
        controlsHideWorkItem?.cancel()
        controlsVisible = false
        DispatchQueue.main.async {
            UIView.animate(withDuration: 0.15) {
                self.centerPlayPauseButton.alpha = 0.0
                self.controlsOverlayView.alpha = 0.0
                self.progressContainer.alpha = 0.0
                self.closeButton.alpha = 0.0
                self.pipButton.alpha = 0.0
            }
        }
    }
    
    @objc private func closeTapped() {
        pipController?.delegate = nil
        if pipController?.isPictureInPictureActive == true {
            pipController?.stopPictureInPicture()
        }
        
        renderer.stop()
        
        if presentingViewController != nil {
            dismiss(animated: true, completion: nil)
        } else {
            view.window?.rootViewController?.dismiss(animated: true, completion: nil)
        }
    }
    
    @objc private func pipTapped() {
        guard let pip = pipController else { return }
        if pip.isPictureInPictureActive {
            pip.stopPictureInPicture()
        } else if pip.isPictureInPicturePossible {
            pip.startPictureInPicture()
        }
    }
    
    private func updatePosition(_ position: Double, duration: Double) {
        DispatchQueue.main.async {
            self.cachedDuration = duration
            self.cachedPosition = position
            if duration > 0 {
                self.updateProgressHostingController()
            }
            self.progressModel.position = position
            self.progressModel.duration = max(duration, 1.0)
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds > 0 else { return "00:00" }
        let total = Int(round(seconds))
        let s = total % 60
        let m = (total / 60) % 60
        let h = total / 3600
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%02d:%02d", m, s)
        }
    }
}

// MARK: - MPVSoftwareRendererDelegate
extension PlayerViewController: MPVSoftwareRendererDelegate {
    func renderer(_ renderer: MPVSoftwareRenderer, didUpdatePosition position: Double, duration: Double) {
        updatePosition(position, duration: duration)
    }
    
    func renderer(_ renderer: MPVSoftwareRenderer, didChangePause isPaused: Bool) {
        updatePlayPauseButton(isPaused: isPaused)
    }
}

// MARK: - PiP Support
extension PlayerViewController: PiPControllerDelegate {
    func pipController(_ controller: PiPController, willStartPictureInPicture: Bool) { }
    func pipController(_ controller: PiPController, didStartPictureInPicture: Bool) { }
    func pipController(_ controller: PiPController, willStopPictureInPicture: Bool) { }
    func pipController(_ controller: PiPController, didStopPictureInPicture: Bool) { }
    func pipController(_ controller: PiPController, restoreUserInterfaceForPictureInPictureStop completionHandler: @escaping (Bool) -> Void) {
        if presentedViewController != nil {
            dismiss(animated: true) { completionHandler(true) }
        } else {
            completionHandler(true)
        }
    }
    func pipControllerPlay(_ controller: PiPController) { renderer.play() }
    func pipControllerPause(_ controller: PiPController) { renderer.pausePlayback() }
    func pipController(_ controller: PiPController, skipByInterval interval: CMTime) {
        let seconds = CMTimeGetSeconds(interval)
        let target = max(0, cachedPosition + seconds)
        renderer.seek(to: target)
    }
    func pipControllerIsPlaying(_ controller: PiPController) -> Bool { return !renderer.isPausedState }
    func pipControllerDuration(_ controller: PiPController) -> Double { return cachedDuration }
    
    @objc private func appDidEnterBackground() {
        DispatchQueue.main.async { [weak self] in
            guard let self, let pip = self.pipController else { return }
            if pip.isPictureInPicturePossible && !pip.isPictureInPictureActive {
                pip.startPictureInPicture()
            }
        }
    }
    
    @objc private func appWillEnterForeground() {
        DispatchQueue.main.async { [weak self] in
            guard let self, let pip = self.pipController else { return }
            if pip.isPictureInPictureActive {
                pip.stopPictureInPicture()
            }
        }
    }
}
