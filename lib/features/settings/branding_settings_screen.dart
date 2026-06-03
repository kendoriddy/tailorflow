import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/shop_branding.dart';
import '../../data/data_layer.dart';

class BrandingSettingsScreen extends StatefulWidget {
  const BrandingSettingsScreen({super.key, required this.layer});

  final DataLayer layer;

  @override
  State<BrandingSettingsScreen> createState() => _BrandingSettingsScreenState();
}

class _BrandingSettingsScreenState extends State<BrandingSettingsScreen> {
  final _displayName = TextEditingController();
  final _shopName = TextEditingController();
  Color _primary = const Color(0xFF1B5E20);
  bool _loading = true;
  bool _saving = false;

  static const _presetColors = <Color>[
    Color(0xFF1B5E20),
    Color(0xFF1565C0),
    Color(0xFF6A1B9A),
    Color(0xFFE65100),
    Color(0xFF37474F),
    Color(0xFFB71C1C),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final branding = await ShopBranding.load(widget.layer.settings);
    _displayName.text = branding.displayName;
    _shopName.text = branding.shopNameForMessages;
    setState(() {
      _primary = branding.primaryColor;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _displayName.dispose();
    _shopName.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ShopBranding.saveDisplayName(
        widget.layer.settings,
        _displayName.text,
      );
      await ShopBranding.saveShopName(widget.layer.settings, _shopName.text);
      await ShopBranding.savePrimaryColor(widget.layer.settings, _primary);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickLogo() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Custom logo upload is available on mobile builds.'),
        ),
      );
      return;
    }
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (file == null) return;
    await ShopBranding.saveLogoFromPath(file.path);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Logo saved. Restart may be needed on some devices.')),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Shop branding')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Customize how your shop appears in the app and in WhatsApp messages.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _displayName,
            decoration: const InputDecoration(
              labelText: 'App name (on this device)',
              hintText: 'e.g. Ada\'s Fashion',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _shopName,
            decoration: const InputDecoration(
              labelText: 'Shop name in messages',
              hintText: 'e.g. Ada\'s Fashion Hub',
            ),
          ),
          const SizedBox(height: 20),
          Text('Accent color', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _presetColors.map((c) {
              final selected = c.toARGB32() == _primary.toARGB32();
              return GestureDetector(
                onTap: () => setState(() => _primary = c),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: c,
                  child: selected
                      ? const Icon(Icons.check, color: Colors.white)
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          if (!kIsWeb) ...[
            OutlinedButton.icon(
              onPressed: _pickLogo,
              icon: const Icon(Icons.image_outlined),
              label: const Text('Choose shop logo'),
            ),
            TextButton(
              onPressed: () async {
                await ShopBranding.clearLogo();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Logo removed.')),
                );
              },
              child: const Text('Remove logo'),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save branding'),
          ),
        ],
      ),
    );
  }
}
