import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/theme/app_theme.dart';
import '../../models/user_profile_model.dart';
import '../../state/user_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late CookingMode _selectedMode;
  late List<String> _selectedDietaryPrefs;
  late List<String> _selectedAllergies;
  bool _saved = false;

  static const _allDietaryOptions = [
    'Vegetarian', 'Vegan', 'Gluten-Free', 'Dairy-Free',
    'Keto', 'Paleo', 'High-Protein', 'Low-Carb',
    'Budget-Friendly', 'Quick (<30 min)', 'Meal Prep',
  ];

  static const _allAllergyOptions = [
    'Nuts', 'Peanuts', 'Gluten', 'Dairy', 'Eggs',
    'Soy', 'Shellfish', 'Fish', 'Wheat', 'Sesame',
  ];

  @override
  void initState() {
    super.initState();
    final profile = context.read<UserProvider>().profile;
    _selectedMode = profile?.cookingMode ?? CookingMode.general;
    _selectedDietaryPrefs = List.from(profile?.dietaryPreferences ?? []);
    _selectedAllergies = List.from(profile?.allergies ?? []);
  }

  void _selectMode(CookingMode mode) {
    setState(() {
      _selectedMode = mode;
      // Auto-apply the mode's default dietary preferences
      // but preserve any existing user choices
      final defaults = mode.defaultDietaryPreferences
          .map((e) => _toDisplayLabel(e))
          .toList();
      for (final d in defaults) {
        if (!_selectedDietaryPrefs.contains(d)) {
          _selectedDietaryPrefs.add(d);
        }
      }
    });
  }

  String _toDisplayLabel(String raw) {
    // Convert backend tags like 'high-protein' to display 'High-Protein'
    return raw.split('-').map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1)).join('-');
  }

  void _saveProfile() {
    final provider = context.read<UserProvider>();
    final current = provider.profile ?? UserProfileModel.defaultProfile();
    provider.setProfile(current.copyWith(
      cookingMode: _selectedMode,
      dietaryPreferences: _selectedDietaryPrefs,
      allergies: _selectedAllergies,
      calorieTarget: _selectedMode.defaultCalorieTarget,
    ));
    setState(() => _saved = true);
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // Background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [AppTheme.backgroundDark, AppTheme.surfaceDark]
                    : [AppTheme.backgroundLight, Colors.white],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildAppBar(isDark),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('Choose Your Cooking Mode', isDark),
                        const SizedBox(height: 12),
                        _buildModeGrid(isDark),
                        const SizedBox(height: 28),
                        _buildSelectedModeDetails(isDark),
                        const SizedBox(height: 28),
                        _buildSectionTitle('Dietary Preferences', isDark),
                        const SizedBox(height: 4),
                        Text(
                          'Select all that apply',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildChipSelector(
                          options: _allDietaryOptions,
                          selected: _selectedDietaryPrefs,
                          color: AppTheme.primaryPurple,
                          onToggle: (val) => setState(() {
                            _selectedDietaryPrefs.contains(val)
                                ? _selectedDietaryPrefs.remove(val)
                                : _selectedDietaryPrefs.add(val);
                          }),
                        ),
                        const SizedBox(height: 28),
                        _buildSectionTitle('Allergies & Restrictions', isDark),
                        const SizedBox(height: 4),
                        Text(
                          'We\'ll flag recipes containing these',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildChipSelector(
                          options: _allAllergyOptions,
                          selected: _selectedAllergies,
                          color: AppTheme.errorRed,
                          onToggle: (val) => setState(() {
                            _selectedAllergies.contains(val)
                                ? _selectedAllergies.remove(val)
                                : _selectedAllergies.add(val);
                          }),
                        ),
                        const SizedBox(height: 28),
                        _buildCalorieCard(isDark),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Save button pinned at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildSaveBar(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded),
            style: IconButton.styleFrom(
              backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('My Profile', style: Theme.of(context).textTheme.headlineMedium),
                Text(
                  'Personalize your cooking experience',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }

  Widget _buildModeGrid(bool isDark) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.15,
      children: CookingMode.values.map((mode) => _ModeCard(
        mode: mode,
        isSelected: _selectedMode == mode,
        onTap: () => _selectMode(mode),
      )).toList(),
    );
  }

  Widget _buildSelectedModeDetails(bool isDark) {
    final mode = _selectedMode;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: Container(
        key: ValueKey(mode),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: mode.gradientColors.map((c) => Color(c)).toList(),
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Color(mode.gradientColors.first).withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(mode.icon, size: 32, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mode.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        mode.tagline,
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              mode.description,
              style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: mode.suggestedTags.map((tag) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(tag, style: const TextStyle(color: Colors.white, fontSize: 12)),
              )).toList(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.local_fire_department, color: Colors.white70, size: 16),
                const SizedBox(width: 4),
                Text(
                  'Daily target: ${mode.defaultCalorieTarget} kcal',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChipSelector({
    required List<String> options,
    required List<String> selected,
    required Color color,
    required void Function(String) onToggle,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final isSelected = selected.contains(opt);
        return GestureDetector(
          onTap: () => onToggle(opt),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? color.withOpacity(0.15) : (isDark ? AppTheme.cardDark : Colors.white),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? color : (isDark ? Colors.white24 : Colors.black12),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected) ...[
                  Icon(Icons.check_rounded, size: 14, color: color),
                  const SizedBox(width: 4),
                ],
                Text(
                  opt,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected
                        ? color
                        : (isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCalorieCard(bool isDark) {
    final target = _selectedMode.defaultCalorieTarget;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black.withOpacity(0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryTeal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.local_fire_department_rounded,
                    color: AppTheme.secondaryTeal, size: 24),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Daily Calorie Target',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          )),
                  Text('Based on your ${_selectedMode.label} profile',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                      )),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$target kcal/day',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppTheme.secondaryTeal,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryTeal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _selectedMode.label,
                  style: const TextStyle(
                    color: AppTheme.secondaryTeal,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: target / 3500,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.secondaryTeal),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _saved
              ? Container(
                  key: const ValueKey('saved'),
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppTheme.successGreen,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_rounded, color: Colors.white),
                      SizedBox(width: 8),
                      Text('Profile Saved!',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
              : GestureDetector(
                  key: const ValueKey('save'),
                  onTap: _saveProfile,
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryPurple.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.save_rounded, color: Colors.white),
                        SizedBox(width: 8),
                        Text('Save Profile',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

// ── Mode selection card ───────────────────────────────────────────────────────

class _ModeCard extends StatelessWidget {
  final CookingMode mode;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeCard({
    required this.mode,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = mode.gradientColors.map((c) => Color(c)).toList();

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight)
              : null,
          color: isSelected ? null : (isDark ? AppTheme.cardDark : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.transparent : (isDark ? Colors.white12 : Colors.black.withOpacity(0.08)),
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: colors.first.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 6))]
              : [],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(mode.icon, size: 28, color: Colors.white),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
                  ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mode.label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  mode.tagline,
                  style: TextStyle(
                    fontSize: 11,
                    color: isSelected
                        ? Colors.white70
                        : (isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}