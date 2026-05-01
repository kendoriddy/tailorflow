import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/currency.dart';
import 'order_status.dart';

class CustomerListItem {
  const CustomerListItem({
    required this.customerId,
    required this.name,
    required this.phone,
    required this.totalOwedNgn,
    required this.openOrdersCount,
    required this.lastOrderTitle,
    required this.lastOrderDueDate,
    required this.lastOrderStatus,
    required this.hasDueSoonOrder,
    required this.nextDueOrderDate,
  });

  final String customerId;
  final String name;
  final String? phone;
  final int totalOwedNgn;
  final int openOrdersCount;
  final String? lastOrderTitle;
  final DateTime? lastOrderDueDate;
  final OrderStatus? lastOrderStatus;
  final bool hasDueSoonOrder;
  final DateTime? nextDueOrderDate;

  Color statusColor(ColorScheme scheme) {
    if (totalOwedNgn > 0) return AppTheme.oweRed;
    if (openOrdersCount > 0) return Colors.amber.shade800;
    return AppTheme.accentGreen;
  }

  String subtitleText(MaterialLocalizations l10n) {
    final owe =
        totalOwedNgn > 0 ? 'Owes: ${formatNgn(totalOwedNgn)}' : 'Fully paid';
    if (lastOrderTitle == null || lastOrderDueDate == null) return owe;
    final status = lastOrderStatus == null
        ? 'Unknown'
        : _statusLabel(lastOrderStatus!);
    return '$owe\nLast order: $lastOrderTitle ($status • Due ${l10n.formatShortDate(lastOrderDueDate!)})';
  }

  String _statusLabel(OrderStatus status) {
    switch (status) {
      case OrderStatus.booked:
        return 'Booked';
      case OrderStatus.cutting:
        return 'Cutting';
      case OrderStatus.ready:
        return 'Ready';
      case OrderStatus.collected:
        return 'Collected';
    }
  }
}
