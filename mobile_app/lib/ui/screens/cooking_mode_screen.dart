// lib/ui/screens/cooking_mode_screen.dart
//
// Full-screen cooking mode. Features:
//  • Step-by-step navigation with progress bar
//  • Per-step countdown timer (auto-detected from step text)
//  • AI assistant panel that knows the current recipe + step
//  • Completion screen on final step

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../core/constants/theme/app_theme.dart';
import '../../services/spoonacular_service.dart';
import '../../services/recipe_ranking_engine.dart';
import '../../state/user_provider.dart';
import '../../core/config/app_config.dart';
import '../../services/nutrition_history_service.dart';
import '../../services/recipe_history_service.dart';

class CookingModeScreen extends StatefulWidget {
  final RankedRecipe ranked;

  const CookingModeScreen({super.key, required this.ranked});

  @override
  State<CookingModeScreen> createState() => _CookingModeScreenState();
}

class _CookingModeScreenState extends State<CookingModeScreen>
    with TickerProviderStateMixin {
  int _currentStep = 0;
  bool _completed = false;

  // Timer state
  int _timerSeconds = 0;
  int _timerTotal = 0;
  bool _timerRunning = false;
  Timer? _ticker;

  // AI panel
  bool _aiPanelOpen = false;
  final TextEditingController _aiInputController = TextEditingController();
  final ScrollController _aiScrollController = ScrollController();
  final List<_ChatMsg> _aiMessages = [];
  bool _aiLoading = false;

  // Step scroll
  final ScrollController _stepScrollController = ScrollController();

  static String get _backendUrl => AppConfig.assistantChatUrl;

  List<SpoonacularStep> get _steps => widget.ranked.recipe.steps;
  SpoonacularStep get _step => _steps[_currentStep];
  bool get _isLastStep => _currentStep == _steps.length - 1;

  @override
  void initState() {
    super.initState();
    _setupTimer();
    // Greet the user with context about the first step
    WidgetsBinding.instance.addPostFrameCallback((_) => _aiGreet());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _aiInputController.dispose();
    _aiScrollController.dispose();
    _stepScrollController.dispose();
    super.dispose();
  }

  // ── Timer ─────────────────────────────────────────────────────────────────

  void _setupTimer() {
    _ticker?.cancel();
    _timerRunning = false;
    final detected = _detectMinutes(_step.step);
    _timerSeconds = detected * 60;
    _timerTotal = _timerSeconds;
  }

  /// Scan step text for patterns like "5 minutes", "2 mins", "30 seconds"
  int _detectMinutes(String text) {
    final minMatch =
        RegExp(r'(\d+)\s*(minute|min)', caseSensitive: false).firstMatch(text);
    if (minMatch != null) return int.parse(minMatch.group(1)!);
    final secMatch =
        RegExp(r'(\d+)\s*(second|sec)', caseSensitive: false).firstMatch(text);
    if (secMatch != null) return 0; // <1 min — no timer
    return 0;
  }

  void _startTimer() {
    if (_timerSeconds <= 0) return;
    setState(() => _timerRunning = true);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_timerSeconds > 0) {
          _timerSeconds--;
        } else {
          _timerRunning = false;
          _ticker?.cancel();
          _onTimerFinished();
        }
      });
    });
  }

  void _pauseTimer() {
    _ticker?.cancel();
    setState(() => _timerRunning = false);
  }

  void _resetTimer() {
    _ticker?.cancel();
    setState(() {
      _timerSeconds = _timerTotal;
      _timerRunning = false;
    });
  }

  void _onTimerFinished() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.notifications_active_rounded, color: Colors.white),
          const SizedBox(width: 8),
          Text('Step ${_currentStep + 1} timer done! ⏰'),
        ]),
        backgroundColor: AppTheme.successGreen,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _formatTimer(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ── Step navigation ───────────────────────────────────────────────────────

  void _goToStep(int index) {
    setState(() {
      _currentStep = index;
      _setupTimer();
    });
    _stepScrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _nextStep() {
    if (_isLastStep) {
      _logCompletion();
      setState(() => _completed = true);
    } else {
      _goToStep(_currentStep + 1);
      _aiStepHint(_currentStep);
    }
  }
 
  Future<void> _logCompletion() async {
    final r = widget.ranked.recipe;
    try {
      // Log to nutrition history
      await NutritionHistoryService.instance.logMeal(
        recipeId:     r.id,
        recipeTitle:  r.title,
        recipeImage:  r.image,
        calories:     r.nutrition.calories,
        protein:      r.nutrition.protein,
        carbs:        r.nutrition.carbs,
        fat:          r.nutrition.fat,
        fiber:        r.nutrition.fiber,
        sodium:       r.nutrition.sodium,
        servings:     r.servings,
        cuisines:     r.cuisines,
        tags:         [
          if (r.vegan)        'vegan',
          if (r.vegetarian)   'vegetarian',
          if (r.glutenFree)   'glutenFree',
          if (r.dairyFree)    'dairyFree',
          if (r.veryHealthy)  'veryHealthy',
        ],
      );
      // Log to recipe history (cook count)
      await RecipeHistoryService.instance.recordCook(r);
    } catch (e) {
      debugPrint('[CookingMode] Failed to log completion: $e');
    }
  }

  void _prevStep() {
    if (_currentStep > 0) _goToStep(_currentStep - 1);
  }

  // ── AI ────────────────────────────────────────────────────────────────────

  String _buildCookingContext() {
    final r = widget.ranked.recipe;
    final profile = context.read<UserProvider>().profile;
    final buf = StringBuffer();

    buf.writeln('=== COOKING MODE CONTEXT ===');
    buf.writeln('Recipe: ${r.title}');
    buf.writeln('Total steps: ${_steps.length}');
    buf.writeln('Current step: ${_currentStep + 1} of ${_steps.length}');
    buf.writeln('Current step text: "${_step.step}"');
    if (_step.ingredients.isNotEmpty) {
      buf.writeln('Ingredients needed now: ${_step.ingredients.join(', ')}');
    }
    if (_step.equipment.isNotEmpty) {
      buf.writeln('Equipment: ${_step.equipment.join(', ')}');
    }

    // All steps for full recipe awareness
    buf.writeln('\nAll steps:');
    for (final s in _steps) {
      buf.writeln('  Step ${s.number}: ${s.step}');
    }

    // Nutrition
    buf.writeln(
        '\nNutrition (total): ${r.nutrition.calories.round()} kcal, '
        '${r.nutrition.protein.toStringAsFixed(1)}g protein, '
        '${r.nutrition.carbs.toStringAsFixed(1)}g carbs, '
        '${r.nutrition.fat.toStringAsFixed(1)}g fat');

    if (profile != null) {
      buf.writeln('\nUser profile:');
      buf.writeln('  Dietary preferences: ${profile.dietaryPreferences.join(', ')}');
      buf.writeln('  Allergies: ${profile.allergies.join(', ')}');
    }

    buf.writeln('\nPrevious AI messages in this session:');
    for (final m in _aiMessages.take(6)) {
      buf.writeln('${m.isUser ? 'User' : 'PIATRA'}: ${m.text}');
    }

    return buf.toString();
  }

  Future<void> _aiGreet() async {
    final r = widget.ranked.recipe;
    final greeting = "Let's cook **${r.title}**! 🍳\n\n"
        "I'm with you for every step. We're starting with Step 1:\n\n"
        "_${_steps.first.step}_\n\n"
        "Ask me anything — substitutions, techniques, timings, or just say 'next tip'!";
    setState(() => _aiMessages.add(_ChatMsg(text: greeting, isUser: false)));
  }

  /// Called automatically when advancing to a new step
  Future<void> _aiStepHint(int stepIndex) async {
    if (!_aiPanelOpen) return; // only send if panel is open
    final step = _steps[stepIndex];
    await _sendToAI(
      'I just moved to step ${step.number}. Give me a quick pro tip for this step in 1–2 sentences.',
      auto: true,
    );
  }

  Future<void> _sendUserMessage() async {
    final text = _aiInputController.text.trim();
    if (text.isEmpty || _aiLoading) return;
    _aiInputController.clear();
    await _sendToAI(text, auto: false);
  }

  Future<void> _sendToAI(String message, {required bool auto}) async {
    setState(() {
      if (!auto) _aiMessages.add(_ChatMsg(text: message, isUser: true));
      _aiLoading = true;
    });
    _scrollAiToBottom();

    final context_ = _buildCookingContext();
    final systemPrompt =
        'You are PIATRA, an AI sous-chef assisting during active cooking. '
        'You are aware of the exact recipe, every step, the current step the user is on, '
        'and their dietary profile. Be concise, practical, and encouraging. '
        'Never repeat the full step back unless asked.';

    try {
      final response = await http
          .post(
            Uri.parse(_backendUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'message': message,
              'context': '$systemPrompt\n\n$context_',
              'user_id': '',
            }),
          )
          .timeout(const Duration(seconds: 30));

      String reply;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        reply = data['response'] as String? ?? 'Sorry, got an empty response.';
      } else {
        reply = 'Server error (${response.statusCode}).';
      }

      if (mounted) {
        setState(() => _aiMessages.add(_ChatMsg(text: reply, isUser: false)));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _aiMessages
            .add(_ChatMsg(text: 'Could not reach assistant: $e', isUser: false)));
      }
    } finally {
      if (mounted) setState(() => _aiLoading = false);
      _scrollAiToBottom();
    }
  }

  void _scrollAiToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_aiScrollController.hasClients) {
        _aiScrollController.animateTo(
          _aiScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Quick AI prompts ──────────────────────────────────────────────────────

  static const List<String> _quickPrompts = [
    '💡 Pro tip for this step',
    '🔄 Substitution ideas',
    '⏱ How long exactly?',
    '❓ What does this mean?',
    '🌡 Temperature guide',
  ];

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_completed) return _CompletionScreen(recipe: widget.ranked.recipe);

    return Scaffold(
      backgroundColor:
          isDark ? AppTheme.backgroundDark : AppTheme.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(isDark),
            _buildProgressBar(),
            Expanded(
              child: Stack(
                children: [
                  _buildStepContent(isDark),
                  // AI panel slides up from bottom
                  if (_aiPanelOpen) _buildAiPanel(isDark),
                ],
              ),
            ),
            _buildBottomBar(isDark),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: _confirmExit,
            icon: const Icon(Icons.close_rounded),
            style: IconButton.styleFrom(
              backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.ranked.recipe.title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Step ${_currentStep + 1} of ${_steps.length}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppTheme.textSecondaryDark
                        : AppTheme.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          // Step picker
          PopupMenuButton<int>(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.cardDark : Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.list_rounded, size: 20),
            ),
            onSelected: _goToStep,
            itemBuilder: (_) => _steps
                .map((s) => PopupMenuItem(
                      value: s.number - 1,
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: s.number - 1 == _currentStep
                                  ? AppTheme.primaryPurple
                                  : AppTheme.primaryPurple.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${s.number}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: s.number - 1 == _currentStep
                                      ? Colors.white
                                      : AppTheme.primaryPurple,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              s.step,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  // ── Progress bar ──────────────────────────────────────────────────────────

  Widget _buildProgressBar() {
    final progress = (_currentStep + 1) / _steps.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppTheme.primaryPurple.withOpacity(0.12),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppTheme.primaryPurple),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(progress * 100).round()}% complete',
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.primaryPurple,
                    fontWeight: FontWeight.w600),
              ),
              Text(
                '${_steps.length - _currentStep - 1} steps left',
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textSecondaryLight),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Step content ──────────────────────────────────────────────────────────

  Widget _buildStepContent(bool isDark) {
    return SingleChildScrollView(
      controller: _stepScrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF5B54E8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryPurple.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Step ${_step.number}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                      ),
                    ),
                    const Spacer(),
                    if (_isLastStep)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.successGreen.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('Final step! 🎉',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  _step.step,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    height: 1.6,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Ingredients & equipment for this step
          if (_step.ingredients.isNotEmpty || _step.equipment.isNotEmpty)
            _buildStepMeta(isDark),

          const SizedBox(height: 16),

          // Timer
          if (_timerTotal > 0) _buildTimerCard(isDark),

          const SizedBox(height: 16),

          // Quick AI prompts
          _buildQuickPrompts(isDark),
        ],
      ),
    );
  }

  Widget _buildStepMeta(bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_step.ingredients.isNotEmpty)
          Expanded(
            child: _MetaCard(
              icon: Icons.egg_rounded,
              title: 'Ingredients',
              items: _step.ingredients,
              color: AppTheme.successGreen,
              isDark: isDark,
            ),
          ),
        if (_step.ingredients.isNotEmpty && _step.equipment.isNotEmpty)
          const SizedBox(width: 12),
        if (_step.equipment.isNotEmpty)
          Expanded(
            child: _MetaCard(
              icon: Icons.kitchen_rounded,
              title: 'Equipment',
              items: _step.equipment,
              color: AppTheme.infoBlue,
              isDark: isDark,
            ),
          ),
      ],
    );
  }

  Widget _buildTimerCard(bool isDark) {
    final progress = _timerTotal > 0 ? _timerSeconds / _timerTotal : 0.0;
    final isWarning = _timerSeconds <= 30 && _timerSeconds > 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isWarning
              ? AppTheme.warningYellow
              : AppTheme.primaryPurple.withOpacity(0.15),
          width: isWarning ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.timer_rounded,
                color: isWarning ? AppTheme.warningYellow : AppTheme.primaryPurple,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Step Timer',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isWarning ? AppTheme.warningYellow : AppTheme.primaryPurple,
                ),
              ),
              const Spacer(),
              Text(
                _formatTimer(_timerSeconds),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: isWarning ? AppTheme.warningYellow : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppTheme.primaryPurple.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(
                isWarning ? AppTheme.warningYellow : AppTheme.primaryPurple,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _TimerBtn(
                icon: Icons.replay_rounded,
                label: 'Reset',
                onTap: _resetTimer,
                color: AppTheme.textSecondaryLight,
              ),
              const SizedBox(width: 16),
              _TimerBtn(
                icon: _timerRunning
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                label: _timerRunning ? 'Pause' : 'Start',
                onTap: _timerRunning ? _pauseTimer : _startTimer,
                color: AppTheme.primaryPurple,
                filled: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPrompts(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Ask PIATRA',
            style:
                TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _quickPrompts
                .map((prompt) => GestureDetector(
                      onTap: () {
                        setState(() => _aiPanelOpen = true);
                        _sendToAI(prompt, auto: false);
                        // Also show it as user message
                        setState(() =>
                            _aiMessages.add(_ChatMsg(text: prompt, isUser: true)));
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppTheme.cardDark
                              : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: AppTheme.primaryPurple.withOpacity(0.2)),
                        ),
                        child: Text(
                          prompt,
                          style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.primaryPurple,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }

  // ── AI Panel ──────────────────────────────────────────────────────────────

  Widget _buildAiPanel(bool isDark) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.52,
        decoration: BoxDecoration(
          color: isDark ? AppTheme.surfaceDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, -4)),
          ],
        ),
        child: Column(
          children: [
            // Handle + header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.auto_awesome_rounded,
                        color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PIATRA Sous-Chef',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                        Text('AI cooking assistant',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondaryLight)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _aiPanelOpen = false),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: isDark
                          ? AppTheme.cardDark
                          : Colors.grey.shade100,
                    ),
                  ),
                ],
              ),
            ),

            // Messages
            Expanded(
              child: ListView.builder(
                controller: _aiScrollController,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                itemCount: _aiMessages.length + (_aiLoading ? 1 : 0),
                itemBuilder: (_, i) {
                  if (i == _aiMessages.length) return _buildTypingDots();
                  return _buildAiMessage(_aiMessages[i], isDark);
                },
              ),
            ),

            // Input
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.cardDark : Colors.grey.shade50,
                border: Border(
                    top: BorderSide(
                        color: (isDark ? Colors.white : Colors.black)
                            .withOpacity(0.06))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _aiInputController,
                      enabled: !_aiLoading,
                      decoration: InputDecoration(
                        hintText: 'Ask about this step…',
                        filled: true,
                        fillColor:
                            isDark ? AppTheme.surfaceDark : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                      ),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _sendUserMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _aiLoading ? null : _sendUserMessage,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: _aiLoading
                            ? LinearGradient(colors: [
                                Colors.grey.shade400,
                                Colors.grey.shade400
                              ])
                            : AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.send_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiMessage(_ChatMsg msg, bool isDark) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        decoration: BoxDecoration(
          gradient: msg.isUser ? AppTheme.primaryGradient : null,
          color: msg.isUser
              ? null
              : (isDark ? AppTheme.cardDark : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight:
                msg.isUser ? const Radius.circular(4) : null,
            bottomLeft:
                msg.isUser ? null : const Radius.circular(4),
          ),
        ),
        child: Text(
          msg.text,
          style: TextStyle(
            fontSize: 14,
            height: 1.45,
            color: msg.isUser ? Colors.white : null,
          ),
        ),
      ),
    );
  }

  Widget _buildTypingDots() {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: _TypingIndicator(),
      ),
    );
  }

  // ── Bottom bar ────────────────────────────────────────────────────────────

  Widget _buildBottomBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 8,
              offset: const Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // AI toggle
            GestureDetector(
              onTap: () => setState(() => _aiPanelOpen = !_aiPanelOpen),
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: _aiPanelOpen
                      ? AppTheme.accentGradient
                      : AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryPurple.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  _aiPanelOpen
                      ? Icons.keyboard_arrow_down_rounded
                      : Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Prev
            if (_currentStep > 0)
              Expanded(
                flex: 1,
                child: OutlinedButton.icon(
                  onPressed: _prevStep,
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Back'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),

            if (_currentStep > 0) const SizedBox(width: 10),

            // Next / Finish
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _nextStep,
                icon: Icon(
                  _isLastStep
                      ? Icons.check_circle_rounded
                      : Icons.arrow_forward_rounded,
                  size: 18,
                ),
                label: Text(_isLastStep ? 'Finish!' : 'Next Step'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor:
                      _isLastStep ? AppTheme.successGreen : null,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Exit confirm ──────────────────────────────────────────────────────────

  void _confirmExit() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Exit cooking mode?'),
        content: const Text('Your progress won\'t be saved.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Keep cooking')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // dialog
              Navigator.pop(context); // screen
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.accentOrange),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }
}

// ─── Completion screen ────────────────────────────────────────────────────────

class _CompletionScreen extends StatelessWidget {
  final SpoonacularRecipe recipe;
  const _CompletionScreen({required this.recipe});
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.accentGradient),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🎉', style: TextStyle(fontSize: 80)),
                  const SizedBox(height: 24),
                  const Text(
                    'You did it!',
                    style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    recipe.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 20,
                        color: Colors.white,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 20),
                  // Nutrition summary card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        const Text('Logged to Nutrition History ✓',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _NutStat('${recipe.nutrition.calories.round()}', 'kcal'),
                            _NutStat('${recipe.nutrition.protein.toStringAsFixed(1)}g', 'protein'),
                            _NutStat('${recipe.nutrition.carbs.toStringAsFixed(1)}g', 'carbs'),
                            _NutStat('${recipe.nutrition.fat.toStringAsFixed(1)}g', 'fat'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.of(context)
                            ..pop()
                            ..pop(),
                          icon: const Icon(Icons.home_rounded,
                              color: Colors.white),
                          label: const Text('Home',
                              style: TextStyle(color: Colors.white)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white54),
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.of(context)
                            ..pop()
                            ..pop()
                            ..pushNamed('/analytics'),
                          icon: const Icon(Icons.bar_chart_rounded),
                          label: const Text('Analytics'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppTheme.successGreen,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
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
      ),
    );
  }
}
 
class _NutStat extends StatelessWidget {
  final String value;
  final String label;
  const _NutStat(this.value, this.label);
 
  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          Text(label,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 11)),
        ],
      );
}

// ─── Helper widgets ───────────────────────────────────────────────────────────

class _MetaCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> items;
  final Color color;
  final bool isDark;

  const _MetaCard({
    required this.icon,
    required this.title,
    required this.items,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(title,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: color)),
            ],
          ),
          const SizedBox(height: 8),
          ...items.map((i) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text('• $i',
                    style: const TextStyle(fontSize: 13)),
              )),
        ],
      ),
    );
  }
}

class _TimerBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final bool filled;

  const _TimerBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: filled ? color : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: filled ? Colors.white : color),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: filled ? Colors.white : color)),
          ],
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(16).copyWith(
          bottomLeft: const Radius.circular(4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
            3,
            (i) => AnimatedBuilder(
                  animation: _ctrl,
                  builder: (_, __) {
                    final offset =
                        ((_ctrl.value * 3 - i) % 1.0).clamp(0.0, 1.0);
                    final dy = offset < 0.5
                        ? -4.0 * (offset / 0.5)
                        : -4.0 * (1 - (offset - 0.5) / 0.5);
                    return Transform.translate(
                      offset: Offset(0, dy),
                      child: Container(
                        width: 7,
                        height: 7,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: const BoxDecoration(
                          color: AppTheme.primaryPurple,
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  },
                )),
      ),
    );
  }
}

class _ChatMsg {
  final String text;
  final bool isUser;
  _ChatMsg({required this.text, required this.isUser});
}