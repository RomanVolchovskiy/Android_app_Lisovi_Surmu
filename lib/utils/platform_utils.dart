import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

bool get isIOS => !kIsWeb && Platform.isIOS;
bool get isAndroid => !kIsWeb && Platform.isAndroid;
bool get isWeb => kIsWeb;
