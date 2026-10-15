import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/activity_service.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import '../profile/profile_screen.dart';
import 'add_activity_sheet.dart';
import 'activity_card.dart';
import '../progress/progress_screen.dart';

/// Legacy home screen. Superseded by [ProgressHomeScreen].
/// Retained for reference and backward-compatibility.
@Deprecated('Use ProgressHomeScreen instead')
class HomeScreen extends StatefulWidget {
  final bool previewMode;

  const HomeScreen({super.key, this.previewMode = false});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.previewMode) return;
      context.read<ActivityService>().fetchActivities();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => _showProfileMenu(context),
          ),
          IconButton(
            tooltip: 'Progress history',
            icon: const Icon(Icons.insights_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ProgressScreen(previewMode: widget.previewMode)),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (widget.previewMode) return;
          if (!mounted) return;
          final actService = context.read<ActivityService>();
          actService.checkDayRollover();
          await actService.fetchActivities();
        },
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date and greeting
                _buildDateSection(context),
                const SizedBox(height: 32),

                // Progress card
                Consumer<ActivityService>(
                  builder: (context, activityService, _) {
                    final progress = activityService.dailyProgress;
                    return _buildProgressCard(progress);
                  },
                ),
                const SizedBox(height: 32),

                // Activities section
                Text(
                  'Today\'s Activities',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                Consumer<ActivityService>(
                  builder: (context, activityService, _) {
                    if (activityService.isLoading) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    final activities = activityService.activities;

                    if (activities.isEmpty) {
                      return _buildEmptyState(context);
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: activities.length,
                      itemBuilder: (context, index) {
                        return ActivityCard(activity: activities[index]);
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'ai_button',
            mini: true,
            onPressed: () {
              // TODO: Open AI chat
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('AI assistant coming soon')),
              );
            },
            child: const Icon(Icons.smart_toy_outlined),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'add_button',
            onPressed: () => _showAddActivitySheet(context),
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSection(BuildContext context) {
    final now = DateTime.now();
    final formatter = DateFormat('EEEE\nMMMM d, yyyy');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          formatter.format(now),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressCard(DailyProgress? progress) {
    if (progress == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Today\'s Progress',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              const Center(
                child: CircularProgressIndicator(),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Today\'s Progress',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  '${progress.percentage}%',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress.percentage / 100,
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${progress.completed} of ${progress.total} completed',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 32),
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Nothing to track yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first activity to get started',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => _showAddActivitySheet(context),
            child: const Text('+ Add Activity'),
          ),
        ],
      ),
    );
  }

  void _showAddActivitySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const AddActivitySheet(),
    );
  }

  void _showProfileMenu(BuildContext context) {
    showMenu(
      context: context,
      position: const RelativeRect.fromLTRB(1000, 56, 16, 0),
      items: [
        PopupMenuItem(
          onTap: () {
            Future.microtask(() {
              if (context.mounted) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProfileScreen(previewMode: widget.previewMode),
                  ),
                );
              }
            });
          },
          child: const Row(
            children: [
              Icon(Icons.person_outline, size: 18),
              SizedBox(width: 10),
              Text('Profile & Settings'),
            ],
          ),
        ),
        PopupMenuItem(
          onTap: () async {
            await context.read<AuthService>().logout();
            if (context.mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            }
          },
          child: const Row(
            children: [
              Icon(Icons.logout, size: 18, color: Colors.redAccent),
              SizedBox(width: 10),
              Text('Logout', style: TextStyle(color: Colors.redAccent)),
            ],
          ),
        ),
      ],
    );
  }
}
