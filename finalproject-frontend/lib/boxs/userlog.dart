class UserLog {
  static final UserLog _instance = UserLog._internal();

  factory UserLog() {
    return _instance;
  }

  UserLog._internal();

  String email = '';

  void clear() {
    email = '';
  }
}
