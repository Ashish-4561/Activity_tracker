export interface User {
  id: string;
  auth_user_id?: string;
  name: string;
  email?: string;
  phone?: string;
  password_hash?: string;
  profile_image?: string;
  auth_provider?: 'email' | 'google' | 'phone';
  theme: string;
  ai_enabled: boolean;
  ai_suggestions_enabled: boolean;
  notifications_enabled: boolean;
  created_at: string;
  updated_at: string;
}

export interface Activity {
  id: string;
  user_id: string;
  name: string;
  group_name: string;
  icon?: string;
  frequency: 'daily' | 'weekly' | 'custom';
  start_date: string;
  frequency_value: number;
  frequency_unit: 'days' | 'weeks' | 'months';
  duration_value: number;
  duration_unit: 'days' | 'weeks' | 'months';
  is_active: boolean;
  color?: string;
  description?: string;
  activity_type?: 'scheduled' | 'duration' | 'flexible';
  start_time?: string;
  end_time?: string;
  repeat_days?: string;
  target_duration_minutes?: number;
  reminders_enabled?: boolean;
  reminder_minutes_before?: number;
  reminder_at_end?: boolean;
  duration_seconds?: number;
  sessions?: string;
  created_at: string;
  updated_at: string;
}

export interface ActivityCompletion {
  id: string;
  activity_id: string;
  user_id: string;
  group_name: string;
  date: string; // YYYY-MM-DD
  completed: boolean;
  completed_at?: string;
  duration_seconds?: number;
  sessions?: string;
  notes?: string;
  created_at: string;
}

export interface ChatMessage {
  id: string;
  user_id: string;
  role: 'user' | 'assistant';
  message: string;
  action_type?: string;
  action_data?: string;
  created_at: string;
}

export interface UserSettings {
  id: string;
  user_id: string;
  theme: string;
  ai_enabled: boolean;
  ai_suggestions_enabled: boolean;
  notifications_enabled: boolean;
  timezone: string;
  quiet_hours_enabled?: boolean;
  quiet_hours_start?: string;
  quiet_hours_end?: string;
  updated_at: string;
}

export interface ProgressData {
  completed: number;
  total: number;
  percentage: number;
  date?: string;
}

export interface StreakData {
  current_streak: number;
  best_streak: number;
  last_completed_date?: string;
}

export interface ActivityGroup {
  id: string;
  user_id: string;
  name: string;
  created_at: string;
  updated_at: string;
}

