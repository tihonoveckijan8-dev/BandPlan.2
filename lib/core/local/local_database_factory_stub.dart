import 'package:sembast/sembast.dart';

/// Fails explicitly on unsupported runtimes instead of silently using memory.
Future<Database> openBandPlanLocalDatabase() {
  throw UnsupportedError('BandPlan local storage is not supported on this platform.');
}
