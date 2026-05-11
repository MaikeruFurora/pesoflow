import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

/// Pushes the latest summary numbers to the Android home-screen widget.
/// The widget reads these via Kotlin's HomeWidgetPlugin SharedPreferences.
class HomeWidgetSync {
  static const _provider = 'PesoFlowWidgetProvider';

  static final _fmt = NumberFormat.currency(
    locale: 'en_PH',
    symbol: '₱ ',
    decimalDigits: 0,
  );

  static Future<void> push({
    required double totalAssets,
    required double iOwe,
    required double owedToMe,
  }) async {
    try {
      await HomeWidget.saveWidgetData<String>(
          'pf_assets', _fmt.format(totalAssets));
      await HomeWidget.saveWidgetData<String>(
          'pf_iowe', _fmt.format(iOwe));
      await HomeWidget.saveWidgetData<String>(
          'pf_owedtome', _fmt.format(owedToMe));
      await HomeWidget.saveWidgetData<String>(
          'pf_updated',
          DateFormat('MMM d, h:mm a').format(DateTime.now()));
      await HomeWidget.updateWidget(
        name: _provider,
        androidName: _provider,
      );
    } catch (_) {
      // Widget plugin can throw on emulators / when no widget is placed yet —
      // swallow so app flow isn't disrupted.
    }
  }
}
