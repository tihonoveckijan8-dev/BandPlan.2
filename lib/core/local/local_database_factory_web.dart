import 'package:sembast/sembast.dart';
import 'package:sembast_web/sembast_web.dart';

/// WHY: IndexedDB persists Flutter Web data independently from the Service
/// Worker cache, so cached records survive reloads and offline relaunches.
Future<Database> openBandPlanLocalDatabase() =>
    databaseFactoryWeb.openDatabase('bandplan_offline_v1');
