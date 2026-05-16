import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/brand.dart';
import '../../data/feedback/feedback_remote.dart';

/// Opens the in-app feedback form from anywhere in the app.
void openFeedbackScreen(BuildContext context) {
  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(builder: (_) => const FeedbackScreen()),
  );
}

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

  /// Gmail-friendly filter: search for "TailorFlow" or "[TailorFlow]".
  String get mailSubject {
    switch (this) {
      case FeedbackCategory.bug:
        return '${Brand.feedbackSubjectPrefix} Bug';
      case FeedbackCategory.idea:
        return '${Brand.feedbackSubjectPrefix} Idea / need';
      case FeedbackCategory.other:
        return '${Brand.feedbackSubjectPrefix} Feedback';
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

  Future<bool> _openFeedbackEmail({
    required String subject,
    required String body,
  }) async {
    final uri = Uri(
      scheme: 'mailto',
      path: Brand.feedbackEmail,
      query:
          'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
    );
    return launchUrl(uri, mode: LaunchMode.externalApplication);
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
      if (!mounted) return;
      if (savedRemote) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Feedback sent successfully.')),
        );
        _message.clear();
        return;
      }

      final openedEmail =
          await _openFeedbackEmail(subject: subject, body: body);
      if (!mounted) return;
      if (openedEmail) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not reach the server. Your email app was opened instead.',
            ),
          ),
        );
        _message.clear();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not send feedback. Check your connection or email '
              '${Brand.feedbackEmail} directly.',
            ),
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
            'Report bugs, ideas, or anything that would help ${Brand.appName} work better for you.',
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
            'Feedback is sent to the ${Brand.appName} team when you are online. '
            'If that fails, your email app opens as a backup.',
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
