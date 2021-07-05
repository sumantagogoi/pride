import 'package:flutter_background_geolocation/flutter_background_geolocation.dart'
    as bg;
import 'ENV.dart';

void _onHttp(bg.HttpEvent event) async {
  switch (event.status) {
    case 403:
    case 406:
      print("TransistorAuth] onHttp status ${event.status}");
      await bg.TransistorAuthorizationToken.destroy(ENV.TRACKER_HOST);
      bool success = await TransistorAuth.register();
      if (success) {
        bg.BackgroundGeolocation.sync().catchError((error) {
          print("[sync] error: $error");
        });
      }
      break;
  }
}

class TransistorAuth {


  static Future<bool> register() async {


      String orgname = "xyn";
      String username = "xynocast";



      bg.TransistorAuthorizationToken jwt =
          await bg.TransistorAuthorizationToken.findOrCreate(
              orgname, username, ENV.TRACKER_HOST);

      await bg.BackgroundGeolocation.setConfig(
          bg.Config(transistorAuthorizationToken: jwt));
      return true;


  }

  static Future<void> registerErrorHandler() async {
    bg.State state = await bg.BackgroundGeolocation.state;
    if ((state.params != null) && (state.params['device'] != null)) {
      _migrateConfig();
    }
    bg.BackgroundGeolocation.removeListener(_onHttp);
    bg.BackgroundGeolocation.onHttp(_onHttp);
  }

  static void _migrateConfig() async {
    print("[TransistorAuth] migrateConfig");
    await bg.TransistorAuthorizationToken.destroy(ENV.TRACKER_HOST);
    bg.BackgroundGeolocation.reset(bg.Config(
        debug: true,
        logLevel: bg.Config.LOG_LEVEL_VERBOSE,
        desiredAccuracy: bg.Config.DESIRED_ACCURACY_HIGH,
        distanceFilter: 10.0,
        stopOnTerminate: false,
        startOnBoot: true,
        url: "${ENV.TRACKER_HOST}/api/locations",
        params: {}));
  }
}
