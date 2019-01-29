package att.moe.flutterrecord

import android.content.pm.PackageManager
import android.Manifest
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.net.Uri
import android.os.Environment
import android.os.Handler
import android.support.v4.app.ActivityCompat
import android.support.v4.content.ContextCompat
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.Registrar
import org.json.JSONObject
import java.io.File
import android.media.MediaMetadataRetriever
import android.util.Log

class FlutterRecordPlugin : MethodCallHandler {
  private val channelName = "flutter_record"
  private var lastRecordPath: String = ""

  private var isRecording: Boolean = false
  private var isPause: Boolean = false
  private var pausePosition = 0

  private var mediaPlayer: MediaPlayer? = null
  private var mediaRecorder: MediaRecorder? = null

  private var runnable: Runnable? = null
  private val taskHandler = Handler()

  private val frequency = 125L

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
      "getPlatformVersion" -> result.success("Android ${android.os.Build.VERSION.RELEASE}")
      "getBasePath" -> result.success("${Environment.getExternalStorageDirectory().absolutePath}/")
      "startRecorder" -> {
        val path = call.argument<String>("path")!!
        val maxVolume = call.argument<String>("maxVolume")
        this.startRecorder(path, maxVolume, result)
      }
      "stopRecorder" -> this.stopRecorder(result)
      "cancelRecorder" -> this.stopRecorder(result, true)
      "startPlayer" -> {
        val path = call.argument<String>("path")!!
        this.startPlayer(path, result)
      }
      "stopPlayer" -> this.stopPlayer(result)
      "pausePlayer" -> this.pausePlayer(result)
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

  private fun startRecorder(path: String, maxVolume: String?, result: Result) {
    if (ContextCompat.checkSelfPermission(reg.context(), Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED
            || ContextCompat.checkSelfPermission(reg.context(), Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
      ActivityCompat.requestPermissions(reg.activity(), arrayOf(Manifest.permission.RECORD_AUDIO, Manifest.permission.WRITE_EXTERNAL_STORAGE), 0)
      recordComplete()
      return
    }

    if (isRecording) return

    if (mediaRecorder == null) {
      mediaRecorder = MediaRecorder()
    }

    lastRecordPath = "${Environment.getExternalStorageDirectory().absolutePath}/$path.aac"

    try {
      isRecording = true

      mediaRecorder?.apply {
        setAudioSource(MediaRecorder.AudioSource.MIC)
        setOutputFormat(MediaRecorder.OutputFormat.AAC_ADTS)
        setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
        setAudioSamplingRate(16000)
        setAudioChannels(1)
        setOutputFile(lastRecordPath)
        prepare()
        start()
      }

      if (maxVolume != null) {
        val json = JSONObject()
        runnable = Runnable {
          json.put("current_volume", maxVolume.toDouble() * mediaRecorder!!.maxAmplitude / 32768 + 1)
          MethodChannel(reg.messenger(), channelName).invokeMethod("updateVolume", json.toString())
          taskHandler.postDelayed(runnable, frequency)
        }
        taskHandler.postDelayed(runnable, frequency)
      }

      result.success(lastRecordPath)
    } catch (e: Exception) {
      result.error(channelName, "start record failed", e.printStackTrace())
    }
  }

  private fun stopRecorder(result: Result, isCancel: Boolean = false) {
    if (runnable != null) {
      taskHandler.removeCallbacks(runnable)
      runnable = null
    }

    try {
      isRecording = false

      mediaRecorder?.apply {
        stop()
        reset()
        release()
      }

      mediaRecorder = null
    } catch (e: Exception) {
      result.error(channelName, "stop record failed", e.printStackTrace())
    } finally {
      if (isCancel && lastRecordPath != "") {
        Log.e(channelName, "path = $lastRecordPath")
        val file = File(lastRecordPath)
        if (file.exists()) {
          file.delete()
        }
        result.success("cancel record success")
      } else {
        result.success("stop record success")
      }
      lastRecordPath = ""
    }
  }

  private fun playComplete() {
    mediaPlayer?.apply {
      stop()
      reset()
      release()
    }
    mediaPlayer = null
    MethodChannel(reg.messenger(), channelName).invokeMethod("playComplete", "play complete")
  }

  private fun recordComplete() {
    MethodChannel(reg.messenger(), channelName).invokeMethod("recordComplete", "record complete")
  }

  private fun startPlayer(path: String, result: Result) {
    if (mediaPlayer == null) {
      mediaPlayer = MediaPlayer()
    }

    if (isPause) {
      mediaPlayer?.apply {
        seekTo(pausePosition)
        start()
      }
      pausePosition = 0
      isPause = false
      return
    }

    if (mediaPlayer!!.isPlaying) {
      playComplete()
      return
    }

    val mPath = "${Environment.getExternalStorageDirectory().absolutePath}/$path.aac"

    try {
      mediaPlayer?.apply {
        setDataSource(mPath)
        setOnCompletionListener {
          playComplete()
          result.success("start play success")
        }
        prepare()
        start()
      }
    } catch (e: Exception) {
      result.error(channelName, "stop play failed", e.printStackTrace())
    }
  }

  private fun pausePlayer(result: Result) {
    try {
      mediaPlayer?.apply {
        pause()
        currentPosition
      }
      isPause = true
      pausePosition = mediaPlayer!!.currentPosition
    } catch (e: Exception) {
      result.error(channelName, "pause play failed", e.printStackTrace())
    }
  }

  private fun stopPlayer(result: Result) {
    try {
      if (mediaPlayer != null && mediaPlayer!!.isPlaying) {
        playComplete()
      }
      result.success("stop play success")
    } catch (e: Exception) {
      result.error(channelName, "stop play failed", e.printStackTrace())
    }
  }

  private fun getDuration(path: String, result: Result) {
    val mPath = "${Environment.getExternalStorageDirectory().absolutePath}/$path.aac"
    if (!File(mPath).isFile) return
    val uri = Uri.parse(mPath)
    val mmr = MediaMetadataRetriever()
    mmr.setDataSource(reg.context(), uri)
    val durationStr = mmr.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
    val millSecond = Integer.parseInt(durationStr)
    result.success(millSecond)
  }

  private fun setVolume(volume: Double, result: Result) {
    try {
      val v = volume.toFloat()
      mediaPlayer?.apply { setVolume(v, v) }
      result.success("set volume success")
    } catch (e: Exception) {
      result.error(channelName, "set volume failed", e.printStackTrace())
    }
  }
}
