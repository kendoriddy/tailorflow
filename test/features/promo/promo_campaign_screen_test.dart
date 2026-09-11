import 'package:flutter_test/flutter_test.dart';
import 'package:tailorflow_ng/features/promo/promo_campaign_screen.dart';

void main() {
  group('promoWhatsAppQuotaWouldBlock', () {
    test('does not block over-limit promo sends when paywall is disabled', () {
      expect(
        promoWhatsAppQuotaWouldBlock(
          paywallEnabled: false,
          subscribed: false,
          freeWhatsAppUnlimited: false,
          monthlyLimit: 10,
          usedThisMonth: 10,
          targetCount: 25,
        ),
        isFalse,
      );
    });

    test('blocks over-limit promo sends when paywall is enabled', () {
      expect(
        promoWhatsAppQuotaWouldBlock(
          paywallEnabled: true,
          subscribed: false,
          freeWhatsAppUnlimited: false,
          monthlyLimit: 10,
          usedThisMonth: 9,
          targetCount: 2,
        ),
        isTrue,
      );
    });

    test('allows subscribed and unlimited plans', () {
      expect(
        promoWhatsAppQuotaWouldBlock(
          paywallEnabled: true,
          subscribed: true,
          freeWhatsAppUnlimited: false,
          monthlyLimit: 10,
          usedThisMonth: 10,
          targetCount: 2,
        ),
        isFalse,
      );
      expect(
        promoWhatsAppQuotaWouldBlock(
          paywallEnabled: true,
          subscribed: false,
          freeWhatsAppUnlimited: true,
          monthlyLimit: -1,
          usedThisMonth: 100,
          targetCount: 100,
        ),
        isFalse,
      );
    });
  });
}
