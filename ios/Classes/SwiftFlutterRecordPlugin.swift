import Flutter
import UIKit
import AVFoundation

public class SwiftFlutterRecordPlugin: NSObject, FlutterPlugin, AVAudioPlayerDelegate {
  private let channelName = "flutter_record"
  private var lastRecordPath: URL?

  private var isPause: Bool = false
  private var pausePosition = 0
  
  private var player: AVAudioPlayer?
  private var recorder: AVAudioRecorder?
  
  private var timer: Timer?
  private let channel: FlutterMethodChannel
  
  private var volume: Double?
  
  init(channel: FlutterMethodChannel) {
    self.channel = channel
  }
  
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "flutter_record", binaryMessenger: registrar.messenger())
    let instance = SwiftFlutterRecordPlugin(channel: channel)
    registrar.addMethodCallDelegate(instance, channel: channel)
  }
  
  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? Dictionary<String, Any>
    switch call.method {
    case "getPlatformVersion":
      result("iOS \(UIDevice.current.systemVersion)")
    case "getBasePath":
      result("\(NSTemporaryDirectory())")
    case "startRecorder":
      let path = args!["path"] as! String
      let maxVolume = args!["maxVolume"] as? String
      self.startRecorder(path, maxVolume, result)
    case "stopRecorder":
      self.stopRecorder(false, result)
    case "cancelRecorder":
      self.stopRecorder(true, result)
    case "startPlayer":
      let path = args!["path"] as! String
      self.startPlayer(path, result)
    case "pausePlayer":
      self.pausePlayer(result)
    case "stopPlayer":
      self.stopPlayer(result)
    case "getDuration":
      let path = args!["path"] as! String
      self.getDuration(path, result)
    case "setVolume":
      let volume = args!["volume"] as? String
      if volume != nil {
        self.setVolume(Double(volume!)!, result)
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }
  
  private func _playComplete() {
    channel.invokeMethod("playComplete", arguments: "play complete")
  }
  
  @objc func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
    _playComplete()
  }
  
  @objc private func updateVolume() {
    recorder!.updateMeters()
    let db = recorder!.averagePower(forChannel: 0)
    let volume = Double(self.volume! * (Double(db) + 77.0) / 77.0)
    channel.invokeMethod("updateVolume", arguments: "{\"current_volume\": \(volume)}")
  }
  
  private func startRecorder(_ path: String, _ maxVolume: String?, _ result: FlutterResult) {
    let recordSetting: [String: Any] = [
      AVSampleRateKey: NSNumber(value: 16000),
      AVFormatIDKey: (value: kAudioFormatMPEG4AAC),
      AVNumberOfChannelsKey: NSNumber(value: 1),
      AVEncoderAudioQualityKey: NSNumber(value: AVAudioQuality.min.rawValue)
    ]
    
    lastRecordPath = URL(fileURLWithPath: "\(NSTemporaryDirectory())\(path).aac")
    
    let session = AVAudioSession.sharedInstance()
    
    do {
      try? session.setCategory(AVAudioSessionCategoryPlayAndRecord)
      try session.setActive(true)
      
      if let recordPath = lastRecordPath {
        recorder = try AVAudioRecorder(url: recordPath, settings: recordSetting)
      }
      recorder?.isMeteringEnabled = true
      recorder?.prepareToRecord()
      recorder?.record()
      
    } catch {
      result(FlutterError.init(code: channelName, message: "start record failed", details: error))
    }
    
    result(lastRecordPath?.absoluteString)
    
    if maxVolume != nil {
      self.volume = Double(maxVolume!)!
      timer = Timer.scheduledTimer(timeInterval: 0.125, target: self, selector: #selector(self.updateVolume), userInfo: nil, repeats: true)
      print(timer!)
    }
  }
  
  private func stopRecorder(_ isCancel: Bool, _ result: FlutterResult)  {
    if let recorder = self.recorder {
      if recorder.isRecording {
        recorder.stop()
        self.recorder = nil
        
        if isCancel {
          let fileManager = FileManager.default
          do {
            let __path__  = lastRecordPath!.absoluteString.replacingOccurrences(of: "file://", with: "")
            if fileManager.fileExists(atPath: __path__) {
              try fileManager.removeItem(atPath: __path__)
            }
            result("cancel record success")
          } catch let error as NSError {
            result(FlutterError.init(code: channelName, message: "cancel record failed", details: error))
          }
        } else {
          result("stop record success")
        }
      }
    }
    if timer != nil {
      timer!.invalidate()
      timer = nil
    }
    volume = nil
  }

  private func startPlayer(_ path: String, _ result: FlutterResult) {
    if isPause && player != nil {
      player!.play(atTime: self.pausePosition)
      pausePosition = 0
      isPause = false
    }
    let fileManager = FileManager.default
    let url = URL(fileURLWithPath: "\(NSTemporaryDirectory())\(path).aac")
    if fileManager.fileExists(atPath: url.absoluteString.replacingOccurrences(of: "file://", with: "")) {
      do {
        player = try AVAudioPlayer(contentsOf: url)

        player!.delegate = self
        
        player!.play()
        result("start play success")
      } catch {
        result(FlutterError.init(code: channelName, message: "start player failed", details: error))
      }
    } else {
      _playComplete()
    }
  }

  private func pausePlayer(_ result: FlutterResult) {
    if player != nil {
      if player!.isPlaying {
        player!.pause()
        isPause = true
        self.pausePosition = player!.currentTime
        result("pause play success")
      }
    }
  }
  
  private func stopPlayer(_ result: FlutterResult) {
    if player != nil {
      if player!.isPlaying {
        player!.stop()
        result("stop play success")
      }
    }
  }
  
  private func getDuration(_ path: String, _ result: FlutterResult)  {
    let asset = AVURLAsset(url: URL(fileURLWithPath: "\(NSTemporaryDirectory())\(path).aac"))
    let audioDuration = asset.duration
    let audioDurationSeconds = CMTimeGetSeconds(audioDuration)
    result(Int(audioDurationSeconds * 1000.0))
  }
  
  private func setVolume(_ volume: Double, _ result: FlutterResult)  {
    if player != nil {
      player!.volume = Float(volume)
      result("set volume success")
    } else {
      result(FlutterError.init(code: channelName, message: "set volume failed", details: nil))
    }
  }
}
