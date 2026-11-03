import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart';

/// WHY: Keep the database in app support storage so it survives ordinary restarts
/// and is not mixed with user-exported files.
Future<Database> openBandPlanLocalDatabase() async {
  final directory = await getApplicationSupportDirectory();
  await directory.create(recursive: true);
  final path = p.join(directory.path, 'bandplan_offline_v1.db');
  return databaseFactoryIo.openDatabase(path);
}
