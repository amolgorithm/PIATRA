// lib/ui/screens/feedback_form_screen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../../core/constants/theme/app_theme.dart';

class FeedbackFormScreen extends StatefulWidget {
  const FeedbackFormScreen({Key? key}) : super(key: key);

  @override
  State<FeedbackFormScreen> createState() => _FeedbackFormScreenState();
}

class _FeedbackFormScreenState extends State<FeedbackFormScreen>
    with TickerProviderStateMixin {
  final TextEditingController _feedbackController = TextEditingController();
  _FeedbackCategory _selectedCategory = _FeedbackCategory.general;
  int _rating = 0;
  bool _isSubmitting = false;
  bool _submitted = false;

  late AnimationController _entranceCtrl;
  late AnimationController _successCtrl;
  late Animation<double> _entranceFade;
  late Animation<Offset> _entranceSlide;
  late Animation<double> _successScale;
  late Animation<double> _successFade;

  @override
  void initState() {
    super.initState();

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _successCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _entranceFade =
        CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut);
    _entranceSlide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutCubic));

    _successScale = Tween<double>(begin: 0.7, end: 1.0).animate(
        CurvedAnimation(parent: _successCtrl, curve: Curves.easeOutBack));
    _successFade =
        CurvedAnimation(parent: _successCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    _entranceCtrl.dispose();
    _successCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendFeedback() async {
    final feedbackText = _feedbackController.text.trim();
    if (feedbackText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [
            Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Text('Please write your feedback first.'),
          ]),
          backgroundColor: AppTheme.warningYellow,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final payload = {
      'feedback':
          '[${_selectedCategory.label}]${_rating > 0 ? ' [${_ratingStars(_rating)}]' : ''} $feedbackText',
      'user_id': '',
    };

    try {
      final response = await http
          .post(
            Uri.parse(AppConfig.feedbackUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        setState(() {
          _isSubmitting = false;
          _submitted = true;
        });
        _successCtrl.forward();
      } else {
        _showError('Server error (${response.statusCode}). Please try again.');
      }
    } catch (e) {
      _showError('Could not reach the server. Check your connection.');
    } finally {
      if (mounted && !_submitted) setState(() => _isSubmitting = false);
    }
  }

  String _ratingStars(int r) => List.filled(r, '*').join();

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(msg)),
        ]),
        backgroundColor: AppTheme.errorRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _reset() {
    setState(() {
      _submitted = false;
      _rating = 0;
      _selectedCategory = _FeedbackCategory.general;
      _feedbackController.clear();
    });
    _successCtrl.reset();
    _entranceCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
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
          Positioned(
            top: -50,
            right: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  const Color(0xFFB24BF3).withOpacity(isDark ? 0.18 : 0.09),
                  Colors.transparent,
                ]),
              ),
            ),
          ),

          SafeArea(
            child: _submitted ? _buildSuccessView(isDark) : _buildForm(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView(bool isDark) {
    return FadeTransition(
      opacity: _successFade,
      child: ScaleTransition(
        scale: _successScale,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFB24BF3), Color(0xFF9D3FDD)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFB24BF3).withOpacity(0.4),
                        blurRadius: 28,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: Colors.white, size: 52),
                ),
                const SizedBox(height: 32),
                Text(
                  'Thank you!',
                  style: TextStyle(
                    fontFamily: 'Sora',
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? AppTheme.textPrimaryDark
                        : AppTheme.textPrimaryLight,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your feedback helps make PIATRA\nbetter for everyone.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.55,
                    color: isDark
                        ? AppTheme.textSecondaryDark
                        : AppTheme.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 40),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _reset,
                        icon: const Icon(Icons.edit_rounded, size: 18),
                        label: const Text('Send More'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.home_rounded, size: 18),
                        label: const Text('Done'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: const Color(0xFFB24BF3),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(bool isDark) {
    return FadeTransition(
      opacity: _entranceFade,
      child: SlideTransition(
        position: _entranceSlide,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(isDark)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _sectionLabel('What is your feedback about?', isDark),
                  const SizedBox(height: 12),
                  _buildCategoryGrid(isDark),
                  const SizedBox(height: 24),

                  _sectionLabel('How would you rate your experience?', isDark),
                  const SizedBox(height: 12),
                  _buildStarRating(isDark),
                  const SizedBox(height: 24),

                  _sectionLabel('Tell us more', isDark),
                  const SizedBox(height: 12),
                  _buildTextField(isDark),
                  const SizedBox(height: 32),

                  _buildSubmitButton(isDark),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.cardDark : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? const Color(0x18FFFFFF)
                          : const Color(0x10000000),
                    ),
                  ),
                  child: Icon(
                    Icons.arrow_back_rounded,
                    color: isDark
                        ? AppTheme.textPrimaryDark
                        : AppTheme.textPrimaryLight,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFB24BF3), Color(0xFF9D3FDD)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFB24BF3).withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.rate_review_rounded,
                    color: Colors.white, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Share Your\nFeedback',
            style: TextStyle(
              fontFamily: 'Sora',
              fontSize: 34,
              fontWeight: FontWeight.w800,
              height: 1.15,
              letterSpacing: -1.0,
              color: isDark
                  ? AppTheme.textPrimaryDark
                  : AppTheme.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your thoughts help us build a better PIATRA.',
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: isDark
                  ? AppTheme.textSecondaryDark
                  : AppTheme.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'Sora',
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
        letterSpacing: -0.2,
      ),
    );
  }

  Widget _buildCategoryGrid(bool isDark) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _FeedbackCategory.values.map((cat) {
        final selected = _selectedCategory == cat;
        return GestureDetector(
          onTap: () => setState(() => _selectedCategory = cat),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: selected
                  ? const LinearGradient(
                      colors: [Color(0xFFB24BF3), Color(0xFF9D3FDD)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: selected
                  ? null
                  : (isDark ? AppTheme.cardDark : Colors.white),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? Colors.transparent
                    : (isDark
                        ? const Color(0x22FFFFFF)
                        : const Color(0x14000000)),
                width: 1.2,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: const Color(0xFFB24BF3).withOpacity(0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ]
                  : [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(cat.icon,
                    size: 16,
                    color: selected ? Colors.white : const Color(0xFFB24BF3)),
                const SizedBox(width: 8),
                Text(
                  cat.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? Colors.white
                        : (isDark
                            ? AppTheme.textPrimaryDark
                            : AppTheme.textPrimaryLight),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStarRating(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? const Color(0x18FFFFFF)
              : const Color(0x10000000),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final starIndex = i + 1;
              final filled = starIndex <= _rating;
              return GestureDetector(
                onTap: () => setState(() =>
                    _rating = _rating == starIndex ? 0 : starIndex),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 4),
                  child: Icon(
                    filled ? Icons.star_rounded : Icons.star_border_rounded,
                    color: filled
                        ? AppTheme.warningYellow
                        : (isDark
                            ? AppTheme.textSecondaryDark
                            : AppTheme.textSecondaryLight),
                    size: filled ? 38 : 34,
                  ),
                ),
              );
            }),
          ),
          if (_rating > 0) ...[
            const SizedBox(height: 8),
            Text(
              _ratingLabel(_rating),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.warningYellow,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _ratingLabel(int r) {
    switch (r) {
      case 1: return 'Needs a lot of work';
      case 2: return 'Could be better';
      case 3: return 'Pretty good';
      case 4: return 'Really enjoying it';
      case 5: return 'Absolutely love it!';
      default: return '';
    }
  }

  Widget _buildTextField(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? const Color(0x22FFFFFF)
              : const Color(0x12000000),
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Focus(
        child: Builder(builder: (ctx) {
          final focused = Focus.of(ctx).hasFocus;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: focused
                    ? const Color(0xFFB24BF3)
                    : Colors.transparent,
                width: 1.8,
              ),
            ),
            child: TextField(
              controller: _feedbackController,
              minLines: 5,
              maxLines: 10,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText:
                    'Describe your experience, report a bug, suggest a feature, or just say hi...',
                hintMaxLines: 3,
                border: InputBorder.none,
                filled: false,
                contentPadding: const EdgeInsets.all(18),
                hintStyle: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: isDark
                      ? AppTheme.textSecondaryDark
                      : AppTheme.textSecondaryLight,
                ),
                counterStyle: TextStyle(
                  fontSize: 11,
                  color: isDark
                      ? AppTheme.textSecondaryDark
                      : AppTheme.textSecondaryLight,
                ),
              ),
              style: TextStyle(
                fontSize: 15,
                height: 1.6,
                color: isDark
                    ? AppTheme.textPrimaryDark
                    : AppTheme.textPrimaryLight,
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSubmitButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _sendFeedback,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFB24BF3),
          disabledBackgroundColor: const Color(0xFFB24BF3).withOpacity(0.5),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _isSubmitting
              ? const SizedBox(
                  key: ValueKey('loading'),
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white),
                )
              : const Row(
                  key: ValueKey('label'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.send_rounded, size: 20),
                    SizedBox(width: 10),
                    Text(
                      'Send Feedback',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

enum _FeedbackCategory {
  general,
  bug,
  feature,
  recipes,
  pantry,
  ai,
}

extension _FeedbackCategoryExt on _FeedbackCategory {
  String get label {
    switch (this) {
      case _FeedbackCategory.general:  return 'General';
      case _FeedbackCategory.bug:      return 'Bug Report';
      case _FeedbackCategory.feature:  return 'Feature Request';
      case _FeedbackCategory.recipes:  return 'Recipes';
      case _FeedbackCategory.pantry:   return 'Pantry';
      case _FeedbackCategory.ai:       return 'Assistant';
    }
  }

  IconData get icon {
    switch (this) {
      case _FeedbackCategory.general:  return Icons.chat_bubble_outline_rounded;
      case _FeedbackCategory.bug:      return Icons.bug_report_outlined;
      case _FeedbackCategory.feature:  return Icons.add_circle_outline_rounded;
      case _FeedbackCategory.recipes:  return Icons.restaurant_outlined;
      case _FeedbackCategory.pantry:   return Icons.kitchen_outlined;
      case _FeedbackCategory.ai:       return Icons.auto_awesome_outlined;
    }
  }
}