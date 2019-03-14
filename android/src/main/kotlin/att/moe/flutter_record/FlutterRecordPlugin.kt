package att.moe.flutter_record

import android.Manifest
import android.annotation.TargetApi
import android.content.pm.PackageManager
import android.media.MediaMetadataRetriever
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.Registrar
import java.io.File
import java.lang.Exception

class FlutterRecordPlugin : MethodCallHandler {
  private val channelName = "flutter_record"
  private var lastRecordPath: String = ""

  private var isRecording: Boolean = false
  private var isPause: Boolean = false
  private var pausePosition: Int = 0

  private var mediaPlayer: MediaPlayer? = null
  private var mediaRecorder: MediaRecorder? = null

  private val taskHandler = Handler()
  private var recordTimerList: ArrayList<Runnable> = ArrayList()
  private var playerTimerList: ArrayList<Runnable> = ArrayList()

  private val dBSplMax = "dB_Spl_Max"
  private val recordTimeStream = "record_time_stream"
  private val playTimeStream = "play_time_stream"

  companion object {
    private lateinit var reg: Registrar
    @JvmStatic
    fun registerWith(registrar: Registrar) {
      val channel = MethodChannel(registrar.messenger(), "flutter_record")
      channel.setMethodCallHandler(FlutterRecordPlugin())
      reg = registrar
    }
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "requestPermission" -> this.requestPermission(result)
      "startRecorder" -> {
        val args = call.arguments<Map<String, Map<String, Any>>>()
        val filename = call.argument<String>("filename")!! // TODO Union Type
        val audioOptions = AudioOptions(args.getValue("audioOptions"))
        val volumeOptions = VolumeOptions(args.getValue("volumeOptions"))
        this.startRecorder(filename, audioOptions, volumeOptions, result)
      }
      "stopRecorder" -> this.stopRecorder(result)
      "cancelRecorder" -> this.stopRecorder(result, true)
      "startPlayer" -> {
        val path = call.argument<String>("path")!!
        val args = call.arguments<Map<String, Map<String, Any>>>()
        val playerOptions = PlayerOptions(args.getValue("playerOptions"))
        this.startPlayer(path, playerOptions, result)
      }
      "stopPlayer" -> this.stopPlayer(result)
      "pausePlayer" -> this.pausePlayer(result)
      "resumePlayer" -> this.resumePlayer(result)
      "getDuration" -> {
        val path = call.argument<String>("path")!!
        this.getDuration(path, result)
      }
      "setVolume" -> {
        val volume = call.argument<Double>("volume")!!
        this.setVolume(volume, result)
      }
      else -> result.notImplemented()
    }
  }

  private fun getAudioType(int: Int) = when (int) {
    0 -> "acc"
    1 -> "mp3"
    else -> "acc"
  }

  private fun checkPathExist(path: String, isDir: Boolean = false): Boolean {
    val f = File(path)
    return if (isDir) f.exists() && f.isDirectory else f.exists()
  }

  @TargetApi(Build.VERSION_CODES.JELLY_BEAN)
  private fun recStart(audioOptions: AudioOptions,
                       result: Result) {
    if (mediaRecorder == null) {
      mediaRecorder = MediaRecorder()
    }

    try {
      mediaRecorder?.apply {
        setAudioSource(MediaRecorder.AudioSource.MIC)
        setOutputFormat(MediaRecorder.OutputFormat.AAC_ADTS)
        setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
        setAudioSamplingRate(audioOptions.samplingRate)
        setAudioChannels(audioOptions.channels)
        setOutputFile(lastRecordPath)
        prepare()
        start()
      }

      isRecording = true
    } catch (e: Exception) {
      result.error(channelName, FlutterRecordError.error_start_recorder, e.printStackTrace())
    }
  }

  private fun recStop(result: Result, deleteFile: Boolean = false) {
    try {
      mediaRecorder?.apply {
        stop()
        reset()
        release()
      }
      isRecording = false
      mediaRecorder = null
    } catch (e: Exception) {
      result.error(channelName, FlutterRecordError.error_stop_recorder, e.printStackTrace())
    } finally {
      if (deleteFile && lastRecordPath != "") {
        if (checkPathExist(lastRecordPath)) {
          File(lastRecordPath).delete()
        }
      }
      lastRecordPath = ""
    }
  }

  private fun playVoice(path: String, result: Result) {
    try {
      mediaPlayer?.apply {
        setDataSource(path)
        setOnCompletionListener { stopVoice(result) }
        prepare()
        start()
      }
    } catch (e: Exception) {
      result.error(channelName, FlutterRecordError.error_start_player, e.printStackTrace())
    }
  }

  private fun stopVoice(result: Result) {
    try {
      mediaPlayer?.apply {
        stop()
        reset()
        release()
      }
      clearRunnable(playerTimerList)
      notifyPlayComplete()
      mediaPlayer = null
    } catch (e: IllegalStateException) {
      result.error(channelName, FlutterRecordError.error_stop_player, e.printStackTrace())
    }
  }

  private fun notifyPlayComplete() {
    invokeMethod("notify_play_complete")
  }

  private fun autoRunnable(curTime: Int, delayMillis: Long, maxRecordableDuration: Int?, runnable: Runnable, result: Result) {
    if (maxRecordableDuration != null) {
      if (curTime - maxRecordableDuration > 1) {
        taskHandler.postDelayed(runnable, delayMillis)
      } else {
        recStop(result)
      }
    } else {
      taskHandler.postDelayed(runnable, delayMillis)
    }
  }

  private fun clearRunnable(arr: ArrayList<Runnable>) {
    arr.forEach {
      taskHandler.removeCallbacks(it)
      arr.remove(it)
    }
  }

  private fun invokeMethod(fnName: String, data: String = "") {
    MethodChannel(reg.messenger(), channelName).invokeMethod(fnName, data)
  }

  private fun requestPermission(result: Result) {
    if (ContextCompat.checkSelfPermission(reg.context(), Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED
            || ContextCompat.checkSelfPermission(reg.context(), Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
      ActivityCompat.requestPermissions(reg.activity(), arrayOf(Manifest.permission.RECORD_AUDIO, Manifest.permission.WRITE_EXTERNAL_STORAGE), 0)
      result.success(ContextCompat.checkSelfPermission(reg.context(), Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
              && ContextCompat.checkSelfPermission(reg.context(), Manifest.permission.WRITE_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED)
    } else {
      result.success(ContextCompat.checkSelfPermission(reg.context(), Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
              && ContextCompat.checkSelfPermission(reg.context(), Manifest.permission.WRITE_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED)
    }
  }

  private fun startRecorder(filename: String,
                            audioOptions: AudioOptions,
                            volumeOptions: VolumeOptions,
                            result: Result) {

    if (ContextCompat.checkSelfPermission(reg.context(), Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED
            || ContextCompat.checkSelfPermission(reg.context(), Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
      ActivityCompat.requestPermissions(reg.activity(), arrayOf(Manifest.permission.RECORD_AUDIO, Manifest.permission.WRITE_EXTERNAL_STORAGE), 0)
      notifyPlayComplete()
      return
    }

    val audioType = getAudioType(audioOptions.audioType)
    lastRecordPath = "${Environment.getExternalStorageDirectory().absolutePath}/$filename.$audioType"

    if (!checkPathExist(lastRecordPath.substring(0..lastRecordPath.lastIndexOf('/')), true)) {
      lastRecordPath = ""
      result.error(channelName, FlutterRecordError.error_filename, FlutterRecordError.error_filename)
    }

    if (isRecording) {
      result.error(channelName, FlutterRecordError.error_recorder, FlutterRecordError.error_recorder)
    }

    recStart(audioOptions, result)

    val startTime = System.currentTimeMillis().toInt()
    var runnable = Runnable { }

    if (audioOptions.openRefresh) {
      runnable = Runnable {
        autoRunnable(startTime, audioOptions.refreshFrequency, audioOptions.maxRecordableDuration, runnable, result)
        invokeMethod(recordTimeStream, (System.currentTimeMillis() - startTime).toString())
      }

      taskHandler.postDelayed(runnable, audioOptions.refreshFrequency)
      recordTimerList.add(runnable)
    }

    if (volumeOptions.dBSplMax != null) {
      val max = volumeOptions.dBSplMax!!
      runnable = Runnable {
        autoRunnable(startTime, audioOptions.refreshFrequency, audioOptions.maxRecordableDuration, runnable, result)
        invokeMethod(dBSplMax, (Math.log(mediaRecorder!!.maxAmplitude.toDouble()) / Math.log(32768.0) * max).toString())
      }

      taskHandler.postDelayed(runnable, volumeOptions.refreshFrequency)
      recordTimerList.add(runnable)
    }

    result.success(lastRecordPath)
  }

  private fun stopRecorder(result: Result, deleteFile: Boolean = false) {
    clearRunnable(recordTimerList)
    recStop(result, deleteFile)
    result.success(Unit)
  }

  private fun startPlayer(path: String, playerOptions: PlayerOptions, result: Result) {
    if (!path.startsWith("http")) {
      if (!checkPathExist(path)) {
        result.error(channelName, FlutterRecordError.error_filename, FlutterRecordError.error_filename)
      }
    }
    if (mediaPlayer == null) {
      mediaPlayer = MediaPlayer()
    }
    if (mediaPlayer!!.isPlaying) {
      notifyPlayComplete()
      result.error(channelName, FlutterRecordError.error_player_already, FlutterRecordError.error_player_already)
    }
    playVoice(path, result)
    if (playerOptions.openRefresh) {
      val curTime = System.currentTimeMillis().toInt()
      val runnable = Runnable {
        invokeMethod(playTimeStream, (System.currentTimeMillis() - curTime).toString())
      }

      taskHandler.postDelayed(runnable, playerOptions.refreshFrequency)
      playerTimerList.add(runnable)
    }
    result.success(Unit)
  }

  private fun stopPlayer(result: Result) {
    stopVoice(result)
    result.success(Unit)
  }

  private fun pausePlayer(result: Result) {
    try {
      pausePosition = mediaPlayer?.apply {
        pause()
      }!!.currentPosition
      isPause = true
      result.success(Unit)
    } catch (e: IllegalStateException) {
      result.error(channelName, FlutterRecordError.error_pause_player, FlutterRecordError.error_pause_player)
    }
  }

  private fun resumePlayer(result: Result) {
    try {
      mediaPlayer?.apply {
        seekTo(pausePosition)
        start()
      }
      pausePosition = 0
      result.success(Unit)
    } catch (e: IllegalStateException) {
      result.error(channelName, FlutterRecordError.error_resume_player, FlutterRecordError.error_resume_player)
    }
  }

  @TargetApi(Build.VERSION_CODES.GINGERBREAD_MR1)
  private fun getDuration(path: String, result: Result) {
    if (!checkPathExist(path)) {
      result.error(channelName, FlutterRecordError.error_filename, FlutterRecordError.error_filename)
    }
    val uri = Uri.parse(path)
    val mmr = MediaMetadataRetriever()
    mmr.setDataSource(reg.context(), uri)
    val durationStr = mmr.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
    val millSecond = Integer.parseInt(durationStr)
    result.success(millSecond)
  }

  private fun setVolume(volume: Double, result: Result) {
    val v = volume.toFloat()
    mediaPlayer?.apply { setVolume(v, v) }
    result.success(Unit)
  }
}
