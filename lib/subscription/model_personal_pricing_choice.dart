enum PersonalPricingChoice {
  cloudFree,
  cloudPaid,
  localPaid;

  String get storagePlan => this == localPaid ? 'local' : 'cloud';
  bool get isFree => this == cloudFree;
  bool acceptsPrice(int? value) =>
      value != null && (isFree ? value == 0 : value > 0);

  static PersonalPricingChoice from(String storagePlan, int price) =>
      storagePlan == 'local'
      ? localPaid
      : price == 0
      ? cloudFree
      : cloudPaid;
}
