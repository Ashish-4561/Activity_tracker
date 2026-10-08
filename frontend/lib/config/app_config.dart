class AppConfig {
  /// The duration of the guest trial period in days.
  static const int guestTrialDays = 2;

  /// Key used to store the guest trial start timestamp in SharedPreferences.
  static const String guestTrialStartKey = 'guest_trial_start_time';
}
