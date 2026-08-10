// lib/ui/screens/assistant_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../core/constants/theme/app_theme.dart';
import '../../state/user_provider.dart';
import '../../services/pantry_service.dart';
import '../../models/user_profile_model.dart';
import '../../core/config/app_config.dart';
import '../../services/backend_status_service.dart';
import '../widgets/backend_status_indicator.dart';

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen>
    with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  late AnimationController _inputCtrl;
  late Animation<double> _inputScale;

  static String get _backendUrl => AppConfig.assistantChatUrl;

  static const List<Map<String, dynamic>> _suggestions = [
    {'icon': Icons.dinner_dining_rounded, 'label': 'What can I cook tonight?'},
    {'icon': Icons.eco_rounded,           'label': 'Healthy meal ideas'},
    {'icon': Icons.timer_rounded,         'label': 'Quick 20-min recipes'},
    {'icon': Icons.shopping_cart_rounded, 'label': 'What am I missing?'},
  ];

  @override
  void initState() {
    super.initState();

    _inputCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 200),
      lowerBound: 0.97, upperBound: 1.0, value: 1.0,
    );
    _inputScale = _inputCtrl;

    _messages.add(ChatMessage(
      text: "Hi! I'm PIATRA, your cooking assistant. I can see your pantry and cooking profile automatically. Ask me what you can cook, get nutrition advice, or anything food-related!",
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _inputCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<String> _buildPantryContext() async {
    try {
      final items = await PantryService.instance.getAllItems();
      if (items.isEmpty) return 'Pantry: empty, no items recorded yet.';
      final buf = StringBuffer('Pantry items (${items.length} total):\n');
      for (final item in items) {
        buf.write('- ${item.name}: ${item.quantity}');
        if (item.category.isNotEmpty && item.category != 'Other') {
          buf.write(' [${item.category}]');
        }
        if (item.expiryDate != null) {
          final d = item.expiryDate!;
          buf.write(' (expires ${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')})');
        }
        buf.writeln();
      }
      return buf.toString().trimRight();
    } catch (e) {
      return 'Pantry: could not load ($e)';
    }
  }

  String _buildProfileContext() {
    final profile = context.read<UserProvider>().profile;
    if (profile == null) return 'Cooking profile: not set up yet.';
    final buf = StringBuffer('Cooking profile:\n');
    buf.writeln('- Name: ${profile.displayName}');
    buf.writeln('- Cooking mode: ${profile.cookingMode.emoji} ${profile.cookingMode.label}');
    buf.writeln('- Calorie target: ${profile.calorieTarget} kcal/day');
    if (profile.favoriteCuisines.isNotEmpty) {
      buf.writeln('- Favourite cuisines: ${profile.favoriteCuisines.join(', ')}');
    }
    buf.writeln('- Dietary preferences: ${profile.dietaryPreferences.isEmpty ? 'none' : profile.dietaryPreferences.join(', ')}');
    buf.writeln('- Allergies: ${profile.allergies.isEmpty ? 'none' : profile.allergies.join(', ')}');
    return buf.toString().trimRight();
  }

  Future<void> _sendMessage([String? prefill]) async {
    final text = (prefill ?? _messageController.text).trim();
    if (text.isEmpty || _isLoading) return;

    // If backend is still waking, show a brief hint but still attempt the call
    // (the backend may have just come online or the ping may be lagging).
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true, timestamp: DateTime.now()));
      _isLoading = true;
    });
    _messageController.clear();
    _scrollToBottom();

    final reply = await _fetchAIResponse(text);

    if (mounted) {
      setState(() {
        _messages.add(ChatMessage(text: reply, isUser: false, timestamp: DateTime.now()));
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  Future<String> _fetchAIResponse(String userMessage) async {
    final pantryCtx = await _buildPantryContext();
    final profileCtx = _buildProfileContext();
    final recent = _messages.length > 10
        ? _messages.sublist(_messages.length - 10)
        : List<ChatMessage>.from(_messages);
    final history = recent
        .map((m) => '${m.isUser ? 'User' : 'Assistant'}: ${m.text}')
        .join('\n');

    final ctx = '$profileCtx\n\n$pantryCtx\n\nConversation:\n$history';

    try {
      final response = await http
          .post(
            Uri.parse(_backendUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'message': userMessage,
              'context': ctx,
              'user_id': '',
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['response'] as String? ?? 'Sorry, got an empty response.';
      }
      return 'Server error (${response.statusCode}).';
    } on Exception catch (e) {
      return 'Could not reach the server.\n\nError: $e';
    }
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
            top: -40, right: -60,
            child: Container(
              width: 200, height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppTheme.primaryPurple.withOpacity(isDark ? 0.15 : 0.07),
                  Colors.transparent,
                ]),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildAppBar(isDark),
                Expanded(child: _buildMessageList(isDark)),
                if (_messages.length <= 1) _buildSuggestions(isDark),
                _buildInputArea(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: isDark ? AppTheme.cardDark : Colors.white,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: isDark ? const Color(0x18FFFFFF) : const Color(0x10000000),
                ),
              ),
              child: Icon(Icons.arrow_back_rounded,
                  color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                  size: 20),
            ),
          ),
          const SizedBox(width: 14),
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(13),
              boxShadow: [BoxShadow(
                color: AppTheme.primaryPurple.withOpacity(0.4),
                blurRadius: 12, offset: const Offset(0, 4),
              )],
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PIATRA Assistant',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                    )),
                // Backend status shown inline below the title
                const SizedBox(height: 3),
                const BackendStatusIndicator(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(bool isDark) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      physics: const BouncingScrollPhysics(),
      itemCount: _messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length) return _buildTypingIndicator(isDark);
        return _buildBubble(_messages[index], isDark, index);
      },
    );
  }

  Widget _buildBubble(ChatMessage message, bool isDark, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Transform.translate(
        offset: Offset(0, 12 * (1 - v)),
        child: Opacity(opacity: v, child: child),
      ),
      child: Align(
        alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          decoration: BoxDecoration(
            gradient: message.isUser ? AppTheme.primaryGradient : null,
            color: message.isUser
                ? null
                : isDark
                    ? AppTheme.cardDark
                    : Colors.white,
            borderRadius: BorderRadius.circular(18).copyWith(
              bottomRight: message.isUser ? const Radius.circular(4) : null,
              bottomLeft: message.isUser ? null : const Radius.circular(4),
            ),
            border: message.isUser
                ? null
                : Border.all(
                    color: isDark
                        ? const Color(0x18FFFFFF)
                        : const Color(0x10000000),
                  ),
            boxShadow: message.isUser
                ? [BoxShadow(
                    color: AppTheme.primaryPurple.withOpacity(0.3),
                    blurRadius: 12, offset: const Offset(0, 4),
                  )]
                : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!message.isUser) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome_rounded,
                        size: 11, color: AppTheme.primaryPurple),
                    const SizedBox(width: 4),
                    const Text('PIATRA',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryPurple,
                          letterSpacing: 0.3,
                        )),
                  ],
                ),
                const SizedBox(height: 5),
              ],
              Text(
                message.text,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: message.isUser
                      ? Colors.white
                      : isDark
                          ? AppTheme.textPrimaryDark
                          : AppTheme.textPrimaryLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator(bool isDark) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(18).copyWith(
            bottomLeft: const Radius.circular(4),
          ),
          border: Border.all(
            color: isDark ? const Color(0x18FFFFFF) : const Color(0x10000000),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DotAnim(color: AppTheme.primaryPurple, delay: 0),
            const SizedBox(width: 5),
            _DotAnim(color: AppTheme.primaryPurple, delay: 150),
            const SizedBox(width: 5),
            _DotAnim(color: AppTheme.primaryPurple, delay: 300),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestions(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _suggestions.map((s) => GestureDetector(
          onTap: () => _sendMessage(s['label'] as String),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: AppTheme.primaryPurple.withOpacity(isDark ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.primaryPurple.withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(s['icon'] as IconData,
                    size: 14, color: AppTheme.primaryPurple),
                const SizedBox(width: 6),
                Text(
                  s['label'] as String,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.primaryPurple,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildInputArea(bool isDark) {
    // Check backend status to decide whether to show a send-blocking banner
    return StreamBuilder<BackendStatus>(
      stream: BackendStatusService.instance.statusStream,
      initialData: BackendStatusService.instance.currentStatus,
      builder: (context, snap) {
        final status = snap.data ?? BackendStatus.idle;
        final isWaking = status == BackendStatus.waking;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Subtle banner only while waking — reminds user AI may be slow
            if (isWaking)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
                color: AppTheme.warningYellow.withOpacity(isDark ? 0.12 : 0.08),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 12, height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.8,
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.warningYellow),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.cloud_sync_rounded, size: 13, color: AppTheme.warningYellow),
                    const SizedBox(width: 6),
                    Text(
                      'Server is waking up — first response may take ~30s',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.warningYellow,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.surfaceDark : Colors.white,
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0x18FFFFFF) : const Color(0x10000000),
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.cardDark : const Color(0xFFF4F3FF),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? const Color(0x18FFFFFF) : const Color(0x10000000),
                          ),
                        ),
                        child: TextField(
                          controller: _messageController,
                          enabled: !_isLoading,
                          decoration: InputDecoration(
                            hintText: isWaking
                                ? 'Type your message (server waking up…)'
                                : 'Ask about cooking…',
                            border: InputBorder.none,
                            filled: false,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            hintStyle: TextStyle(
                              color: isDark
                                  ? AppTheme.textSecondaryDark
                                  : AppTheme.textSecondaryLight,
                            ),
                          ),
                          maxLines: null,
                          textCapitalization: TextCapitalization.sentences,
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    AnimatedBuilder(
                      animation: _inputScale,
                      builder: (_, child) => Transform.scale(
                        scale: _inputScale.value,
                        child: child,
                      ),
                      child: GestureDetector(
                        onTapDown: (_) => _inputCtrl.reverse(),
                        onTapUp: (_) {
                          _inputCtrl.forward();
                          _sendMessage();
                        },
                        onTapCancel: () => _inputCtrl.forward(),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: _isLoading
                                ? LinearGradient(colors: [
                                    Colors.grey.shade600,
                                    Colors.grey.shade700
                                  ])
                                : AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: _isLoading
                                ? []
                                : [
                                    BoxShadow(
                                      color: AppTheme.primaryPurple.withOpacity(0.45),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                          ),
                          child: const Icon(Icons.send_rounded,
                              color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DotAnim extends StatefulWidget {
  final Color color;
  final int delay;
  const _DotAnim({required this.color, required this.delay});

  @override
  State<_DotAnim> createState() => _DotAnimState();
}

class _DotAnimState extends State<_DotAnim>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 550));
    _anim = Tween<double>(begin: 0, end: -5)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    Future.delayed(Duration(milliseconds: widget.delay),
        () { if (mounted) _ctrl.repeat(reverse: true); });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _anim,
        builder: (_, __) => Transform.translate(
          offset: Offset(0, _anim.value),
          child: Container(
            width: 7, height: 7,
            decoration: BoxDecoration(
              color: widget.color, shape: BoxShape.circle,
            ),
          ),
        ),
      );
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  ChatMessage({required this.text, required this.isUser, required this.timestamp});
}