import 'package:flutter/material.dart';
import '../../routes/app_routes.dart';
import '../../core/constants/theme/app_theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PIATRA'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Text(
                'Welcome to PIATRA',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Your smart cooking assistant',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              _MenuCard(
                icon: Icons.kitchen,
                title: 'My Pantry',
                description: 'View and manage your ingredients',
                color: AppTheme.primaryGreen,
                onTap: () => Navigator.pushNamed(context, AppRoutes.pantry),
              ),
              const SizedBox(height: 16),
              _MenuCard(
                icon: Icons.camera_alt,
                title: 'Scan Ingredients',
                description: 'Add items using your camera',
                color: AppTheme.accentBlue,
                onTap: () => Navigator.pushNamed(context, AppRoutes.scan),
              ),
              const SizedBox(height: 16),
              _MenuCard(
                icon: Icons.restaurant_menu,
                title: 'Find Recipes',
                description: 'Browse recipes based on your pantry',
                color: AppTheme.secondaryOrange,
                onTap: () => Navigator.pushNamed(context, AppRoutes.recipes),
              ),
              const SizedBox(height: 16),
              _MenuCard(
                icon: Icons.chat,
                title: 'Cooking Assistant',
                description: 'Get AI-powered cooking help',
                color: Colors.purple,
                onTap: () => Navigator.pushNamed(context, AppRoutes.assistant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _MenuCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: AppTheme.textSecondary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}