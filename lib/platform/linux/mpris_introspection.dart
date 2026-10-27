import 'package:dbus/dbus.dart';

/// Introspection data for the MPRIS interfaces Fermata implements.
abstract final class MprisIntrospection {
  static const playerMethods = {
    'Next',
    'Previous',
    'Pause',
    'PlayPause',
    'Stop',
    'Play',
    'Seek',
    'SetPosition',
    'OpenUri',
  };

  static DBusIntrospectArgument _in(String sig, String name) =>
      DBusIntrospectArgument(DBusSignature(sig), DBusArgumentDirection.in_, name: name);

  static DBusIntrospectProperty _ro(String name, String sig, {bool emitsChanged = true}) => DBusIntrospectProperty(
        name,
        DBusSignature(sig),
        access: DBusPropertyAccess.read,
        annotations: [
          if (!emitsChanged) DBusIntrospectAnnotation('org.freedesktop.DBus.Property.EmitsChangedSignal', 'false'),
        ],
      );

  static DBusIntrospectProperty _rw(String name, String sig) =>
      DBusIntrospectProperty(name, DBusSignature(sig), access: DBusPropertyAccess.readwrite);

  static final interfaces = <DBusIntrospectInterface>[
    DBusIntrospectInterface(
      'org.mpris.MediaPlayer2',
      methods: [DBusIntrospectMethod('Raise'), DBusIntrospectMethod('Quit')],
      properties: [
        _ro('CanQuit', 'b'),
        _ro('CanRaise', 'b'),
        _ro('CanSetFullscreen', 'b'),
        _ro('Fullscreen', 'b'),
        _ro('HasTrackList', 'b'),
        _ro('Identity', 's'),
        _ro('DesktopEntry', 's'),
        _ro('SupportedUriSchemes', 'as'),
        _ro('SupportedMimeTypes', 'as'),
      ],
    ),
    DBusIntrospectInterface(
      'org.mpris.MediaPlayer2.Player',
      methods: [
        DBusIntrospectMethod('Next'),
        DBusIntrospectMethod('Previous'),
        DBusIntrospectMethod('Pause'),
        DBusIntrospectMethod('PlayPause'),
        DBusIntrospectMethod('Stop'),
        DBusIntrospectMethod('Play'),
        DBusIntrospectMethod('Seek', args: [_in('x', 'Offset')]),
        DBusIntrospectMethod('SetPosition', args: [_in('o', 'TrackId'), _in('x', 'Position')]),
        DBusIntrospectMethod('OpenUri', args: [_in('s', 'Uri')]),
      ],
      signals: [
        DBusIntrospectSignal('Seeked', args: [
          DBusIntrospectArgument(DBusSignature('x'), DBusArgumentDirection.out, name: 'Position'),
        ]),
      ],
      properties: [
        _ro('PlaybackStatus', 's'),
        _rw('LoopStatus', 's'),
        _rw('Rate', 'd'),
        _rw('Shuffle', 'b'),
        _ro('Metadata', 'a{sv}'),
        _rw('Volume', 'd'),
        _ro('Position', 'x', emitsChanged: false),
        _ro('MinimumRate', 'd'),
        _ro('MaximumRate', 'd'),
        _ro('CanGoNext', 'b'),
        _ro('CanGoPrevious', 'b'),
        _ro('CanPlay', 'b'),
        _ro('CanPause', 'b'),
        _ro('CanSeek', 'b'),
        _ro('CanControl', 'b', emitsChanged: false),
      ],
    ),
  ];
}
