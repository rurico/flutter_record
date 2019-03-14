class VolumeOptions {
  const VolumeOptions({
    this.refreshFrequency = 150,
    this.dBSplMax,
  })  : assert(refreshFrequency != null),
        assert(refreshFrequency >= 50);

  /// refresh frequency microsecond
  final int refreshFrequency;
  final int dBSplMax;

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = Map<String, dynamic>();
    data['refreshFrequency'] = this.refreshFrequency;
    data['dbsplMax'] = this.dBSplMax;
    return data;
  }
}
