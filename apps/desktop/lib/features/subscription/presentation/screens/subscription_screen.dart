/// Subscription screen — placeholder until M7 builds the full pricing /
/// billing-history / manage surface.
///
/// For now it forwards to the existing `LicensesScreen` so paid users can
/// still see their orders + license keys. Renamed from "Licenses" per the
/// redesign plan §3.1.
library;

import 'package:fluxora_desktop/features/orders/presentation/screens/licenses_screen.dart';

// Type alias the redesigned route to the existing implementation. Replaced
// by a proper SubscriptionScreen widget at M7.
typedef SubscriptionScreen = LicensesScreen;
