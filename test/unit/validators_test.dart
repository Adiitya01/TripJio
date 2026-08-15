import 'package:flutter_test/flutter_test.dart';
import 'package:tripjio/core/utils/validators.dart';

void main() {
  group('Phone validation', () {
    test('valid 10-digit Indian number passes', () {
      expect(Validators.phone('9876543210'), isNull);
    });

    test('with +91 prefix passes', () {
      expect(Validators.phone('+919876543210'), isNull);
    });

    test('with spaces passes', () {
      expect(Validators.phone('98765 43210'), isNull);
    });

    test('empty fails', () {
      expect(Validators.phone(''), isNotNull);
    });

    test('null fails', () {
      expect(Validators.phone(null), isNotNull);
    });

    test('too short fails', () {
      expect(Validators.phone('98765'), isNotNull);
    });

    test('too long fails', () {
      expect(Validators.phone('+91987654321099'), isNotNull);
    });

    test('only letters fails', () {
      expect(Validators.phone('abcdefghij'), isNotNull);
    });
  });

  group('OTP validation', () {
    test('valid 6-digit OTP passes', () {
      expect(Validators.otp('123456'), isNull);
    });

    test('5 digits fails', () {
      expect(Validators.otp('12345'), isNotNull);
    });

    test('7 digits fails', () {
      expect(Validators.otp('1234567'), isNotNull);
    });

    test('letters fail', () {
      expect(Validators.otp('12abcd'), isNotNull);
    });

    test('empty fails', () {
      expect(Validators.otp(''), isNotNull);
    });
  });

  group('Vehicle number validation', () {
    test('valid MH14AB1234 passes', () {
      expect(Validators.vehicleNumber('MH14AB1234'), isNull);
    });

    test('valid KA01M2345 passes', () {
      expect(Validators.vehicleNumber('KA01M2345'), isNull);
    });

    test('with spaces passes (stripped)', () {
      expect(Validators.vehicleNumber('MH 14 AB 1234'), isNull);
    });

    test('with dashes passes', () {
      expect(Validators.vehicleNumber('MH-14-AB-1234'), isNull);
    });

    test('lowercase passes (auto-uppercased)', () {
      expect(Validators.vehicleNumber('mh14ab1234'), isNull);
    });

    test('all-digit fails', () {
      expect(Validators.vehicleNumber('1234567890'), isNotNull);
    });

    test('too short fails', () {
      expect(Validators.vehicleNumber('MH14'), isNotNull);
    });

    test('empty fails', () {
      expect(Validators.vehicleNumber(''), isNotNull);
    });
  });

  group('Weight validation', () {
    test('null passes (weight is optional)', () {
      expect(Validators.weightKg(null), isNull);
    });

    test('empty passes (weight is optional)', () {
      expect(Validators.weightKg(''), isNull);
    });

    test('valid 500 passes', () {
      expect(Validators.weightKg('500'), isNull);
    });

    test('valid 50000 passes', () {
      expect(Validators.weightKg('50000'), isNull);
    });

    test('zero fails', () {
      expect(Validators.weightKg('0'), isNotNull);
    });

    test('negative fails', () {
      expect(Validators.weightKg('-100'), isNotNull);
    });

    test('above 50000 fails', () {
      expect(Validators.weightKg('50001'), isNotNull);
    });

    test('non-numeric fails', () {
      expect(Validators.weightKg('abc'), isNotNull);
    });
  });

  group('Address validation', () {
    test('valid address passes', () {
      expect(Validators.address('Andheri East, Mumbai'), isNull);
    });

    test('empty fails', () {
      expect(Validators.address(''), isNotNull);
    });

    test('null fails', () {
      expect(Validators.address(null), isNotNull);
    });

    test('1 character fails', () {
      expect(Validators.address('A'), isNotNull);
    });

    test('500 character passes', () {
      expect(Validators.address('A' * 500), isNull);
    });

    test('501 character fails', () {
      expect(Validators.address('A' * 501), isNotNull);
    });
  });

  group('Name validation', () {
    test('valid name passes', () {
      expect(Validators.name('Rajesh Kumar'), isNull);
    });

    test('single character fails', () {
      expect(Validators.name('R'), isNotNull);
    });

    test('100 chars passes', () {
      expect(Validators.name('A' * 100), isNull);
    });

    test('101 chars fails', () {
      expect(Validators.name('A' * 101), isNotNull);
    });

    test('empty fails', () {
      expect(Validators.name(''), isNotNull);
    });
  });

  group('Notes validation', () {
    test('null is allowed', () {
      expect(Validators.notes(null), isNull);
    });

    test('1000 chars passes', () {
      expect(Validators.notes('A' * 1000), isNull);
    });

    test('1001 chars fails', () {
      expect(Validators.notes('A' * 1001), isNotNull);
    });
  });
}
