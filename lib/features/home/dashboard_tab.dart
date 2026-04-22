import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/currency.dart';
import '../../data/data_layer.dart';
import '../../data/models/order_row.dart';
import '../customers/customer_detail_screen.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key, required this.layer, required this.onRefresh});

  final DataLayer layer;
  final VoidCallback onRefresh;

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  late Future<_DashData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant DashboardTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.layer != widget.layer) {
      _future = _load();
    }
  }

  Future<_DashData> _load() async {
    final due = await widget.layer.dashboard.dueToday();
    final owed = await widget.layer.dashboard.totalOwedThisMonth();
    return _DashData(due: due, owedThisMonth: owed);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _future = _load());
        widget.onRefresh();
        await _future;
      },
      child: FutureBuilder<_DashData>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                Center(child: CircularProgressIndicator()),
              ],
            );
          }
          final data = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              _StatCard(
                title: 'Total owed this month',
                subtitle:
                    'Sum of balances for orders due this month (not collected).',
                value: formatNgn(data.owedThisMonth),
                emphasize: data.owedThisMonth > 0,
              ),
              const SizedBox(height: 16),
              Text(
                "Today's due orders",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              if (data.due.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('Nothing due today. Nice and calm.'),
                )
              else
                ...data.due.map((o) => _DueTile(layer: widget.layer, order: o)),
            ],
          );
        },
      ),
    );
  }
}

class _DashData {
  _DashData({required this.due, required this.owedThisMonth});

  final List<OrderDueView> due;
  final int owedThisMonth;
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.emphasize,
  });

  final String title;
  final String subtitle;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: emphasize ? AppTheme.oweRed : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DueTile extends StatelessWidget {
  const _DueTile({required this.layer, required this.order});

  final DataLayer layer;
  final OrderDueView order;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(order.customerName),
        subtitle: Text('${order.title} • Due ${MaterialLocalizations.of(context).formatShortDate(order.dueDate)}'),
        trailing: order.balanceNgn > 0
            ? Text(
                'Owe ${formatNgn(order.balanceNgn)}',
                style: const TextStyle(
                  color: AppTheme.oweRed,
                  fontWeight: FontWeight.w800,
                ),
              )
            : const Text('Paid'),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CustomerDetailScreen(
                layer: layer,
                customerId: order.customerId,
              ),
            ),
          );
        },
      ),
    );
  }
}
