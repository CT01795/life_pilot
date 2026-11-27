enum PersonalPricingChoice {
  cloudFree,
  cloudPaid,
  localFree,
  localPaid;

  String get storagePlan =>
      this == localPaid || this == localFree ? 'local' : 'cloud';
  bool get isFree => this == cloudFree || this == localFree;
  bool acceptsPrice(int? value) =>
      value != null && (isFree ? value == 0 : value > 0);

  static PersonalPricingChoice from(String storagePlan, int price) =>
      storagePlan == 'local'
      ? (price == 0 ? localFree : localPaid)
      : price == 0
      ? cloudFree
      : cloudPaid;
}
