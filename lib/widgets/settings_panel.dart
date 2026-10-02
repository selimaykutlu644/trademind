import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPanel extends StatefulWidget {
  const SettingsPanel({super.key});

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  String? selectedLanguage;

  @override
  void initState() {
    super.initState();
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLang = prefs.getString('trademind.language');
    if (mounted) {
      setState(() {
        selectedLanguage = savedLang ?? context.locale.languageCode;
      });
    }
  }

  Future<void> _changeLanguage(String langCode) async {
    await context.setLocale(Locale(langCode));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('trademind.language', langCode);
    if (mounted) {
      setState(() {
        selectedLanguage = langCode;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xff0c1327),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xff202b43)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'nav_settings'.tr(),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          _buildLanguageSelector(),
          const SizedBox(height: 20),
          Text(
            'settings_language'.tr(),
            style: const TextStyle(
              color: Color(0xff97a7c3),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSelector() {
    return Row(
      children: [
        _buildLanguageButton('tr', 'Türkçe'),
        const SizedBox(width: 12),
        _buildLanguageButton('en', 'English'),
      ],
    );
  }

  Widget _buildLanguageButton(String code, String label) {
    final isSelected = selectedLanguage == code;
    return OutlinedButton(
      onPressed: () => _changeLanguage(code),
      style: OutlinedButton.styleFrom(
        backgroundColor: isSelected 
            ? const Color(0xff56dcf2).withOpacity(0.1) 
            : Colors.transparent,
        side: BorderSide(
          color: isSelected ? const Color(0xff56dcf2) : const Color(0xff202b43),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? const Color(0xff56dcf2) : const Color(0xff97a7c3),
        ),
      ),
    );
  }
}