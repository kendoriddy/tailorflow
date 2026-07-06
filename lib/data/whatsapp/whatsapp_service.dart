import 'package:flutter/material.dart';

import '../billing/remote_flags.dart';
import '../billing/subscription_service.dart';
import '../billing/whatsapp_quota_service.dart';
import '../../features/whatsapp/whatsapp_launcher.dart';

enum WhatsAppSendResult {
  sent,
  noPhone,
  launchFailed,
  quotaExceeded,
}

/// Central gate for WhatsApp: enforces monthly quota on the free tier.
class WhatsAppService {
  WhatsAppService({
    required SubscriptionService subscriptions,
    required WhatsAppQuotaService quota,
  })  : _subscriptions = subscriptions,
        _quota = quota;

  final SubscriptionService _subscriptions;
  final WhatsAppQuotaService _quota;

  Future<WhatsAppSendResult> sendText({
    required String? rawPhone,
    required String message,
    bool countTowardQuota = true,
  }) async {
    final subscribed = await _subscriptions.isActive();
    if (!subscribed &&
        countTowardQuota &&
        RemoteFlags.paywallEnabled) {
      final allowed = await _quota.canSend(subscribed: false);
      if (!allowed) return WhatsAppSendResult.quotaExceeded;
    }

    final ok = await openWhatsAppText(rawPhone: rawPhone, message: message);
    if (!ok) {
      final digits = rawPhone?.replaceAll(RegExp(r'\D'), '') ?? '';
      if (digits.isEmpty) return WhatsAppSendResult.noPhone;
      return WhatsAppSendResult.launchFailed;
    }

    if (countTowardQuota && !subscribed) {
      await _quota.recordSend();
    }
    return WhatsAppSendResult.sent;
  }

  static String quotaMessage(int limit, int used) {
    if (RemoteFlags.paywallEnabled) {
      return 'Free plan WhatsApp limit reached ($used of $limit this month). '
          'Upgrade to send more messages.';
    }
    return 'WhatsApp limit reached for this month ($used of $limit). '
        'Try again next month.';
  }

  static void showResultSnackBar(
    BuildContext context,
    WhatsAppSendResult result, {
    int? limit,
    int? used,
  }) {
    final String text;
    switch (result) {
      case WhatsAppSendResult.sent:
        text = 'WhatsApp opened with your message.';
      case WhatsAppSendResult.noPhone:
        text = 'Add a valid phone number to send on WhatsApp.';
      case WhatsAppSendResult.launchFailed:
        text = 'Could not open WhatsApp.';
      case WhatsAppSendResult.quotaExceeded:
        text = limit != null && used != null
            ? quotaMessage(limit, used)
            : 'WhatsApp limit reached for this month on the free plan.';
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}
