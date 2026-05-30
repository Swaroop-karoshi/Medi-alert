import 'package:flutter_test/flutter_test.dart';
import 'package:medi_alert/core/constants/app_constants.dart';

void main() {
  test('app name is Medialert', () {
    expect(AppConstants.appName, 'Medialert');
  });
}
