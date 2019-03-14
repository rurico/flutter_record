class PlayerOptions {
  const PlayerOptions({
    this.openRefresh = false,
    this.refreshFrequency = 150,
  })  : assert(refreshFrequency != null),
        assert(refreshFrequency >= 50);

  /// refresh frequency microsecond
  final int refreshFrequency;
  final bool openRefresh;

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = Map<String, dynamic>();
    data['refreshFrequency'] = this.refreshFrequency;
    data['openRefresh'] = this.openRefresh;
    return data;
  }
}
