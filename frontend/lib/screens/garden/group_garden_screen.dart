import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/garden.dart';
import '../../services/activity_service.dart';
import '../../services/garden_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/neumorphic_card.dart';

class GroupGardenScreen extends StatefulWidget {
  final String groupName;
  final String? groupId;

  const GroupGardenScreen({
    super.key,
    required this.groupName,
    this.groupId,
  });

  @override
  State<GroupGardenScreen> createState() => _GroupGardenScreenState();
}

class _GroupGardenScreenState extends State<GroupGardenScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GardenService>().ensureGardenForGroup(widget.groupName);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Consumer2<GardenService, ActivityService>(
      builder: (context, gardenService, activityService, _) {
        final garden = gardenService.getGardenForGroup(widget.groupId ?? widget.groupName);

        // Group-specific activity count
        final groupActivities = activityService.activities
            .where((a) => a.groupName.trim().toLowerCase() == widget.groupName.trim().toLowerCase())
            .toList();
        final completedActivitiesCount = garden?.activitiesCompletedCount ??
            groupActivities.where((a) => a.isCompleted).length;

        final streak = garden?.currentStreak ?? activityService.groupStreak(widget.groupName);
        final bestStreak = garden?.bestStreak ?? activityService.groupBestStreak(widget.groupName);

        return Scaffold(
          appBar: AppBar(
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor: theme.scaffoldBackgroundColor,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🌸 ', style: TextStyle(fontSize: 18)),
                    Flexible(
                      child: Text(
                        '${widget.groupName} Garden',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Text(
                  garden?.levelName ?? 'Sprout Haven',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Refresh Garden',
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () => gardenService.fetchGardens(),
              ),
            ],
          ),
          body: gardenService.isLoading && garden == null
              ? const Center(child: CircularProgressIndicator())
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
                      children: [
                        // ── Hero Section: Level, Points & Progress ─────────────────
                        _buildGardenHero(context, garden, isDark),
                        const SizedBox(height: 18),

                        // ── Interactive Garden Landscape Plot ──────────────────────
                        _buildGardenVisualPlot(context, garden, isDark),
                        const SizedBox(height: 18),

                        // ── Group-Specific Statistics Cards ────────────────────────
                        _buildGroupStats(
                          context,
                          completedCount: completedActivitiesCount,
                          currentStreak: streak,
                          bestStreak: bestStreak,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 20),

                        // ── Tab Bar: Plants & Milestones ───────────────────────────
                        Container(
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurfaceRaised : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                            ),
                          ),
                          child: TabBar(
                            controller: _tabController,
                            indicatorSize: TabBarIndicatorSize.tab,
                            dividerColor: Colors.transparent,
                            indicator: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            labelColor: Colors.white,
                            unselectedLabelColor: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                            tabs: [
                              Tab(
                                text: 'Plants (${garden?.onlyUnlockedPlants.length ?? 0}/${garden?.unlockedPlants.length ?? 0})',
                              ),
                              Tab(
                                text: 'Milestones (${garden?.onlyAchievedMilestones.length ?? 0}/${garden?.milestones.length ?? 0})',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── Tab Views ──────────────────────────────────────────────
                        AnimatedBuilder(
                          animation: _tabController,
                          builder: (context, _) {
                            if (_tabController.index == 0) {
                              return _buildPlantsGrid(context, garden, isDark);
                            } else {
                              return _buildMilestonesList(context, garden, isDark);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  // ── Garden Hero Header Card ───────────────────────────────────────────────
  Widget _buildGardenHero(BuildContext context, GroupGarden? garden, bool isDark) {
    final theme = Theme.of(context);
    final level = garden?.level ?? 1;
    final levelName = garden?.levelName ?? 'Sprout Haven';
    final points = garden?.growthPoints ?? 0;
    final progressPct = garden?.levelProgressPercentage ?? 0;
    final nextPoints = garden?.nextLevelPoints ?? 50;
    final ptsNeeded = (nextPoints - points) > 0 ? (nextPoints - points) : 0;

    return NeumorphicCard(
      padding: const EdgeInsets.all(20),
      borderRadius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.emeraldSuccess,
                          AppColors.emeraldSuccess.withValues(alpha: 0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.emeraldSuccess.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        'Lv.$level',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        levelName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$points Growth Points (GP)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.eco_rounded, size: 14, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      '$progressPct%',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Progress Bar towards Next Level
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (progressPct / 100.0).clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.emeraldSuccess),
            ),
          ),
          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                level >= 10
                    ? 'Maximum Level Achieved! 👑'
                    : '$ptsNeeded GP needed for Level ${level + 1}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
              Text(
                '$points / $nextPoints GP',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Visual Landscape Garden Plot ──────────────────────────────────────────
  Widget _buildGardenVisualPlot(BuildContext context, GroupGarden? garden, bool isDark) {
    final unlocked = garden?.onlyUnlockedPlants ?? [];

    return Container(
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [
                  const Color(0xFF131A2A),
                  const Color(0xFF0F172A),
                  const Color(0xFF1E293B),
                ]
              : [
                  const Color(0xFFE0F2FE),
                  const Color(0xFFBAE6FD),
                  const Color(0xFFDCFCE7),
                ],
        ),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x60000000) : const Color(0x150F172A),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Sky decor (ambient clouds/sun or stars/moon)
          Positioned(
            top: 14,
            left: 20,
            child: Row(
              children: [
                Text(
                  isDark ? '🌙' : '☀️',
                  style: const TextStyle(fontSize: 22),
                ),
                const SizedBox(width: 8),
                Text(
                  isDark ? '✨ Starlight Sanctuary' : '🌤️ Sunlit Garden',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white70 : const Color(0xFF0369A1),
                  ),
                ),
              ],
            ),
          ),

          // Ground soil / grass bed layer
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 70,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? [
                          const Color(0xFF1E3A2F),
                          const Color(0xFF142921),
                        ]
                      : [
                          const Color(0xFF86EFAC),
                          const Color(0xFF4ADE80),
                        ],
                ),
              ),
            ),
          ),

          // Render Plants in Garden
          if (unlocked.isEmpty)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🌱', style: TextStyle(fontSize: 40)),
                  const SizedBox(height: 8),
                  Text(
                    'No plants sprouted yet',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: isDark ? Colors.white70 : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Complete habits in "${widget.groupName}" to grow your garden!',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            Positioned(
              bottom: 25,
              left: 14,
              right: 14,
              child: SizedBox(
                height: 110,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: unlocked.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (context, index) {
                    final plant = unlocked[index];
                    return _buildGardenPlantItem(context, plant, isDark);
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGardenPlantItem(BuildContext context, GardenPlant plant, bool isDark) {
    return GestureDetector(
      onTap: () => _showPlantDetailSheet(context, plant),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceRaised.withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _rarityColor(plant.rarity).withValues(alpha: 0.6),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: _rarityColor(plant.rarity).withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Text(
                plant.emoji,
                style: const TextStyle(fontSize: 32),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isDark ? Colors.black54 : Colors.white70,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              plant.name,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ── Group-Specific Statistics Cards ───────────────────────────────────────
  Widget _buildGroupStats(
    BuildContext context, {
    required int completedCount,
    required int currentStreak,
    required int bestStreak,
    required bool isDark,
  }) {
    return Row(
      children: [
        Expanded(
          child: _buildStatItem(
            context,
            icon: Icons.check_circle_rounded,
            iconColor: AppColors.emeraldSuccess,
            value: '$completedCount',
            label: 'Habits Done',
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatItem(
            context,
            icon: Icons.local_fire_department_rounded,
            iconColor: const Color(0xFFF97316),
            value: '$currentStreak d',
            label: 'Current Streak',
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatItem(
            context,
            icon: Icons.emoji_events_rounded,
            iconColor: const Color(0xFFEAB308),
            value: '$bestStreak d',
            label: 'Best Streak',
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
    required bool isDark,
  }) {
    return NeumorphicCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      borderRadius: 18,
      child: Column(
        children: [
          Icon(icon, size: 22, color: iconColor),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ── Plants Tab: Collection Grid ───────────────────────────────────────────
  Widget _buildPlantsGrid(BuildContext context, GroupGarden? garden, bool isDark) {
    final plants = garden?.unlockedPlants ?? [];
    if (plants.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text('No plant collection available.')),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: plants.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.15,
      ),
      itemBuilder: (context, index) {
        final plant = plants[index];
        final isUnlocked = plant.unlocked;

        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _showPlantDetailSheet(context, plant),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isUnlocked
                  ? (isDark ? AppColors.darkSurfaceRaised : Colors.white)
                  : (isDark ? const Color(0xFF131722) : const Color(0xFFF1F5F9)),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isUnlocked
                    ? _rarityColor(plant.rarity).withValues(alpha: 0.4)
                    : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                width: isUnlocked ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      plant.emoji,
                      style: TextStyle(
                        fontSize: 28,
                        color: isUnlocked ? null : Colors.grey,
                      ),
                    ),
                    if (isUnlocked)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _rarityColor(plant.rarity).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          plant.rarity.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: _rarityColor(plant.rarity),
                          ),
                        ),
                      )
                    else
                      const Icon(Icons.lock_rounded, size: 16, color: Colors.grey),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plant.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: isUnlocked
                            ? null
                            : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isUnlocked ? 'Unlocked at Lv.${plant.levelRequired}' : 'Requires Lv.${plant.levelRequired}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isUnlocked
                            ? AppColors.emeraldSuccess
                            : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Milestones Tab ────────────────────────────────────────────────────────
  Widget _buildMilestonesList(BuildContext context, GroupGarden? garden, bool isDark) {
    final milestones = garden?.milestones ?? [];
    if (milestones.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text('No milestones available.')),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: milestones.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final ms = milestones[index];
        final achieved = ms.achieved;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: achieved
                ? (isDark
                    ? AppColors.emeraldSuccess.withValues(alpha: 0.1)
                    : const Color(0xFFF0FDF4))
                : (isDark ? AppColors.darkSurfaceRaised : const Color(0xFFF8FAFC)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: achieved
                  ? AppColors.emeraldSuccess.withValues(alpha: 0.4)
                  : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: achieved
                      ? AppColors.emeraldSuccess.withValues(alpha: 0.18)
                      : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    ms.badge,
                    style: TextStyle(
                      fontSize: 22,
                      color: achieved ? null : Colors.grey,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ms.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: achieved ? null : (isDark ? Colors.grey : Colors.grey[700]),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ms.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (achieved)
                const Icon(Icons.check_circle_rounded, color: AppColors.emeraldSuccess, size: 22)
              else
                Icon(Icons.radio_button_unchecked_rounded, color: isDark ? Colors.grey[700] : Colors.grey[400], size: 20),
            ],
          ),
        );
      },
    );
  }

  void _showPlantDetailSheet(BuildContext context, GardenPlant plant) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceRaised : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: _rarityColor(plant.rarity).withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(plant.emoji, style: const TextStyle(fontSize: 34)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plant.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _rarityColor(plant.rarity).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                plant.rarity.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: _rarityColor(plant.rarity),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              plant.unlocked ? 'Unlocked • Lv.${plant.levelRequired}' : 'Requires Lv.${plant.levelRequired}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: plant.unlocked ? AppColors.emeraldSuccess : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(),
              const SizedBox(height: 12),
              Text(
                plant.description,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _rarityColor(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'rare':
        return const Color(0xFF3B82F6);
      case 'epic':
        return const Color(0xFFA855F7);
      case 'legendary':
        return const Color(0xFFEAB308);
      default:
        return AppColors.emeraldSuccess;
    }
  }
}
