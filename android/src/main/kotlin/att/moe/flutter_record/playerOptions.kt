package att.moe.flutter_record

data class PlayerOptions(private val map: Map<String, Any?>) {
  val refreshFrequency: Long by map
  val openRefresh: Boolean by map
}