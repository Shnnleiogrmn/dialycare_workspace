enum MobileAccountStatus { notActivated, activationPending, active, disabled }

class MobileAccount {
  const MobileAccount({
    this.status = MobileAccountStatus.notActivated,
    this.activatedAt,
    this.activationExpiresAt,
  });
  final MobileAccountStatus status;
  final DateTime? activatedAt;
  final DateTime? activationExpiresAt;
  String get label => switch (status) {
    MobileAccountStatus.notActivated => 'Not Activated',
    MobileAccountStatus.activationPending => 'Activation Pending',
    MobileAccountStatus.active => 'Active',
    MobileAccountStatus.disabled => 'Disabled',
  };
  Map<String, dynamic> toJson() => {
    'accountStatus': status.name,
    'activatedAt': activatedAt?.toUtc().toIso8601String(),
    'activationExpiresAt': activationExpiresAt?.toUtc().toIso8601String(),
  };
  factory MobileAccount.fromJson(Map<String, dynamic>? value) => value == null
      ? const MobileAccount()
      : MobileAccount(
          status: MobileAccountStatus.values.firstWhere(
            (s) => s.name == value['accountStatus'],
            orElse: () => MobileAccountStatus.notActivated,
          ),
          activatedAt: DateTime.tryParse(value['activatedAt'] as String? ?? ''),
          activationExpiresAt: DateTime.tryParse(
            value['activationExpiresAt'] as String? ?? '',
          ),
        );
}
