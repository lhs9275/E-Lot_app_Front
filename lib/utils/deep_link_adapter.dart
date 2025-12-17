import 'deep_link_stub.dart'
    if (dart.library.io) 'deep_link_io.dart' as impl;

Future<String?> getInitialLinkSafe() => impl.getInitialLinkSafe();

Stream<String?> get linkStreamSafe => impl.linkStreamSafe;
