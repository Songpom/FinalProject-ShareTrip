class Member {
  String? email;
  String? password;
  String? username;
  String? memberImage;
  String? firstName;
  String? lastName;
  String? promptpayNumber;
  String? tel;

  Member({
    this.email,
    this.password,
    this.username,
    this.memberImage,
    this.firstName,
    this.lastName,
    this.promptpayNumber,
    this.tel,
  });

  factory Member.fromJson(Map<String, dynamic> json) {
    // รองรับได้หลายคีย์สำหรับรูปภาพ
    final dynamic imgRaw = json['memberImage'] ??
        json['member_image'] ??
        json['image'] ??
        json['avatar'] ??
        json['photo'];

    return Member(
      email: (json['email'] ?? '').toString(),
      password: (json['password'] ?? '').toString(),
      username: (json['username'] ?? '').toString(),
      memberImage: (imgRaw == null) ? '' : imgRaw.toString().trim(),
      firstName: (json['firstName'] ?? '').toString(),
      lastName: (json['lastName'] ?? '').toString(),
      promptpayNumber: (json['promptpayNumber'] ?? '').toString(),
      tel: (json['tel'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'email': email,
        'password': password,
        'username': username,
        // ถ้าฝั่ง backend คาดหวัง snake_case ก็ส่งคีย์นี้
        'member_image': memberImage,
        'firstName': firstName,
        'lastName': lastName,
        'promptpayNumber': promptpayNumber,
        'tel': tel,
      };

  factory Member.empty() {
    return Member(
      email: '',
      password: '',
      username: '',
      memberImage: '',
      firstName: '',
      lastName: '',
      promptpayNumber: '',
      tel: '',
    );
  }
}
