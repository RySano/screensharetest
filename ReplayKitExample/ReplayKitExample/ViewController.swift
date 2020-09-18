//
//  ViewController.swift
//  ReplayKitExample
//
//  Copyright © 2018-2019 Twilio. All rights reserved.
//

import AVKit
import UIKit
import ReplayKit
import SafariServices
import TwilioVideo

class ViewController: UIViewController {

    @IBOutlet weak var spinner: UIActivityIndicatorView!
    @IBOutlet weak var broadcastButton: UIButton!
    // Treat this view as generic, since RPSystemBroadcastPickerView is only available on iOS 12.0 and above.
    @IBOutlet weak var broadcastPickerView: UIView?
    @IBOutlet weak var infoLabel: UILabel?
    @IBOutlet var settingsButton: UIBarButtonItem?

    // Conference state.
    var screenTrack: LocalVideoTrack?
    
    // Broadcast state. Our extension will capture samples from ReplayKit, and publish them in a Room.
    var broadcastController: RPBroadcastController?

    static let kBroadcastExtensionBundleId = "com.twilio.ReplayKitExample.BroadcastVideoExtension"

    static let kStartBroadcastButtonTitle = "Start Broadcast"
    static let kInProgressBroadcastButtonTitle = "Broadcasting"
    static let kStopBroadcastButtonTitle = "Stop Broadcast"
    static let kRecordingAvailableInfo = "Ready to share the screen in a Broadcast (extension)."
    static let kRecordingNotAvailableInfo = "ReplayKit is not available at the moment. Another app might be recording, or AirPlay may be in use."

    // An application has a much higher memory limit than an extension. You may choose to deliver full sized buffers instead.
    static let kDownscaleBuffers = true

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        broadcastButton.setTitle(ViewController.kStartBroadcastButtonTitle, for: .normal)
        broadcastButton.layer.cornerRadius = 4

        self.navigationController?.navigationBar.barTintColor = UIColor(red: 226.0/255.0,
                                                                        green: 29.0/255.0,
                                                                        blue: 37.0/255.0,
                                                                        alpha: 1.0)
        self.navigationController?.navigationBar.tintColor = UIColor.white
        self.navigationController?.navigationBar.barStyle = UIBarStyle.black

        // The setter fires an availability changed event, but we check rather than rely on this implementation detail.
        RPScreenRecorder.shared().delegate = self
        checkRecordingAvailability()

        NotificationCenter.default.addObserver(forName: UIScreen.capturedDidChangeNotification, object: UIScreen.main, queue: OperationQueue.main) { (notification) in
            if self.broadcastPickerView != nil && self.screenTrack == nil {
                let isCaptured = UIScreen.main.isCaptured
                let title = isCaptured ? ViewController.kInProgressBroadcastButtonTitle : ViewController.kStartBroadcastButtonTitle
                self.broadcastButton.setTitle(title, for: .normal)
                isCaptured ? self.spinner.startAnimating() : self.spinner.stopAnimating()
            }
        }
        setupPickerView()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    func setupPickerView() {
        // Swap the button for an RPSystemBroadcastPickerView.
        #if !targetEnvironment(simulator)
        // iOS 13.0 throws an NSInvalidArgumentException when RPSystemBroadcastPickerView is used to start a broadcast.
        // https://stackoverflow.com/questions/57163212/get-nsinvalidargumentexception-when-trying-to-present-rpsystembroadcastpickervie

        let pickerView = RPSystemBroadcastPickerView(frame: CGRect(x: 0,
                                                                   y: 0,
                                                                   width: view.bounds.width,
                                                                   height: 80))
        pickerView.translatesAutoresizingMaskIntoConstraints = false
        pickerView.preferredExtension = ViewController.kBroadcastExtensionBundleId

        // Theme the picker view to match the white that we want.
        if let button = pickerView.subviews.first as? UIButton {
            button.imageView?.tintColor = UIColor.white
        }

        view.addSubview(pickerView)

        self.broadcastPickerView = pickerView
        broadcastButton.isEnabled = false
        broadcastButton.titleEdgeInsets = UIEdgeInsets(top: 34, left: 0, bottom: 0, right: 0)

        let centerX = NSLayoutConstraint(item:pickerView,
                                         attribute: NSLayoutConstraint.Attribute.centerX,
                                         relatedBy: NSLayoutConstraint.Relation.equal,
                                         toItem: broadcastButton,
                                         attribute: NSLayoutConstraint.Attribute.centerX,
                                         multiplier: 1,
                                         constant: 0);
        self.view.addConstraint(centerX)
        let centerY = NSLayoutConstraint(item: pickerView,
                                         attribute: NSLayoutConstraint.Attribute.centerY,
                                         relatedBy: NSLayoutConstraint.Relation.equal,
                                         toItem: broadcastButton,
                                         attribute: NSLayoutConstraint.Attribute.centerY,
                                         multiplier: 1,
                                         constant: -10);
        self.view.addConstraint(centerY)
        let width = NSLayoutConstraint(item: pickerView,
                                       attribute: NSLayoutConstraint.Attribute.width,
                                       relatedBy: NSLayoutConstraint.Relation.equal,
                                       toItem: self.broadcastButton,
                                       attribute: NSLayoutConstraint.Attribute.width,
                                       multiplier: 1,
                                       constant: 0);
        self.view.addConstraint(width)
        let height = NSLayoutConstraint(item: pickerView,
                                        attribute: NSLayoutConstraint.Attribute.height,
                                        relatedBy: NSLayoutConstraint.Relation.equal,
                                        toItem: self.broadcastButton,
                                        attribute: NSLayoutConstraint.Attribute.height,
                                        multiplier: 1,
                                        constant: 0);
        self.view.addConstraint(height)
        #endif
    }

    // MARK:- Private
    private func checkRecordingAvailability() {
        let isScreenRecordingAvailable = RPScreenRecorder.shared().isAvailable
        broadcastButton.isHidden = !isScreenRecordingAvailable
        infoLabel?.text = isScreenRecordingAvailable ? ViewController.kRecordingAvailableInfo : ViewController.kRecordingNotAvailableInfo
    }

    private func startBroadcast() {
        self.broadcastController?.startBroadcast { [unowned self] error in
            DispatchQueue.main.async {
                if let theError = error {
                    print("Broadcast controller failed to start with error:", theError as Any)
                } else {
                    print("Broadcast controller started.")
                    self.spinner.startAnimating()
                    self.broadcastButton.setTitle(ViewController.kStopBroadcastButtonTitle, for: .normal)
                }
            }
        }
    }
}

// MARK:- RPBroadcastActivityViewControllerDelegate
extension ViewController: RPBroadcastActivityViewControllerDelegate {
    func broadcastActivityViewController(_ broadcastActivityViewController: RPBroadcastActivityViewController, didFinishWith broadcastController: RPBroadcastController?, error: Error?) {
        DispatchQueue.main.async {
            self.broadcastController = broadcastController
            self.broadcastController?.delegate = self
            self.infoLabel?.text = ""

            broadcastActivityViewController.dismiss(animated: true) {
                self.startBroadcast()
            }
        }
    }
}

// MARK:- RPBroadcastControllerDelegate
extension ViewController: RPBroadcastControllerDelegate {
    func broadcastController(_ broadcastController: RPBroadcastController, didFinishWithError error: Error?) {
        // Update the button UI.
        DispatchQueue.main.async {
            self.broadcastController = nil
            self.infoLabel?.isHidden = false
            if let picker = self.broadcastPickerView {
                picker.isHidden = false
                self.broadcastButton.isHidden = false
            } else {
                self.broadcastButton.isEnabled = true
            }
            self.broadcastButton.setTitle(ViewController.kStartBroadcastButtonTitle, for: .normal)
            self.spinner?.stopAnimating()

            if let theError = error {
                print("Broadcast did finish with error:", error as Any)
                self.infoLabel?.text = theError.localizedDescription
            } else {
                print("Broadcast did finish.")
            }
        }
    }

    func broadcastController(_ broadcastController: RPBroadcastController, didUpdateServiceInfo serviceInfo: [String : NSCoding & NSObjectProtocol]) {
        print("Broadcast did update service info: \(serviceInfo)")
    }

    func broadcastController(_ broadcastController: RPBroadcastController, didUpdateBroadcast broadcastURL: URL) {
        print("Broadcast did update URL: \(broadcastURL)")
    }
}

// MARK:- RPScreenRecorderDelegate
extension ViewController: RPScreenRecorderDelegate {
    func screenRecorderDidChangeAvailability(_ screenRecorder: RPScreenRecorder) {
        if Thread.isMainThread {
            // Assume we will get an error raised if we are actively broadcasting / capturing and access is "stolen".
            if (self.broadcastController == nil && screenTrack == nil) {
                checkRecordingAvailability()
            }
        } else {
            DispatchQueue.main.async {
                self.screenRecorderDidChangeAvailability(screenRecorder)
            }
        }
    }
}

