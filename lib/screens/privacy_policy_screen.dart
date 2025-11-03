// =============================================
// GROWLOG - Privacy Policy Screen
// =============================================

import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  final String language;

  const PrivacyPolicyScreen({super.key, this.language = 'en'});

  bool get isGerman => language == 'de';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              isGerman ? 'Datenschutzerklärung für Plantry' : 'Privacy Policy for Plantry',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.green[700],
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              isGerman ? 'Gültig ab: 3. November 2025' : 'Effective Date: November 3, 2025',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[600],
                  ),
            ),
            Text(
              isGerman ? 'Zuletzt aktualisiert: 3. November 2025' : 'Last Updated: November 3, 2025',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 24),

            // Quick Summary Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                border: Border(
                  left: BorderSide(
                    color: Colors.green[400]!,
                    width: 4,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isGerman ? 'Kurzzusammenfassung:' : 'Quick Summary:',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isGerman
                        ? 'Plantry ist eine 100% Offline-App. Alle deine Pflanzendaten bleiben auf deinem Gerät. '
                            'Wir sammeln, übertragen oder teilen keine deiner Informationen.'
                        : 'Plantry is a 100% offline app. All your plant data stays on your device. '
                            'We don\'t collect, upload, or share any of your information.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // 1. Introduction
            _buildSection(
              context,
              '1. Introduction',
              'Welcome to Plantry ("we," "our," or "us"). This Privacy Policy explains how we handle '
                  'information when you use our mobile application ("App"). Your privacy is important to us, '
                  'and we are committed to protecting it.',
            ),

            // 2. Information We Collect
            _buildSection(
              context,
              '2. Information We Collect',
              'Plantry is designed to work completely offline. The App stores the following data locally on your device:',
            ),
            _buildBulletPoint('Plant Information: Names, strains, growing phases, and other plant-related data you enter'),
            _buildBulletPoint('Grow Logs: Notes, measurements (pH, EC, temperature, humidity), watering schedules, and feeding data'),
            _buildBulletPoint('Photos: Images you take or select from your device to document plant growth'),
            _buildBulletPoint('Room & Equipment Data: Information about your grow rooms and hardware'),
            _buildBulletPoint('App Settings: Your preferences such as language and theme (dark/light mode)'),
            const SizedBox(height: 24),

            // 3. How We Store Your Data
            _buildSection(
              context,
              '3. How We Store Your Data',
              'All data is stored locally on your device. We do NOT:',
            ),
            _buildBulletPoint('❌ Upload your data to any server or cloud service'),
            _buildBulletPoint('❌ Transmit your data over the internet'),
            _buildBulletPoint('❌ Create user accounts or profiles'),
            _buildBulletPoint('❌ Track your activity or usage'),
            _buildBulletPoint('❌ Collect analytics or telemetry'),
            _buildBulletPoint('❌ Use cookies or tracking technologies'),
            const SizedBox(height: 24),

            // 4. Data Sharing
            _buildSection(
              context,
              '4. Data Sharing',
              'We do not share your data with anyone. Since all data is stored locally on your device '
                  'and we have no servers, there is no way for us to access or share your information.\n\n'
                  'The only way your data leaves your device is if you choose to:',
            ),
            _buildBulletPoint('Export a backup file using the app\'s export feature'),
            _buildBulletPoint('Share a backup file via email, cloud storage, or messaging apps'),
            const SizedBox(height: 24),

            // 5. Permissions We Request
            _buildSection(
              context,
              '5. Permissions We Request',
              'Plantry requires certain permissions to function. Here\'s why we need them:',
            ),
            const SizedBox(height: 16),
            _buildSubsection(context, '📷 Camera Permission'),
            _buildBulletPoint('Purpose: To take photos of your plants'),
            _buildBulletPoint('Usage: Only when you tap the camera button to document plant growth'),
            _buildBulletPoint('Optional: You can use the app without granting camera access'),
            const SizedBox(height: 12),
            _buildSubsection(context, '📁 Storage Permission'),
            _buildBulletPoint('Purpose: To save photos and create backup files'),
            _buildBulletPoint('Usage: To read photos from your gallery and save backup ZIP files'),
            _buildBulletPoint('Data: Only photos you explicitly select or backups you create'),
            const SizedBox(height: 12),
            _buildSubsection(context, '🌐 Internet Permission'),
            _buildBulletPoint('Purpose: Required by Android for file sharing features'),
            _buildBulletPoint('Usage: Only when you choose to share backup files via email/messaging apps'),
            _buildBulletPoint('Note: The app works 100% offline; internet is never required for core functionality'),
            const SizedBox(height: 24),

            // 6. Your Control Over Your Data
            _buildSection(
              context,
              '6. Your Control Over Your Data',
              'You have complete control over your data:',
            ),
            _buildBulletPoint('Export Data: Use the "Export Data" feature in Settings to create a complete backup'),
            _buildBulletPoint('Import Data: Restore your data from a previous backup'),
            _buildBulletPoint('Delete Data: Clear all data by resetting the database in Settings (Debug section)'),
            _buildBulletPoint('Uninstall: Deleting the app removes all data from your device'),
            const SizedBox(height: 24),

            // 7. Third-Party Services
            _buildSection(
              context,
              '7. Third-Party Services',
              'Plantry does not integrate with any third-party services, advertising networks, '
                  'analytics providers, or social media platforms.',
            ),

            // 8. Children's Privacy
            _buildSection(
              context,
              '8. Children\'s Privacy',
              'Plantry is not directed at children under the age of 13 (or applicable age in your jurisdiction). '
                  'We do not knowingly collect information from children. If you are under the required age, '
                  'please do not use this app.',
            ),

            // 9. Data Security
            _buildSection(
              context,
              '9. Data Security',
              'Since all data is stored locally on your device, the security of your data depends on:',
            ),
            _buildBulletPoint('Your device\'s security measures (lock screen, encryption)'),
            _buildBulletPoint('Your backup file security (if you export data, store it securely)'),
            const SizedBox(height: 12),
            const Text('We recommend:'),
            const SizedBox(height: 8),
            _buildBulletPoint('Using a device lock screen (PIN, pattern, fingerprint, etc.)'),
            _buildBulletPoint('Storing backup files in a secure location'),
            _buildBulletPoint('Not sharing your backup files with untrusted parties'),
            const SizedBox(height: 24),

            // 10. Changes to This Privacy Policy
            _buildSection(
              context,
              '10. Changes to This Privacy Policy',
              'We may update this Privacy Policy from time to time. Any changes will be posted in the app '
                  'and on this page. The "Last Updated" date at the top will indicate when changes were made.',
            ),

            // 11. Legal Compliance
            _buildSection(
              context,
              '11. Legal Compliance',
              'This app is designed for legal plant growing activities. Users are responsible for ensuring '
                  'their use of the app complies with all applicable local, state, and federal laws.',
            ),

            // 12. Contact Us
            _buildSection(
              context,
              '12. Contact Us',
              'If you have any questions about this Privacy Policy or the app, please contact us at:',
            ),
            _buildBulletPoint('Email: ley.daniel.ley@gmail.com'),
            const SizedBox(height: 32),

            // Footer
            Divider(color: Colors.grey[300]),
            const SizedBox(height: 16),
            Center(
              child: Text(
                '© 2025 Plantry. All rights reserved.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.green[600],
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        Text(
          content,
          style: const TextStyle(height: 1.6),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSubsection(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 16)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
