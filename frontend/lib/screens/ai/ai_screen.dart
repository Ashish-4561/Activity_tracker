import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/activity_service.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/auth_prompt_dialog.dart';
import '../../widgets/neumorphic_card.dart';

class AiScreen extends StatefulWidget {
  final bool previewMode;

  const AiScreen({super.key, this.previewMode = false});

  @override
  State<AiScreen> createState() => _AiScreenState();
}

class _ChatMessage {
  final String role; // 'user' or 'assistant'
  final String text;
  final List<String>? suggestedActivities;
  final String? suggestedGroup;

  _ChatMessage({
    required this.role,
    required this.text,
    this.suggestedActivities,
    this.suggestedGroup,
  });
}

class _AiScreenState extends State<AiScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [
    _ChatMessage(
      role: 'assistant',
      text: '👋 Hi! I am your AI Habit & Routine Coach.\n\nTell me what goal you want to achieve (e.g., workout routine, exam study schedule, hydration habits, or analyzing your progress), and I will create a tailored plan for you.',
    ),
  ];
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    final authService = context.read<AuthService>();
    if (!widget.previewMode && !authService.isGuest) _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final response = await context.read<ApiService>().getChatHistory(limit: 50);
      final history = (response['messages'] as List? ?? []).map((message) {
        final text = message['message']?.toString() ?? '';
        return _ChatMessage(
          role: message['role']?.toString() ?? 'assistant',
          text: text,
        );
      }).where((m) => m.text.isNotEmpty).toList();
      if (mounted && history.isNotEmpty) {
        setState(() {
          _messages
            ..clear()
            ..addAll(history);
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send([String? quickPrompt]) async {
    final text = (quickPrompt ?? _controller.text).trim();
    if (text.isEmpty || _sending) return;

    final authService = context.read<AuthService>();
    if (authService.isGuest && authService.isTrialExpired) {
      AuthPromptDialog.show(
        context,
        title: 'Trial Expired',
        message: 'Your 2-day guest trial has expired. Create an account or log in to use the AI Assistant.',
      );
      return;
    }

    _controller.clear();

    setState(() {
      _messages.add(_ChatMessage(role: 'user', text: text));
      _sending = true;
    });

    _scrollToBottom();

    final activityService = context.read<ActivityService>();

    try {
      final directAddResponse = _checkDirectAddIntent(text, activityService);
      if (directAddResponse != null) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        if (mounted) {
          setState(() {
            _messages.add(directAddResponse);
          });
        }
        return;
      }

      if (!widget.previewMode && !authService.isGuest) {
        try {
          final response = await context.read<ApiService>().sendChatMessage(
                message: text,
                includeHistory: true,
              );
          final responseText = response['response']?.toString() ?? '';

          final isError = responseText.isEmpty ||
              responseText.contains('quota exceeded') ||
              responseText.contains('rate limit') ||
              responseText.contains('rejected the API key') ||
              responseText.contains('Unable to reach') ||
              responseText.contains('AI provider not configured');

          if (!isError) {
            final suggested = _extractSuggestedActivities(responseText);
            if (mounted) {
              setState(() {
                _messages.add(_ChatMessage(
                  role: 'assistant',
                  text: responseText,
                  suggestedActivities: suggested,
                ));
              });
            }
            await activityService.fetchActivities();
            return;
          }
        } catch (_) {}
      }

      await Future<void>.delayed(const Duration(milliseconds: 400));
      final dynamicResponse = _generateTailoredResponse(text, activityService);
      if (mounted) {
        setState(() {
          _messages.add(dynamicResponse);
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _messages.add(_ChatMessage(
            role: 'assistant',
            text: 'I ran into an issue processing that. Please try asking again.',
          ));
        });
      }
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  _ChatMessage? _checkDirectAddIntent(String prompt, ActivityService service) {
    final lower = prompt.toLowerCase().trim();

    final groupMatch = RegExp(r'^(?:add|create|track)\s+(.+?)\s+(?:to|in|under)\s+(?:group\s+)?(.+)$', caseSensitive: false).firstMatch(lower);
    if (groupMatch != null) {
      final actName = groupMatch.group(1)!.trim();
      final grpName = groupMatch.group(2)!.trim();
      _createActivityQuick(actName, grpName, service);
      return _ChatMessage(
        role: 'assistant',
        text: '✅ **Activity Created!**\n\nI added **"$actName"** to your **"$grpName"** group (daily).\n\nYou can see it on your home screen right now and start logging progress!',
      );
    }

    final simpleAdd = RegExp(r'^(?:add|track|create\s+activity)\s+(.+)$', caseSensitive: false).firstMatch(lower);
    if (simpleAdd != null && !lower.contains('routine') && !lower.contains('plan')) {
      final actName = simpleAdd.group(1)!.trim();
      if (actName.isNotEmpty && actName.length < 50) {
        final group = service.activities.isNotEmpty ? service.activities.first.groupName : 'General';
        _createActivityQuick(actName, group, service);
        return _ChatMessage(
          role: 'assistant',
          text: '✅ **Activity Added!**\n\nI created **"$actName"** in the **"$group"** group.\n\nTap the Dashboard tab anytime to mark it complete!',
        );
      }
    }

    return null;
  }

  void _createActivityQuick(String name, String groupName, ActivityService service, {String icon = '📌'}) {
    String resolvedIcon = icon;
    final l = name.toLowerCase();
    if (l.contains('gym') || l.contains('workout') || l.contains('lift')) {
      resolvedIcon = '🏋️';
    } else if (l.contains('run') || l.contains('jog')) {
      resolvedIcon = '🏃';
    } else if (l.contains('water') || l.contains('drink') || l.contains('hydrate')) {
      resolvedIcon = '💧';
    } else if (l.contains('study') || l.contains('read') || l.contains('book')) {
      resolvedIcon = '📚';
    } else if (l.contains('sleep') || l.contains('rest')) {
      resolvedIcon = '😴';
    } else if (l.contains('meditat') || l.contains('yoga')) {
      resolvedIcon = '🧘';
    } else if (l.contains('code') || l.contains('program')) {
      resolvedIcon = '💻';
    } else if (l.contains('walk')) {
      resolvedIcon = '🚶';
    }

    service.addActivity(
      name: name,
      groupName: groupName,
      icon: resolvedIcon,
      frequency: 'daily',
      frequencyValue: 1,
      frequencyUnit: 'days',
      durationValue: 3,
      durationUnit: 'months',
    );
  }

  List<String> _extractSuggestedActivities(String text) {
    final lines = text.split('\n');
    final result = <String>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('- ') || trimmed.startsWith('* ') || RegExp(r'^\d+\.').hasMatch(trimmed)) {
        final clean = trimmed.replaceFirst(RegExp(r'^(?:[-*]|\d+\.)\s*'), '').trim();
        final nameOnly = clean.split(':').first.replaceAll(RegExp(r'[*_]'), '').trim();
        if (nameOnly.isNotEmpty && nameOnly.length < 30 && !nameOnly.toLowerCase().contains('tip')) {
          result.add(nameOnly);
        }
      }
    }
    return result.take(4).toList();
  }

  _ChatMessage _generateTailoredResponse(String prompt, ActivityService service) {
    final lower = prompt.toLowerCase();

    if (lower.contains('workout') || lower.contains('gym') || lower.contains('fitness') || lower.contains('exercise')) {
      return _ChatMessage(
        role: 'assistant',
        text: '🏋️ **Personalized Fitness Routine**\n\nHere is a balanced routine designed to build consistent athletic performance:\n\n1. **Strength Training**: 45 mins of targeted compound lifts\n2. **Cardio & Mobility**: 20 mins brisk walk or light jog\n3. **Post-Workout Recovery**: 10 mins stretching & hydration\n\nTap the button below to add these activities directly into a **"Fitness"** group!',
        suggestedActivities: ['Strength Training', 'Cardio & Mobility', 'Recovery Stretching'],
        suggestedGroup: 'Fitness',
      );
    }

    if (lower.contains('study') || lower.contains('exam') || lower.contains('learn') || lower.contains('read')) {
      return _ChatMessage(
        role: 'assistant',
        text: '📚 **Productive Deep-Work & Study Plan**\n\nHere is an optimal study schedule based on the Pomodoro technique:\n\n1. **Deep Focus Session 1**: 50 mins core learning\n2. **Review & Flashcards**: 25 mins active recall\n3. **Subject Reading**: 30 mins chapter breakdown\n\nTap below to add these directly to your **"Studies"** group!',
        suggestedActivities: ['Deep Focus Session', 'Active Recall Review', 'Reading & Notes'],
        suggestedGroup: 'Studies',
      );
    }

    if (lower.contains('progress') || lower.contains('review') || lower.contains('stat') || lower.contains('streak')) {
      final count = service.activities.length;
      final completed = service.activities.where((a) => a.isCompleted).length;
      final streak = service.overallCurrentStreak;

      return _ChatMessage(
        role: 'assistant',
        text: '📊 **Progress Snapshot**\n\n- Total active habits: **$count**\n- Completed today: **$completed**\n- Active overall streak: **$streak days 🔥**\n\nKeep maintaining your consistency. Tapping the **Analytics** tab will show your full historical date matrix!',
      );
    }

    return _ChatMessage(
      role: 'assistant',
      text: '✨ **Custom Daily Plan**\n\nBased on your goal, here are 3 habits to help you build momentum:\n\n1. **Morning Focus**: 20 mins uninterrupted start\n2. **Daily Action**: Primary priority task\n3. **Evening Reflection**: 5 mins day review\n\nTap below to attach them to your routine!',
      suggestedActivities: ['Morning Focus', 'Daily Action Task', 'Evening Reflection'],
      suggestedGroup: 'Daily Habits',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activityService = context.watch<ActivityService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Routine Coach', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Clear Chat',
            icon: const Icon(Icons.cleaning_services_rounded),
            onPressed: () {
              setState(() {
                _messages
                  ..clear()
                  ..add(_ChatMessage(
                    role: 'assistant',
                    text: 'Chat cleared! Tell me what routine or habit plan you would like to create.',
                  ));
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              children: [
                // Top Banner Card
                NeumorphicCard(
                  padding: const EdgeInsets.all(16),
                  borderRadius: 18,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primaryGradientStart, AppColors.primaryGradientEnd],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Smart Habit & Routine Architect',
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Generate workouts, study schedules, and habit routines automatically.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Chat Messages
                ..._messages.map((m) => _buildMessageBubble(context, isDark, m, activityService)),

                if (_sending)
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 12),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Designing your custom plan…',
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 14),

                // Quick Suggestions
                Row(
                  children: [
                    const Icon(Icons.lightbulb_outline_rounded, size: 14, color: AppColors.amberFlame),
                    const SizedBox(width: 6),
                    Text(
                      'Quick Prompts',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    (title: 'Build me a workout routine', icon: Icons.fitness_center_rounded),
                    (title: 'Help me create a study plan', icon: Icons.menu_book_rounded),
                    (title: 'Analyze my progress', icon: Icons.insights_rounded),
                    (title: 'Daily hydration habit', icon: Icons.water_drop_rounded),
                  ].map((p) {
                    return ActionChip(
                      avatar: Icon(p.icon, size: 16, color: AppColors.primary),
                      label: Text(p.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                      backgroundColor: isDark ? AppColors.darkSurfaceRaised : const Color(0xFFF1F5F9),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      ),
                      onPressed: _sending ? null : () => _send(p.title),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          // Bottom Input Bar
          SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                border: Border(
                  top: BorderSide(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Focus(
                      onKeyEvent: (node, event) {
                        if (event is KeyDownEvent &&
                            event.logicalKey == LogicalKeyboardKey.enter &&
                            !HardwareKeyboard.instance.isShiftPressed) {
                          _send();
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      },
                      child: TextField(
                        controller: _controller,
                        maxLines: 4,
                        minLines: 1,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          hintText: 'Ask anything (e.g. 3-day workout, exam prep, add gym)...',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                          filled: true,
                          fillColor: isDark ? AppColors.darkSurfaceRaised : const Color(0xFFF8FAFC),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: IconButton(
                      tooltip: 'Send message',
                      onPressed: _sending ? null : () => _send(),
                      icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
    BuildContext context,
    bool isDark,
    _ChatMessage message,
    ActivityService activityService,
  ) {
    final isUser = message.role == 'user';

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        constraints: const BoxConstraints(maxWidth: 580),
        child: Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: isUser
                    ? AppColors.primary
                    : (isDark ? AppColors.darkSurfaceRaised : const Color(0xFFF8FAFC)),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
                border: Border.all(
                  color: isUser
                      ? AppColors.primary
                      : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SelectableText(
                message.text,
                style: TextStyle(
                  color: isUser
                      ? Colors.white
                      : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
            ),

            if (!isUser && message.suggestedActivities != null && message.suggestedActivities!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: message.suggestedActivities!.map((actName) {
                  return ActionChip(
                    avatar: const Icon(Icons.add_circle_outline_rounded, size: 16, color: AppColors.primary),
                    label: Text('+ Add "$actName"', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    backgroundColor: isDark ? AppColors.darkSurfaceRaised : const Color(0xFFEEF2FF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    onPressed: () {
                      final group = message.suggestedGroup ?? 'Daily Habits';
                      _createActivityQuick(actName, group, activityService);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Added "$actName" to "$group" group!'),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
