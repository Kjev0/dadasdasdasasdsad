/// Well-known source identifiers. Plugins may register additional ids;
/// ids must be lowercase ASCII without ':'.
abstract final class SourceIds {
  static const local = 'local';
  static const soundcloud = 'soundcloud';
  static const audius = 'audius';
  static const deezer = 'deezer';
  static const spotify = 'spotify';
  static const youtube = 'youtube';
  static const jamendo = 'jamendo';

  /// Default provider preference order (SoundCloud first, per product spec).
  static const defaultPreference = [soundcloud, audius, local, jamendo, deezer, youtube, spotify];
}
