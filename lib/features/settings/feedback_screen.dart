import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/feedback_config.dart';
import '../../data/feedback/feedback_remote.dart';

enum FeedbackCategory {
  bug,
  idea,
  other;

  String get label {
    switch (this) {
      case FeedbackCategory.bug:
        return 'Bug';
      case FeedbackCategory.idea:
        return 'Idea / need';
      case FeedbackCategory.other:
        return 'Other';
    }
  }

  /// Gmail-friendly filter: search for "TailorFlow NG" or "[TailorFlow NG]".
  String get mailSubject {
    switch (this) {
      case FeedbackCategory.bug:
        return '[TailorFlow NG] Bug';
      case FeedbackCategory.idea:
        return '[TailorFlow NG] Idea / need';
      case FeedbackCategory.other:
        return '[TailorFlow NG] Feedback';
    }
  }
}

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _message = TextEditingController();
  FeedbackCategory _category = FeedbackCategory.idea;
  PackageInfo? _packageInfo;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _loadPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _packageInfo = info);
    } catch (_) {
      // Web or unsupported — leave null; footer still shows platform.
    }
  }

  String _platformLabel() {
    if (kIsWeb) return 'Web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'Android';
      case TargetPlatform.iOS:
        return 'iOS';
      case TargetPlatform.linux:
        return 'Linux';
      case TargetPlatform.macOS:
        return 'macOS';
      case TargetPlatform.windows:
        return 'Windows';
      case TargetPlatform.fuchsia:
        return 'Fuchsia';
    }
  }

  String _platformLine() => 'Platform: ${_platformLabel()}';

  String _buildBody() {
    final buf = StringBuffer();
    buf.writeln(_message.text.trim());
    buf.writeln();
    buf.writeln('---');
    buf.writeln('Category: ${_category.label}');
    buf.writeln(_platformLine());
    if (_packageInfo != null) {
      buf.writeln(
        'App: ${_packageInfo!.appName} ${_packageInfo!.version} (${_packageInfo!.buildNumber})',
      );
    }
    if (kDebugMode) buf.writeln('Build: debug');
    return buf.toString();
  }

  Future<void> _submit() async {
    final text = _message.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe your feedback.')),
      );
      return;
    }

    setState(() => _sending = true);
    final body = _buildBody();
    final subject = _category.mailSubject;

    try {
      final savedRemote = await FeedbackRemote.trySubmit(
        category: _category.name,
        subject: subject,
        message: text,
        bodyContext: body,
        appVersion: _packageInfo?.version,
        platform: _platformLabel(),
      );

      if (kFeedbackMailtoAddress.isEmpty) {
        await Clipboard.setData(ClipboardData(text: '$subject\n\n$body'));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              savedRemote
                  ? 'Saved for the team. Feedback address is not set — message copied to clipboard.'
                  : 'Feedback address is not set. Message copied — paste into email or WhatsApp.',
            ),
          ),
        );
        return;
      }

      final uri = Uri(
        scheme: 'mailto',
        path: kFeedbackMailtoAddress,
        queryParameters: <String, String>{
          'subject': subject,
          'body': body,
        },
      );

      final launched = await launchUrl(uri);
      if (!mounted) return;
      if (!launched) {
        await Clipboard.setData(ClipboardData(text: '$subject\n\n$body'));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              savedRemote
                  ? 'Saved for the team. Could not open mail — feedback copied to clipboard.'
                  : 'Could not open mail. Feedback copied to clipboard instead.',
            ),
          ),
        );
      } else if (savedRemote) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Saved for the team. Finish sending in your email app.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Send feedback')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Report bugs, ideas, or anything that would help TailorFlow work better for you.',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 20),
          Text('Type', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: FeedbackCategory.values.map((c) {
              final selected = _category == c;
              return ChoiceChip(
                label: Text(c.label),
                selected: selected,
                onSelected: (_) => setState(() => _category = c),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _message,
            decoration: const InputDecoration(
              labelText: 'Details',
              hintText: 'What happened? What would you like to see?',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
            maxLines: 8,
            minLines: 5,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 12),
          Text(
            kFeedbackMailtoAddress.isEmpty
                ? 'Add a feedback email in the app config, or use Send to copy the message to the clipboard.'
                : 'Opens your email app with To: $kFeedbackMailtoAddress. '
                    'If backup & sync is enabled, a copy is also saved for the TailorFlow team. '
                    'Subjects start with [TailorFlow NG].',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: _sending ? null : _submit,
              child: _sending
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Send feedback'),
            ),
          ),
        ],
      ),
    );
  }
}
