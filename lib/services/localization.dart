import 'package:easy_localization/easy_localization.dart';

class AppLocalization {
  static String tr(String key, {Map<String, String>? args}) {
    if (args != null && args.isNotEmpty) {
      return key.tr(args: args);
    }
    return key.tr();
  }

  static String format(String key, List<dynamic> args) {
    return key.tr(args: args);
  }
}