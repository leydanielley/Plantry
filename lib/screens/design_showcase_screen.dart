import 'package:flutter/material.dart';
import 'package:growlog_app/utils/app_messages.dart';
import 'package:growlog_app/widgets/widgets.dart';
import 'package:growlog_app/utils/app_theme.dart';

/// 🎨 Design Showcase Screen
///
/// Demonstriert alle neuen Design-Komponenten
class DesignShowcaseScreen extends StatelessWidget {
  const DesignShowcaseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Design Showcase')),
      body: MultiColorGradientBackground(
        gradients: [
          [Colors.green[100] ?? Colors.green, Colors.blue[100] ?? Colors.blue],
          [
            Colors.blue[100] ?? Colors.blue,
            Colors.purple[100] ?? Colors.purple,
          ],
          [
            Colors.purple[100] ?? Colors.purple,
            Colors.pink[100] ?? Colors.pink,
          ],
          [Colors.pink[100] ?? Colors.pink, Colors.green[100] ?? Colors.green],
        ],
        duration: const Duration(seconds: 5),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 🎨 Glassmorphism Cards
              _buildSection(
                context,
                title: '🎨 Glassmorphism Cards',
                child: Column(
                  children: [
                    GlassCard(
                      borderRadius: 16,
                      blur: 10,
                      opacity: 0.1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Standard Glass Card',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'This is a beautiful glassmorphism card with blur effect and semi-transparent background.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    GlassGradientCard(
                      gradientColors: [AppTheme.primaryGreen, Colors.teal],
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Glass Gradient Card',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(color: Colors.white),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Glass card with custom gradient colors.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 🎯 Bouncy Buttons
              _buildSection(
                context,
                title: '🎯 Bouncy Buttons',
                child: Column(
                  children: [
                    BouncyButton(
                      onPressed: () {
                        AppMessages.showSuccess(
                          context,
                          'Primary Button Pressed!',
                        );
                      },
                      child: const Text('Primary Button'),
                    ),
                    const SizedBox(height: 12),
                    BouncyButton(
                      onPressed: () {},
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.primaryGreen,
                      border: BorderSide(
                        color: AppTheme.primaryGreen,
                        width: 2,
                      ),
                      child: const Text('Outlined Button'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        BouncyIconButton(
                          icon: Icons.favorite,
                          onPressed: () {},
                          color: Colors.red,
                          backgroundColor: Colors.red.withValues(alpha: 0.1),
                        ),
                        BouncyIconButton(
                          icon: Icons.share,
                          onPressed: () {},
                          color: Colors.blue,
                          backgroundColor: Colors.blue.withValues(alpha: 0.1),
                        ),
                        BouncyIconButton(
                          icon: Icons.bookmark,
                          onPressed: () {},
                          color: Colors.orange,
                          backgroundColor: Colors.orange.withValues(alpha: 0.1),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 🚀 Hero Animations
              _buildSection(
                context,
                title: '🚀 Hero Animations',
                child: Column(
                  children: [
                    HeroCard(
                      tag: 'demo-card',
                      borderRadius: BorderRadius.circular(16),
                      child: GlassCard(
                        child: ListTile(
                          leading: const Icon(Icons.flutter_dash, size: 40),
                          title: const Text('Hero Card'),
                          subtitle: const Text('Tap to see hero animation'),
                          trailing: const Icon(Icons.arrow_forward_ios),
                          onTap: () {
                            Navigator.push(
                              context,
                              ScaleHeroPageRoute(
                                builder: (context) => const _HeroDetailScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 🎨 Typography Showcase
              _buildSection(
                context,
                title: '🎨 Poppins Typography',
                child: GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Display Large',
                        style: Theme.of(context).textTheme.displayLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Headline Medium',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Title Large',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Body Large - This is the standard body text with Poppins font.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Body Medium - Secondary text with medium weight.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Label Small - Small labels and captions.',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // 🎨 Color Palette
              _buildSection(
                context,
                title: '🎨 Color Palette',
                child: GlassCard(
                  child: Column(
                    children: [
                      _buildColorChip(
                        context,
                        'Primary Green',
                        AppTheme.primaryGreen,
                      ),
                      _buildColorChip(
                        context,
                        'Success',
                        AppTheme.successColor,
                      ),
                      _buildColorChip(
                        context,
                        'Warning',
                        AppTheme.warningColor,
                      ),
                      _buildColorChip(context, 'Error', AppTheme.errorColor),
                      _buildColorChip(context, 'Info', AppTheme.infoColor),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
        ),
        child,
      ],
    );
  }

  Widget _buildColorChip(BuildContext context, String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.getBorderColor(context),
                width: 1,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(label, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}

/// Detail Screen for Hero Animation Demo
class _HeroDetailScreen extends StatelessWidget {
  const _HeroDetailScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hero Detail')),
      body: Center(
        child: HeroCard(
          tag: 'demo-card',
          borderRadius: BorderRadius.circular(16),
          child: GlassCard(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.flutter_dash, size: 80),
                const SizedBox(height: 16),
                Text(
                  'Hero Animation!',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'This card animated smoothly from the previous screen.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
