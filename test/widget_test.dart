import 'package:flutter_test/flutter_test.dart';
import 'package:shamsi_date/shamsi_date.dart';

void main() {
  test('Jalali calendar has 31 days in Farvardin', () {
    expect(Jalali(1403, 1, 1).monthLength, 31);
  });
}
