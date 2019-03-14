enum AudioType { AAC }

class AudioOptions {
  const AudioOptions({
    this.refreshFrequency = 100,
    this.openRefresh = false,
    this.maxRecordableDuration,
    this.audioType = AudioType.AAC,
    this.samplingRate = 16000,
    this.channels = 2,
  })  : assert(channels != null),
        assert(channels >= 1),
        assert(samplingRate != null),
        assert(samplingRate >= 1),
        assert(refreshFrequency != null),
        assert(refreshFrequency >= 50);

  /// refresh frequency microsecond
  final int refreshFrequency;
  final bool openRefresh;

  /// recordable max time
  final int maxRecordableDuration;

  final AudioType audioType;

  final int samplingRate;
  final int channels;

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = Map<String, dynamic>();
    data['refreshFrequency'] = this.refreshFrequency;
    data['openRefresh'] = this.openRefresh;
    data['maxRecordableDuration'] = this.maxRecordableDuration;
    data['audioType'] = this.audioType.index;
    data['samplingRate'] = this.samplingRate;
    data['channels'] = this.channels;
    return data;
  }
}
