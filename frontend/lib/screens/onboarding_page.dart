import 'package:flutter/material.dart';

class OnboardingPage extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget body;
  final String primaryText;
  final VoidCallback onPrimary;
  final String? secondaryText;
  final VoidCallback? onSecondary;

  const OnboardingPage({
    super.key,
    required this.title,
    this.subtitle,
    required this.body,
    required this.primaryText,
    required this.onPrimary,
    this.secondaryText,
    this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Text(
                title,
                style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle!,
                  style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: 16),
              Expanded(child: body),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: onPrimary,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56), shape: const StadiumBorder()),
                child: Text(primaryText),
              ),
              if (secondaryText != null) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: onSecondary,
                  child: Text(secondaryText!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}


