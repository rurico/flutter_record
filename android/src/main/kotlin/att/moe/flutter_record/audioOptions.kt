package att.moe.flutter_record

data class AudioOptions(private val map: Map<String, Any?>) {
  val refreshFrequency: Long by map
  val maxRecordableDuration: Int? by map
  val openRefresh: Boolean by map
  val audioType: Int by map
  val samplingRate: Int by map
  val channels: Int by map
}