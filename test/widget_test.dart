import 'package:flutter_test/flutter_test.dart';
import 'package:ciber_radar/services/oui_service.dart';

void main() {
  test('OUI Service - isRandomMac detects random MACs', () {
    expect(OuiService.isRandomMac('02:00:00:00:00:00'), true);
    expect(OuiService.isRandomMac('06:00:00:00:00:00'), true);
    expect(OuiService.isRandomMac('0A:00:00:00:00:00'), true);
    expect(OuiService.isRandomMac('0E:00:00:00:00:00'), true);

    expect(OuiService.isRandomMac('00:00:00:00:00:00'), false);
    expect(OuiService.isRandomMac('3C:15:C2:E4:05:01'), false);
  });
}
