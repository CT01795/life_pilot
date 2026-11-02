import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/subscription/model_billing_cycle.dart';

String billingCycleLabel(AppLocalizations loc, BillingCycle cycle) =>
    cycle == BillingCycle.month ? loc.billingMonthly : loc.billingQuarterly;

String billingPriceLabel(AppLocalizations loc, int price, BillingCycle cycle) =>
    price == 0
    ? loc.free
    : cycle == BillingCycle.month
    ? loc.billingMonthlyPrice(price)
    : loc.vendorQuarterlyPrice(price);
