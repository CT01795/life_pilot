import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/vendor/model_vendor_account.dart';

String vendorPlanName(AppLocalizations loc, String planCode) {
  return switch (planCode.trim().toLowerCase()) {
    'free' => loc.vendorPlanFreeName,
    'partner' => loc.vendorPlanPartnerName,
    'growth' => loc.vendorPlanGrowthName,
    _ => loc.vendorPlanCustomName,
  };
}

String vendorPlanVersionName(AppLocalizations loc, VendorPricingPlan plan) {
  final planName = vendorPlanName(loc, plan.code);
  final raw = plan.versionName.trim();
  if (raw.isEmpty) return planName;

  final match = RegExp(
    r'^(?:vendor\s+free|free|partner|growth)\s*(.*)$',
    caseSensitive: false,
  ).firstMatch(raw);
  final version = match?.group(1)?.trim() ?? '';
  return version.isEmpty ? planName : '$planName $version';
}
