// lib/ui/screens/profile_screen.dart
//
// Unified Profile & Preferences screen.
// Sections:
//   1. Identity        – display name + avatar initial
//   2. Cooking Mode    – mode cards
//   3. Calorie Target  – slider + live macro breakdown
//   4. Diet            – chip grid (hard exclusions)
//   5. Cuisines        – chip grid (ranking priority)
//   6. Allergies       – chip grid (hard exclusions)
//
// All changes auto-save to Firestore via UserProvider on back-navigation
// (WillPopScope) or by tapping the Save button that appears when dirty.
// On save, RecipeProvider re-fetches with the updated profile.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/theme/app_theme.dart';
import '../../models/user_profile_model.dart';
import '../../state/user_provider.dart';
import '../../state/recipe_provider.dart';

// ─── Option data ──────────────────────────────────────────────────────────────

class _Opt {
  final String id;
  final String label;
  final String emoji;
  final String? sub;
  const _Opt(this.id, this.label, this.emoji, [this.sub]);
}

const _diets = [
  _Opt('vegetarian',  'Vegetarian',  '🥬', 'No meat or fish'),
  _Opt('vegan',       'Vegan',       '🌱', 'No animal products'),
  _Opt('gluten free', 'Gluten-Free', '🌾', 'No gluten'),
  _Opt('dairy free',  'Dairy-Free',  '🥛', 'No dairy'),
  _Opt('ketogenic',   'Keto',        '🥑', 'Very low carb'),
  _Opt('paleo',       'Paleo',       '🍖', 'No grains/legumes'),
  _Opt('pescetarian', 'Pescetarian', '🐟', 'Fish, no other meat'),
  _Opt('whole30',     'Whole30',     '🥦', 'Clean whole foods'),
  _Opt('low fodmap',  'Low FODMAP',  '🫐', 'Gut-friendly'),
];

const _cuisines = [
  _Opt('Italian',        'Italian',        '🍝'),
  _Opt('Japanese',       'Japanese',       '🍣'),
  _Opt('Mexican',        'Mexican',        '🌮'),
  _Opt('Indian',         'Indian',         '🍛'),
  _Opt('Chinese',        'Chinese',        '🥢'),
  _Opt('Thai',           'Thai',           '🍜'),
  _Opt('Mediterranean',  'Mediterranean',  '🫒'),
  _Opt('American',       'American',       '🍔'),
  _Opt('French',         'French',         '🥐'),
  _Opt('Greek',          'Greek',          '🫙'),
  _Opt('Spanish',        'Spanish',        '🥘'),
  _Opt('Middle Eastern', 'Middle Eastern', '🧆'),
  _Opt('Korean',         'Korean',         '🍱'),
  _Opt('Vietnamese',     'Vietnamese',     '🍲'),
];

const _allergies = [
  _Opt('dairy',     'Dairy',      '🥛'),
  _Opt('egg',       'Eggs',       '🥚'),
  _Opt('gluten',    'Gluten',     '🌾'),
  _Opt('peanut',    'Peanuts',    '🥜'),
  _Opt('tree nut',  'Tree Nuts',  '🌰'),
  _Opt('soy',       'Soy',        '🫘'),
  _Opt('seafood',   'Seafood',    '🦐'),
  _Opt('shellfish', 'Shellfish',  '🦞'),
  _Opt('sesame',    'Sesame',     '🌿'),
  _Opt('wheat',     'Wheat',      '🍞'),
];

// ─── Screen ───────────────────────────────────────────────────────────────────

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // ── Draft state ────────────────────────────────────────────────────────────
  late TextEditingController _nameCtrl;
  late CookingMode _mode;
  late int _calories;
  late List<String> _selectedDiets;
  late List<String> _selectedCuisines;
  late List<String> _selectedAllergies;

  bool _dirty = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = context.read<UserProvider>().profile ?? UserProfileModel.defaultProfile();
    _nameCtrl  = TextEditingController(text: p.displayName);
    _mode      = p.cookingMode;
    _calories  = p.calorieTarget;
    _selectedDiets     = List.from(p.dietaryPreferences);
    _selectedCuisines  = List.from(p.favoriteCuisines);
    _selectedAllergies = List.from(p.allergies);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  // ── Persistence ────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_dirty) return;
    final name = _nameCtrl.text.trim();
    setState(() => _saving = true);

    final up = context.read<UserProvider>();
    if (name.isNotEmpty) await up.updateDisplayName(name);
    await up.updateCookingMode(_mode);
    await up.updateCalorieTarget(_calories);
    await up.updateDietaryPreferences(_selectedDiets);
    await up.updateFavoriteCuisines(_selectedCuisines);
    await up.updateAllergies(_selectedAllergies);

    final profile = up.profile;
    if (profile != null && mounted) {
      context.read<RecipeProvider>().loadRecommendations(profile: profile);
    }

    if (mounted) setState(() { _saving = false; _dirty = false; });
  }

  void _mark() => setState(() => _dirty = true);

  // ── Toggle helpers ─────────────────────────────────────────────────────────

  bool _hasDiet(String id)    => _selectedDiets.any((d) => d.toLowerCase() == id);
  bool _hasCuisine(String id) => _selectedCuisines.any((c) => c.toLowerCase() == id.toLowerCase());
  bool _hasAllergy(String id) => _selectedAllergies.any((a) => a.toLowerCase() == id);

  void _toggleDiet(String id) {
    setState(() {
      if (_hasDiet(id)) {
        _selectedDiets.removeWhere((d) => d.toLowerCase() == id);
        // Removing vegan doesn't remove vegetarian automatically
      } else {
        if (id == 'vegan' && !_hasDiet('vegetarian')) _selectedDiets.add('vegetarian');
        _selectedDiets.add(id);
      }
    });
    _mark();
  }

  void _toggleCuisine(String id) {
    setState(() {
      if (_hasCuisine(id)) {
        _selectedCuisines.removeWhere((c) => c.toLowerCase() == id.toLowerCase());
      } else {
        _selectedCuisines.add(id);
      }
    });
    _mark();
  }

  void _toggleAllergy(String id) {
    setState(() {
      if (_hasAllergy(id)) {
        _selectedAllergies.removeWhere((a) => a.toLowerCase() == id);
      } else {
        _selectedAllergies.add(id);
      }
    });
    _mark();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.backgroundDark : const Color(0xFFF7F6FB);

    return WillPopScope(
      onWillPop: () async { await _save(); return true; },
      child: Scaffold(
        backgroundColor: bg,
        body: CustomScrollView(
          slivers: [
            _appBar(isDark),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 48),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _identityCard(isDark),
                  _divider(),
                  _sectionHeader('Cooking Mode',
                      'Shapes what kind of recipes we surface', null, isDark),
                  _modeGrid(isDark),
                  _divider(),
                  _sectionHeader('Daily Calorie Target',
                      'Matches recipes to your per-meal energy goal', null, isDark),
                  _calorieSlider(isDark),
                  _divider(),
                  _sectionHeader(
                    'Dietary Preferences',
                    'Hard exclusions — non-compliant recipes are never shown',
                    _selectedDiets.isNotEmpty ? '${_selectedDiets.length} active' : null,
                    isDark,
                    badgeColor: AppTheme.successGreen,
                  ),
                  _chipGrid(_selectedDiets, _diets, isDark, AppTheme.successGreen, _toggleDiet),
                  _divider(),
                  _sectionHeader(
                    'Favourite Cuisines',
                    'Matching recipes are always ranked first',
                    _selectedCuisines.isNotEmpty ? '${_selectedCuisines.length} selected' : null,
                    isDark,
                  ),
                  _chipGrid(_selectedCuisines, _cuisines, isDark, AppTheme.primaryPurple, _toggleCuisine),
                  _divider(),
                  _sectionHeader(
                    'Allergies & Intolerances',
                    'Hard exclusions — these ingredients are never shown',
                    _selectedAllergies.isNotEmpty ? '${_selectedAllergies.length} active' : null,
                    isDark,
                    badgeColor: AppTheme.accentOrange,
                  ),
                  _chipGrid(_selectedAllergies, _allergies, isDark, AppTheme.accentOrange, _toggleAllergy),
                  const SizedBox(height: 32),
                  _saveButton(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── App bar ────────────────────────────────────────────────────────────────

  Widget _appBar(bool isDark) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 100,
      backgroundColor: isDark ? AppTheme.backgroundDark : const Color(0xFFF7F6FB),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () async { await _save(); if (mounted) Navigator.pop(context); },
      ),
      actions: [
        if (_saving)
          const Padding(
            padding: EdgeInsets.only(right: 20),
            child: Center(
              child: SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(AppTheme.primaryPurple)),
              ),
            ),
          )
        else if (_dirty)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _save,
              child: const Text('Save',
                  style: TextStyle(
                      color: AppTheme.primaryPurple,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
            ),
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Profile',
                style: TextStyle(
                    fontSize: 26, fontWeight: FontWeight.w800,
                    letterSpacing: -0.6)),
            Text('Identity & preferences',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: isDark
                        ? AppTheme.textSecondaryDark
                        : AppTheme.textSecondaryLight)),
          ],
        ),
      ),
    );
  }

  // ── Identity card ──────────────────────────────────────────────────────────

  Widget _identityCard(bool isDark) {
    final initial = (_nameCtrl.text.isNotEmpty ? _nameCtrl.text[0] : '?')
        .toUpperCase();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              gradient: AppTheme.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(initial,
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ),
          ),
          const SizedBox(width: 16),
          // Name field
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Display name',
                    style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppTheme.textSecondaryDark
                            : AppTheme.textSecondaryLight,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                TextField(
                  controller: _nameCtrl,
                  onChanged: (_) { setState(() {}); _mark(); },
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    hintText: 'Your name',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    filled: true,
                    fillColor: isDark ? AppTheme.cardDark : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppTheme.primaryPurple, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Cooking mode grid ──────────────────────────────────────────────────────

  Widget _modeGrid(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        children: CookingMode.values.map((mode) {
          final sel = _mode == mode;
          final colors = mode.gradientColors.map((c) => Color(c)).toList();
          return GestureDetector(
            onTap: () { setState(() => _mode = mode); _mark(); },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: sel ? LinearGradient(colors: colors) : null,
                color: sel ? null : (isDark ? AppTheme.cardDark : Colors.white),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: sel ? Colors.transparent
                      : (isDark ? Colors.white12 : Colors.black12),
                ),
                boxShadow: sel
                    ? [BoxShadow(
                        color: colors.first.withOpacity(0.3),
                        blurRadius: 12, offset: const Offset(0, 4))]
                    : [],
              ),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: sel
                          ? Colors.white.withOpacity(0.2)
                          : colors.first.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Center(
                        child: Text(mode.emoji,
                            style: const TextStyle(fontSize: 19))),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(mode.label,
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14,
                                color: sel ? Colors.white : null)),
                        const SizedBox(height: 1),
                        Text(mode.tagline,
                            style: TextStyle(
                                fontSize: 11,
                                color: sel
                                    ? Colors.white.withOpacity(0.8)
                                    : (isDark
                                        ? AppTheme.textSecondaryDark
                                        : AppTheme.textSecondaryLight))),
                      ],
                    ),
                  ),
                  Icon(
                    sel ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: sel ? Colors.white
                        : (isDark ? Colors.white24 : Colors.black26),
                    size: 20,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Calorie slider ─────────────────────────────────────────────────────────

  Widget _calorieSlider(bool isDark) {
    final macros = MacroTargets.fromCalories(_calories);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        children: [
          // Big number display
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('$_calories',
                  style: const TextStyle(
                      fontSize: 48, fontWeight: FontWeight.w800,
                      color: AppTheme.primaryPurple, letterSpacing: -2)),
              const SizedBox(width: 6),
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text('kcal / day',
                    style: TextStyle(
                        fontSize: 14, color: AppTheme.textSecondaryLight,
                        fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppTheme.primaryPurple,
              inactiveTrackColor: AppTheme.primaryPurple.withOpacity(0.15),
              thumbColor: AppTheme.primaryPurple,
              overlayColor: AppTheme.primaryPurple.withOpacity(0.1),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
              trackHeight: 5,
            ),
            child: Slider(
              value: _calories.toDouble(),
              min: 1200, max: 4000, divisions: 56,
              onChanged: (v) { setState(() => _calories = v.round()); _mark(); },
            ),
          ),
          // Range labels
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: ['1,200', '1,800', '2,500', '3,200', '4,000']
                  .map((l) => Text(l,
                      style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.textSecondaryLight)))
                  .toList(),
            ),
          ),
          const SizedBox(height: 14),
          // Macro breakdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.cardDark
                  : AppTheme.primaryPurple.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppTheme.primaryPurple.withOpacity(0.12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _macroTile('Protein', '${macros.proteinG.round()}g',
                    Colors.red.shade400),
                _vline(isDark),
                _macroTile('Carbs', '${macros.carbsG.round()}g',
                    Colors.blue.shade400),
                _vline(isDark),
                _macroTile('Fat', '${macros.fatG.round()}g',
                    Colors.orange.shade400),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _macroTile(String label, String value, Color color) => Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppTheme.textSecondaryLight)),
        ],
      );

  Widget _vline(bool isDark) => Container(
        width: 1, height: 28,
        color: isDark ? Colors.white12 : Colors.black12);

  // ── Chip grid ──────────────────────────────────────────────────────────────

  // Works for diets, cuisines, and allergies by accepting the relevant _Opt list.
  Widget _chipGrid(
    List<String> activeList,
    List<_Opt> optionList,
    bool isDark,
    Color activeColor,
    void Function(String) onToggle,
  ) {
    final opts = optionList;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Wrap(
        spacing: 9,
        runSpacing: 9,
        children: opts.map((opt) {
          final on = activeColor == AppTheme.primaryPurple
              ? _hasCuisine(opt.id)
              : activeColor == AppTheme.successGreen
                  ? _hasDiet(opt.id)
                  : _hasAllergy(opt.id);
          return GestureDetector(
            onTap: () => onToggle(opt.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              decoration: BoxDecoration(
                color: on
                    ? activeColor.withOpacity(0.12)
                    : (isDark ? AppTheme.cardDark : Colors.white),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: on
                      ? activeColor.withOpacity(0.55)
                      : (isDark ? Colors.white12 : Colors.black12),
                  width: on ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(opt.emoji, style: const TextStyle(fontSize: 15)),
                  const SizedBox(width: 7),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(opt.label,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: on ? activeColor : null)),
                      if (opt.sub != null)
                        Text(opt.sub!,
                            style: TextStyle(
                                fontSize: 10,
                                color: on
                                    ? activeColor.withOpacity(0.7)
                                    : AppTheme.textSecondaryLight)),
                    ],
                  ),
                  if (on) ...[
                    const SizedBox(width: 5),
                    Icon(Icons.check_rounded, size: 13, color: activeColor),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Save button ────────────────────────────────────────────────────────────

  Widget _saveButton() {
    return AnimatedOpacity(
      opacity: _dirty ? 1.0 : 0.35,
      duration: const Duration(milliseconds: 200),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton.icon(
          onPressed: _dirty && !_saving ? _save : null,
          icon: _saving
              ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white))
              : const Icon(Icons.check_circle_rounded),
          label: Text(_saving ? 'Saving…' : 'Save Changes',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryPurple,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppTheme.primaryPurple,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _divider() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Divider(height: 1),
      );

  Widget _sectionHeader(
    String title,
    String subtitle,
    String? badge,
    bool isDark, {
    Color badgeColor = AppTheme.primaryPurple,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppTheme.textSecondaryDark
                            : AppTheme.textSecondaryLight)),
              ],
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(badge,
                  style: TextStyle(
                      fontSize: 11,
                      color: badgeColor,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }
}