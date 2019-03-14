package att.moe.flutter_record

data class VolumeOptions(private val map: Map<String, Any?>) {
  val refreshFrequency: Long by map
  val dBSplMax: Int? by map
}