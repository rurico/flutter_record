import AVFoundation
import Flutter
import UIKit

public class SwiftFlutterRecordPlugin: NSObject, FlutterPlugin, AVAudioPlayerDelegate {
  private let channelName = "flutter_record"
  private var lastRecordPath: URL?

  private var isPause: Bool = false
  private var isRecording: Bool = false
  private var pausePosition: TimeInterval = 0

  private var player: AVAudioPlayer?
  private var recorder: AVAudioRecorder?

  private var recordTimerList: NSArray = []
  private var playerTimerList: NSArray = []
  private let channel: FlutterMethodChannel

  private let dBSplMaxStr = "dB_Spl_Max"
  private let recordTimeStream = "record_time_stream"
  private let playerTimeStream = "play_time_stream"

  init(channel: FlutterMethodChannel) {
    self.channel = channel
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "flutter_record", binaryMessenger: registrar.messenger())
    let instance = SwiftFlutterRecordPlugin(channel: channel)
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? NSDictionary
    switch call.method {
    case "requestPermission":
      result(true)
    case "startRecorder":
      let filename = args?["filename"] as! NSString
      let audioOptions = args?["audioOptions"] as! NSDictionary
      let volumeOptions = args?["volumeOptions"] as! NSDictionary
      startRecorder(filename, audioOptions, volumeOptions, result)
    case "stopRecorder":
      let delete = args?["delete"] as? Bool != nil
      stopRecorder(delete, result)
    case "startPlayer":
      let path = args?["path"] as! String
      let playerOptions = args?["playerOptions"] as! NSDictionary
      startPlayer(path, playerOptions, result)
    case "stopPlayer":
      stopPlayer(result)
    case "pausePlayer":
      pausePlayer(result)
    case "resumePlayer":
      resumePlayer(result)
    case "getDuration":
      let path = args?["path"] as! String
      getDuration(path, result)
    case "setVolume":
      let volume = args?["volume"] as! Double
      setVolume(volume, result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func _playComplete() {
    clearPlayerTimer()
    channel.invokeMethod("notify_play_complete", arguments: "")
  }

  private func audioPlayerDidFinishPlaying(_: AVAudioPlayer, successfully _: Bool) {
    _playComplete()
  }

  private func getAudioType(int: NSNumber) -> NSString {
    switch int {
    case 0:
      return "aac"
    case 1:
      return "mp3"
    default:
      return "aac"
    }
  }

  private func autoTimer(startTime: Double, maxDuration: Double) {
    if startTime - NSDate().timeIntervalSince1970 * 1000 + maxDuration > 0 {
      if recordTimerList.count > 1 {
        clearRecordTimer()
        recStop()
      }
    }
  }

  private func clearRecordTimer() {
    recordTimerList.forEach { it in
      (it as! Timer).invalidate()
    }
    recordTimerList = []
  }

  private func clearPlayerTimer() {
    playerTimerList.forEach { it in
      (it as! Timer).invalidate()
    }
    playerTimerList = []
  }

  @objc private func updateDbSpl(info: NSDictionary) {
    autoTimer(startTime: info["startTime"]! as! Double, maxDuration: info["maxDuration"]! as! Double)
    recorder!.updateMeters()
    let dbfs = recorder!.peakPower(forChannel: 0)
    let db = pow(10, 0.05 * dbfs) * Float(truncating: info["dBSplMax"]! as! NSNumber)
    channel.invokeMethod(dBSplMaxStr, arguments: "\(db)")
  }

  @objc private func updateRecordTimeStream(info: NSDictionary) {
    autoTimer(startTime: info["startTime"]! as! Double, maxDuration: info["maxDuration"]! as! Double)
    channel.invokeMethod(
      recordTimeStream,
      arguments: "\(Double(truncating: info["startTime"]! as! NSNumber) - NSDate().timeIntervalSince1970 * 1000)"
    )
  }

  @objc private func updatePlayTimeStream(info: NSDictionary) {
    channel.invokeMethod(
      playerTimeStream,
      arguments: "\(Double(truncating: info["startTime"]! as! NSNumber) - NSDate().timeIntervalSince1970 * 1000)"
    )
  }

  private func startRecorder(_ filename: NSString,
                             _ audioOptions: NSDictionary,
                             _ volumeOptions: NSDictionary,
                             _ result: FlutterResult) {
    let audioType = getAudioType(int: audioOptions["audioType"] as! NSNumber)
    lastRecordPath = URL(fileURLWithPath: "\(NSTemporaryDirectory())\(filename).\(audioType)")

    if isRecording {
      result(FlutterError(code: channelName,
                          message: FlutterRecordError.error_recorder,
                          details: FlutterRecordError.error_recorder))
    }

    let recordSetting: [String: Any] = [
      AVSampleRateKey: audioOptions["samplingRate"] as! NSNumber,
      AVFormatIDKey: (value: kAudioFormatMPEG4AAC),
      AVNumberOfChannelsKey: audioOptions["channels"] as! NSNumber,
      AVEncoderAudioQualityKey: NSNumber(value: AVAudioQuality.min.rawValue),
    ]

    let session = AVAudioSession.sharedInstance()

    do {
      if #available(iOS 10.0, *) {
        try? session.setCategory(.playAndRecord, mode: .default)
      } else {
        session.perform(NSSelectorFromString("setCategory:error:"),
                        with: AVAudioSession.Category.playback)
      }

      try session.setActive(true)

      if let recordPath = lastRecordPath {
        recorder = try AVAudioRecorder(url: recordPath, settings: recordSetting)
      }

      recorder?.isMeteringEnabled = true
      recorder?.prepareToRecord()
      recorder?.record()

      isRecording = true

    } catch {
      result(FlutterError(code: channelName,
                          message: FlutterRecordError.error_start_recorder,
                          details: error))
    }

    let startTime = NSDate().timeIntervalSince1970 * 1000

    let info: NSMutableDictionary = [startTime: startTime]

    if audioOptions["maxRecordableDuration"]! as? NSNumber != nil {
      info["maxDuration"] = audioOptions["maxRecordableDuration"]! as! NSNumber
    }

    if audioOptions["openRefresh"]! as! Bool {
      let timer = Timer.scheduledTimer(
        timeInterval: Double(truncating: audioOptions["refreshFrequency"]! as! NSNumber) * 0.001,
        target: self,
        selector: #selector(updateRecordTimeStream),
        userInfo: info,
        repeats: true
      )
      recordTimerList.adding(timer)
    }

    if volumeOptions["dBSplMax"] != nil {
      info["dbSpl"] = volumeOptions["dBSplMax"]! as! Double
      let timer = Timer.scheduledTimer(
        timeInterval: Double(truncating: volumeOptions["refreshFrequency"]! as! NSNumber) * 0.001,
        target: self,
        selector: #selector(updateDbSpl),
        userInfo: info,
        repeats: true
      )
      recordTimerList.adding(timer)
    }

    result(lastRecordPath?.absoluteString)
  }

  private func recStop() {
    if let recorder = self.recorder {
      if recorder.isRecording {
        recorder.stop()
        self.recorder = nil
      }
    }
  }

  private func stopRecorder(_ deleteOrigin: Bool, _ result: FlutterResult) {
    clearRecordTimer()
    recStop()

    if deleteOrigin {
      let fileManager = FileManager.default
      do {
        let path = lastRecordPath!.absoluteString.replacingOccurrences(of: "file://", with: "")
        if fileManager.fileExists(atPath: path) {
          try fileManager.removeItem(atPath: path)
        }
        result(nil)
      } catch let error as NSError {
        result(FlutterError(code: channelName, message: "cancel record failed", details: error))
      }
    } else {
      result(nil)
    }
  }

  private func startPlayer(_ path: String, _ playerOptions: NSDictionary, _ result: FlutterResult) {
    let fileManager = FileManager.default
    let url = URL(fileURLWithPath: path)
    if fileManager.fileExists(atPath: url.absoluteString.replacingOccurrences(of: "file://", with: "")) {
      do {
        player = try AVAudioPlayer(contentsOf: url)

        player!.delegate = self

        player!.play()

        let startTime = NSDate().timeIntervalSince1970 * 1000
        let info: NSMutableDictionary = [startTime: startTime]

        if playerOptions["maxRecordableDuration"]! as? NSNumber != nil {
          info["maxDuration"] = playerOptions["maxRecordableDuration"]! as! NSNumber
        }

        if playerOptions["openRefresh"]! as! Bool {
          let timer = Timer.scheduledTimer(
            timeInterval: Double(truncating: playerOptions["refreshFrequency"]! as! NSNumber) * 0.001,
            target: self,
            selector: #selector(updatePlayTimeStream),
            userInfo: info,
            repeats: true
          )
          playerTimerList.adding(timer)
        }

        result(nil)

      } catch {
        result(FlutterError(code: channelName, message: FlutterRecordError.error_start_player, details: error))
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
        pausePosition = player!.currentTime
        result(nil)
      }
    }
  }

  private func resumePlayer(_ result: FlutterResult) {
    if isPause {
      if player != nil {
        let shortStartDelay = 0.01
        player!.prepareToPlay()
        player!.play(atTime: pausePosition + shortStartDelay)
        isPause = false
        pausePosition = 0
        result(nil)
      }
    }
  }

  private func stopPlayer(_ result: FlutterResult) {
    if player != nil {
      if player!.isPlaying {
        player!.stop()
        clearPlayerTimer()
        result(nil)
      }
    }
  }

  private func getDuration(_ path: String, _ result: FlutterResult) {
    let asset = AVURLAsset(url: URL(fileURLWithPath: path))
    let audioDuration = asset.duration
    let audioDurationSeconds = CMTimeGetSeconds(audioDuration)
    result(Int(audioDurationSeconds * 1000.0))
  }

  private func setVolume(_ volume: Double, _ result: FlutterResult) {
    if player != nil {
      player!.volume = Float(volume)
      result(nil)
    }
  }
}
