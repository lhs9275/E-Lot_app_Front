import 'package:uni_links/uni_links.dart';

Future<String?> getInitialLinkSafe() => getInitialLink();

Stream<String?> get linkStreamSafe => linkStream;
