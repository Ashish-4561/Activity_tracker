import { Response } from 'express';
import { getDatabase } from '../config/database';
import { getCurrentDate } from '../utils/auth';
import { AuthRequest } from '../middleware/auth';
import { Activity, ActivityCompletion, ProgressData, StreakData } from '../models/types';

function formatDateString(val: unknown, fallback: string = new Date().toISOString().split('T')[0]): string {
  if (!val) return fallback;
  if (val instanceof Date) {
    if (isNaN(val.getTime())) return fallback;
    return val.toISOString().split('T')[0];
  }
  if (typeof val === 'string') {
    const trimmed = val.trim();
    if (/^\d{4}-\d{2}-\d{2}$/.test(trimmed)) return trimmed;
    const match = trimmed.match(/^(\d{4}-\d{2}-\d{2})/);
    if (match) return match[1];
    const parsed = new Date(trimmed);
    if (!isNaN(parsed.getTime())) return parsed.toISOString().split('T')[0];
  }
  return fallback;
}

function isCompletedValue(val: unknown): boolean {
  return val === true || val === 1 || val === 'true' || val === '1';
}

function parseDate(value: unknown, fallback: Date): string {
  return formatDateString(value, fallback.toISOString().split('T')[0]);
}

function addDays(date: unknown, amount: number): string {
  const cleanDate = formatDateString(date);
  const value = new Date(`${cleanDate}T00:00:00Z`);
  if (isNaN(value.getTime())) return cleanDate;
  value.setUTCDate(value.getUTCDate() + (Number.isFinite(amount) ? amount : 0));
  return value.toISOString().split('T')[0];
}

function addInterval(date: unknown, amount: number, unit: string): string {
  const cleanDate = formatDateString(date);
  const value = new Date(`${cleanDate}T00:00:00Z`);
  if (isNaN(value.getTime())) return cleanDate;
  const safeAmount = Number.isFinite(amount) && amount > 0 ? amount : 1;
  if (unit === 'months') {
    value.setUTCMonth(value.getUTCMonth() + safeAmount);
  } else {
    value.setUTCDate(value.getUTCDate() + safeAmount * (unit === 'weeks' ? 7 : 1));
  }
  return value.toISOString().split('T')[0];
}

function isScheduled(activity: any, date: string): boolean {
  if (!activity) return false;
  const targetDate = formatDateString(date);
  const rawStart = activity.start_date || activity.created_at;
  const start = formatDateString(rawStart, targetDate);

  if (targetDate < start) return false;

  // Daily activities are always scheduled
  if (activity.frequency === 'daily' || (!activity.frequency && !activity.frequency_value)) {
    return true;
  }

  const durationVal = Math.max(1, Number(activity.duration_value) || 12);
  const durationUnit = activity.duration_unit || 'months';
  const end = addInterval(start, durationVal, durationUnit);
  if (targetDate >= end) return false;

  const interval = Math.max(1, Number(activity.frequency_value) || 1);
  const unit = activity.frequency_unit || (activity.frequency === 'weekly' ? 'weeks' : 'days');

  if (unit === 'days' && interval === 1) return true;

  let occurrence = start;
  let safetyCounter = 0;
  while (occurrence < targetDate && safetyCounter < 1000) {
    occurrence = addInterval(occurrence, interval, unit);
    safetyCounter++;
  }
  return occurrence === targetDate;
}

export async function getRangeProgress(req: AuthRequest, res: Response): Promise<void> {
  try {
    if (!req.userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const today = new Date();
    const defaultFrom = new Date(today);
    defaultFrom.setDate(today.getDate() - 6);
    const from = parseDate(req.query.from, defaultFrom);
    const to = parseDate(req.query.to, today);
    const group = typeof req.query.group === 'string' ? req.query.group : null;
    const activityId = typeof req.query.activity_id === 'string' ? req.query.activity_id : null;
    const db = await getDatabase();

    const activityFilters = ['a.user_id = ?', 'a.is_active = 1'];
    const activityParams: any[] = [req.userId];
    if (group && group !== 'All Groups') {
      activityFilters.push('a.group_name = ?');
      activityParams.push(group);
    }
    if (activityId && activityId !== 'All Activities') {
      activityFilters.push('a.id = ?');
      activityParams.push(activityId);
    }

    const activities = await db.all<any[]>(
      `SELECT a.id, a.name, a.icon, a.group_name, a.start_date, a.frequency_value, a.frequency_unit, a.duration_value, a.duration_unit, a.frequency
       FROM activities a WHERE ${activityFilters.join(' AND ')}`,
      activityParams,
    );
    const rawCompletions = await db.all<any[]>(
      `SELECT ac.activity_id, ac.date, ac.completed, ac.completed_at,
              a.name, a.icon, a.group_name
       FROM activity_completions ac
       JOIN activities a ON a.id = ac.activity_id
       WHERE ac.user_id = ? AND ac.date BETWEEN ? AND ?
         AND ${activityFilters.slice(1).join(' AND ')}`,
      [req.userId, from, to, ...activityParams.slice(1)],
    );

    const completions = (rawCompletions || []).map(c => ({
      ...c,
      date: formatDateString(c.date),
      completed: isCompletedValue(c.completed),
    }));

    const completionMap = new Map<string, any>();
    completions.forEach(completion => completionMap.set(`${completion.activity_id}:${completion.date}`, completion));
    const daily: any[] = [];
    let cursor = from;
    while (cursor <= to) {
      const scheduled = activities.filter(activity => {
        const isActCompleted = isCompletedValue(completionMap.get(`${activity.id}:${cursor}`)?.completed);
        return isActCompleted || isScheduled(activity, cursor);
      });
      const completed = scheduled.filter(activity => isCompletedValue(completionMap.get(`${activity.id}:${cursor}`)?.completed)).length;
      const total = scheduled.length;
      daily.push({
        date: cursor,
        day: new Date(`${cursor}T00:00:00Z`).toLocaleDateString('en-US', { weekday: 'short' }),
        completed,
        total,
        percentage: total ? Math.round((completed / total) * 100) : 0,
      });
      cursor = addDays(cursor, 1);
    }

    const totalCompleted = daily.reduce((sum, day) => sum + day.completed, 0);
    const totalScheduled = daily.reduce((sum, day) => sum + day.total, 0);
    const completedDates = new Set(daily.filter(day => day.completed > 0).map(day => day.date));
    let bestStreak = 0;
    let running = 0;
    for (const day of daily) {
      if (day.completed > 0) running += 1;
      else running = 0;
      bestStreak = Math.max(bestStreak, running);
    }
    let currentStreak = 0;
    for (let index = daily.length - 1; index >= 0 && completedDates.has(daily[index].date); index -= 1) currentStreak += 1;

    const groupMap = new Map<string, { completed: number; total: number }>();
    activities.forEach(activity => groupMap.set(activity.group_name, { completed: 0, total: 0 }));
    daily.forEach(day => activities.filter(activity => isCompletedValue(completionMap.get(`${activity.id}:${day.date}`)?.completed) || isScheduled(activity, day.date)).forEach(activity => {
      const entry = groupMap.get(activity.group_name)!;
      entry.total += 1;
      if (isCompletedValue(completionMap.get(`${activity.id}:${day.date}`)?.completed)) entry.completed += 1;
    }));

    const activityHistory = activities.map(activity => {
      const activityDaily = daily.map(day => isCompletedValue(completionMap.get(`${activity.id}:${day.date}`)?.completed));
      const scheduledDays = daily.filter(day => isCompletedValue(completionMap.get(`${activity.id}:${day.date}`)?.completed) || isScheduled(activity, day.date)).length;
      const completedDays = activityDaily.filter(Boolean).length;
      return {
        id: activity.id,
        name: activity.name,
        icon: activity.icon,
        group_name: activity.group_name,
        completed: completedDays,
        total: scheduledDays,
        percentage: scheduledDays ? Math.round((completedDays / scheduledDays) * 100) : 0,
        history: activityDaily,
      };
    });

    res.json({
      from,
      to,
      completed: totalCompleted,
      total: totalScheduled,
      percentage: totalScheduled ? Math.round((totalCompleted / totalScheduled) * 100) : 0,
      average_daily_percentage: daily.length ? Math.round(daily.reduce((sum, day) => sum + day.percentage, 0) / daily.length) : 0,
      best_day: daily.reduce((best, day) => day.percentage > best.percentage ? day : best, daily[0] || { date: null, percentage: 0 }),
      worst_day: daily.reduce((worst, day) => day.percentage < worst.percentage ? day : worst, daily[0] || { date: null, percentage: 0 }),
      current_streak: currentStreak,
      best_streak: bestStreak,
      daily_progress: daily,
      groups: Array.from(groupMap.entries()).map(([name, value]) => ({ name, ...value, percentage: value.total ? Math.round((value.completed / value.total) * 100) : 0 })),
      activities: activityHistory,
      raw_activities: activities,
      completion_history: completions,
    });
  } catch (error: any) {
    console.error('Get range progress error:', error);
    res.status(500).json({ error: 'Failed to get historical progress' });
  }
}

export async function getDailyProgress(req: AuthRequest, res: Response): Promise<void> {
  try {
    if (!req.userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const { date } = req.query;
    const targetDate = formatDateString(date, getCurrentDate());

    const db = await getDatabase();

    // Get all activities for the user that should be tracked on this date
    const activities = await db.all<Activity[]>(
      `SELECT * FROM activities WHERE user_id = ? AND is_active = 1`,
      [req.userId]
    );

    if (!activities || activities.length === 0) {
      res.json({
        date: targetDate,
        completed: 0,
        total: 0,
        percentage: 0,
        activities: [],
      });
      return;
    }

    // Get completions for this date
    const completions = await db.all<ActivityCompletion[]>(
      `SELECT * FROM activity_completions WHERE user_id = ? AND date = ?`,
      [req.userId, targetDate]
    );

    const completionMap = new Map<string, boolean>();
    completions?.forEach(c => {
      completionMap.set(c.activity_id, isCompletedValue(c.completed));
    });

    // Count completed activities
    let completed = 0;
    const scheduledActivities = activities.filter(activity => isScheduled(activity, targetDate));
    const activityDetails = scheduledActivities.map(activity => {
      const isCompleted = completionMap.get(activity.id) || false;
      if (isCompleted) completed++;
      return {
        id: activity.id,
        name: activity.name,
        icon: activity.icon,
        frequency: activity.frequency,
        completed: isCompleted,
      };
    });

    const total = scheduledActivities.length;
    const percentage = total > 0 ? Math.round((completed / total) * 100) : 0;

    res.json({
      date: targetDate,
      completed,
      total,
      percentage,
      activities: activityDetails,
    });
  } catch (error: any) {
    console.error('Get daily progress error:', error);
    res.status(500).json({ error: 'Failed to get daily progress' });
  }
}

export async function getWeeklyProgress(req: AuthRequest, res: Response): Promise<void> {
  try {
    if (!req.userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const db = await getDatabase();

    // Get target date (defaults to today) and calculate Monday of that week in UTC
    const targetDateStr = formatDateString(req.query.date, new Date().toISOString().split('T')[0]);
    const [year, month, day] = targetDateStr.split('-').map(Number);
    const targetDate = new Date(Date.UTC(year, month - 1, day));
    const dayOfWeek = targetDate.getUTCDay(); // 0 is Sunday, 1 is Monday...
    const diffToMonday = dayOfWeek === 0 ? -6 : 1 - dayOfWeek;
    const mondayDate = new Date(Date.UTC(year, month - 1, day + diffToMonday));
    const weekStart = mondayDate.toISOString().split('T')[0];

    // Get end of week (Sunday)
    const sundayDate = new Date(Date.UTC(mondayDate.getUTCFullYear(), mondayDate.getUTCMonth(), mondayDate.getUTCDate() + 6));
    const weekEnd = sundayDate.toISOString().split('T')[0];

    // Get activities
    const activities = await db.all<Activity[]>(
      `SELECT * FROM activities WHERE user_id = ? AND is_active = 1`,
      [req.userId]
    );

    if (!activities || activities.length === 0) {
      res.json({
        week_start: weekStart,
        week_end: weekEnd,
        completed: 0,
        total: 0,
        percentage: 0,
        daily_progress: [],
      });
      return;
    }

    // Get completions for the week
    const completions = await db.all<ActivityCompletion[]>(
      `SELECT * FROM activity_completions WHERE user_id = ? AND date BETWEEN ? AND ?`,
      [req.userId, weekStart, weekEnd]
    );

    const completionMap = new Map<string, boolean>();
    completions?.forEach(c => {
      completionMap.set(`${c.activity_id}:${c.date}`, isCompletedValue(c.completed));
    });

    // Calculate daily progress
    const daysOfWeek = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const dailyProgress = [];
    let totalCompleted = 0;
    let totalExpected = 0;

    for (let i = 0; i < 7; i++) {
      const currentDate = new Date(Date.UTC(mondayDate.getUTCFullYear(), mondayDate.getUTCMonth(), mondayDate.getUTCDate() + i));
      const dateStr = currentDate.toISOString().split('T')[0];

      let dayCompleted = 0;
      activities.filter(activity => isScheduled(activity, dateStr)).forEach(activity => {
        const isCompleted = completionMap.get(`${activity.id}:${dateStr}`) || false;
        if (isCompleted) dayCompleted++;
      });

      const dayTotal = activities.filter(activity => isScheduled(activity, dateStr)).length;
      const dayPercentage = dayTotal > 0 ? Math.round((dayCompleted / dayTotal) * 100) : 0;

      dailyProgress.push({
        date: dateStr,
        day: daysOfWeek[i],
        completed: dayCompleted,
        total: dayTotal,
        percentage: dayPercentage,
      });

      totalCompleted += dayCompleted;
      totalExpected += dayTotal;
    }

    const weeklyPercentage = totalExpected > 0 ? Math.round((totalCompleted / totalExpected) * 100) : 0;

    res.json({
      week_start: weekStart,
      week_end: weekEnd,
      completed: totalCompleted,
      total: totalExpected,
      percentage: weeklyPercentage,
      daily_progress: dailyProgress,
    });
  } catch (error: any) {
    console.error('Get weekly progress error:', error);
    res.status(500).json({ error: 'Failed to get weekly progress' });
  }
}

export async function getMonthlyProgress(req: AuthRequest, res: Response): Promise<void> {
  try {
    if (!req.userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const { month, year } = req.query;

    const db = await getDatabase();

    // Get current month/year if not specified
    const today = new Date();
    const targetMonth = month ? parseInt(month as string) : today.getMonth() + 1;
    const targetYear = year ? parseInt(year as string) : today.getFullYear();

    const monthStart = `${targetYear}-${String(targetMonth).padStart(2, '0')}-01`;
    const lastDay = new Date(targetYear, targetMonth, 0).getDate();
    const monthEnd = `${targetYear}-${String(targetMonth).padStart(2, '0')}-${String(lastDay).padStart(2, '0')}`;

    // Get activities
    const activities = await db.all<Activity[]>(
      `SELECT * FROM activities WHERE user_id = ? AND is_active = 1`,
      [req.userId]
    );

    if (!activities || activities.length === 0) {
      res.json({
        month: targetMonth,
        year: targetYear,
        month_start: monthStart,
        month_end: monthEnd,
        completed: 0,
        total: 0,
        percentage: 0,
        activity_stats: [],
      });
      return;
    }

    // Get completions for the month
    const completions = await db.all<ActivityCompletion[]>(
      `SELECT * FROM activity_completions WHERE user_id = ? AND date BETWEEN ? AND ?`,
      [req.userId, monthStart, monthEnd]
    );

    // Calculate activity-specific stats
    const activityStats = activities.map(activity => {
      const activityCompletions = completions?.filter(c => c.activity_id === activity.id) || [];
      const completedDays = activityCompletions.filter(c => isCompletedValue(c.completed)).length;
      const trackedDays = activityCompletions.length;

      return {
        id: activity.id,
        name: activity.name,
        icon: activity.icon,
        completed_days: completedDays,
        tracked_days: trackedDays,
        completion_rate: trackedDays > 0 ? Math.round((completedDays / trackedDays) * 100) : 0,
      };
    });

    // Overall stats
    const totalCompleted = completions?.filter(c => isCompletedValue(c.completed)).length || 0;
    const totalTracked = completions?.length || 0;
    const percentage = totalTracked > 0 ? Math.round((totalCompleted / totalTracked) * 100) : 0;

    res.json({
      month: targetMonth,
      year: targetYear,
      month_start: monthStart,
      month_end: monthEnd,
      completed: totalCompleted,
      total: totalTracked,
      percentage,
      activity_stats: activityStats,
    });
  } catch (error: any) {
    console.error('Get monthly progress error:', error);
    res.status(500).json({ error: 'Failed to get monthly progress' });
  }
}

export async function getStreakData(req: AuthRequest, res: Response): Promise<void> {
  try {
    if (!req.userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const { activity_id } = req.query;

    const db = await getDatabase();

    let query = `
      SELECT date, completed FROM activity_completions 
      WHERE user_id = ?
    `;
    const params: any[] = [req.userId];

    if (activity_id) {
      query += ` AND activity_id = ?`;
      params.push(activity_id);
    }

    query += ` ORDER BY date DESC`;

    const completions = await db.all<ActivityCompletion[]>(query, params);

    if (!completions || completions.length === 0) {
      res.json({
        current_streak: 0,
        best_streak: 0,
        last_completed_date: null,
      });
      return;
    }

    // Calculate current streak (consecutive completed days)
    let currentStreak = 0;
    let bestStreak = 0;

    const today = new Date();
    let expectedDate = new Date(today);

    for (const completion of completions) {
      const completionDateStr = formatDateString(completion.date);
      const completionDate = new Date(`${completionDateStr}T00:00:00Z`);

      if (isCompletedValue(completion.completed)) {
        // Check if this is consecutive with the expected date
        if (
          expectedDate.getUTCFullYear() === completionDate.getUTCFullYear() &&
          expectedDate.getUTCMonth() === completionDate.getUTCMonth() &&
          expectedDate.getUTCDate() === completionDate.getUTCDate()
        ) {
          currentStreak++;
          bestStreak = Math.max(bestStreak, currentStreak);
          expectedDate.setUTCDate(expectedDate.getUTCDate() - 1);
        } else if (
          expectedDate < completionDate ||
          (expectedDate.getTime() - completionDate.getTime()) > 86400000
        ) {
          // Gap found, reset current streak
          currentStreak = 1;
          bestStreak = Math.max(bestStreak, currentStreak);
          expectedDate = new Date(completionDate);
          expectedDate.setUTCDate(completionDate.getUTCDate() - 1);
        }
      } else {
        expectedDate = new Date(completionDate);
        expectedDate.setUTCDate(expectedDate.getUTCDate() - 1);
      }
    }

    const lastCompletedCompletion = completions.find(c => isCompletedValue(c.completed));

    res.json({
      current_streak: currentStreak,
      best_streak: bestStreak,
      last_completed_date: lastCompletedCompletion?.date ? formatDateString(lastCompletedCompletion.date) : null,
    });
  } catch (error: any) {
    console.error('Get streak data error:', error);
    res.status(500).json({ error: 'Failed to get streak data' });
  }
}
