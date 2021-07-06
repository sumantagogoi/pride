import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_login/theme.dart';
import 'package:flutter_login/widgets.dart';
import 'transition_route_observer.dart';
import 'widgets/fade_in.dart';
import 'constants.dart';
import 'widgets/animated_numeric_text.dart';
import 'widgets/round_button.dart';

import 'dart:async';

import 'package:flutter_background_geolocation/flutter_background_geolocation.dart'
as bg;
import 'config/ENV.dart';

////
// For pretty-printing locations as JSON
// @see _onLocation
//
import 'dart:convert';

JsonEncoder encoder = new JsonEncoder.withIndent("     ");


class DashboardScreen extends StatefulWidget {
  static const routeName = '/dashboard';
  @override
  _DashboardScreenState createState() => _DashboardScreenState();


}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin, TransitionRouteAware {
  Future<bool> _goToLogin(BuildContext context) {
    return Navigator.of(context)
        .pushReplacementNamed('/')
    // we dont want to pop the screen, just replace it completely
        .then((_) => false);
  }

  final routeObserver = TransitionRouteObserver<PageRoute?>();
  static const headerAniInterval = Interval(.1, .3, curve: Curves.easeOut);
  late Animation<double> _headerScaleAnimation;
  AnimationController? _loadingController;

  bool _isMoving = false;
  bool _enabled = false;
  String _motionActivity="";
  String _odometer="";
  String _content="";


  @override
  void initState() {
    super.initState();

    _content = "    Enable the switch to begin tracking.";
    _isMoving = false;
    _enabled = false;
    _content = '';
    _motionActivity = 'UNKNOWN';
    _odometer = '0';
    _initPlatformState();


    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1250),
    );

    _headerScaleAnimation =
        Tween<double>(begin: .6, end: 1).animate(CurvedAnimation(
          parent: _loadingController!,
          curve: headerAniInterval,
        ));
  }

  Future<Null> _initPlatformState() async {

    String orgname = "xyn";
    String username = "xynocast";


    // Fetch a Transistor demo server Authorization token for tracker.transistorsoft.com.
    bg.TransistorAuthorizationToken token =
    await bg.TransistorAuthorizationToken.findOrCreate(
        orgname, username, ENV.TRACKER_HOST);

    // 1.  Listen to events (See docs for all 12 available events).
    bg.BackgroundGeolocation.onLocation(_onLocation, _onLocationError);
    bg.BackgroundGeolocation.onMotionChange(_onMotionChange);
    bg.BackgroundGeolocation.onActivityChange(_onActivityChange);
    bg.BackgroundGeolocation.onProviderChange(_onProviderChange);
    bg.BackgroundGeolocation.onConnectivityChange(_onConnectivityChange);
    bg.BackgroundGeolocation.onHttp(_onHttp);
    bg.BackgroundGeolocation.onAuthorization(_onAuthorization);

    // 2.  Configure the plugin
    bg.BackgroundGeolocation.ready(bg.Config(
        reset: true,
        debug: true,
        logLevel: bg.Config.LOG_LEVEL_VERBOSE,
        desiredAccuracy: bg.Config.DESIRED_ACCURACY_HIGH,
        distanceFilter: 10.0,
        backgroundPermissionRationale: bg.PermissionRationale(
            title:
            "Allow {applicationName} to access this device's location even when the app is closed or not in use.",
            message:
            "This app collects location data to enable recording your trips to work and calculate distance-travelled.",
            positiveAction: 'Change to "{backgroundPermissionOptionLabel}"',
            negativeAction: 'Cancel'),
        url: "${ENV.TRACKER_HOST}/api/locations",
        authorization: bg.Authorization(
          // <-- demo server authenticates with JWT
            strategy: bg.Authorization.STRATEGY_JWT,
            accessToken: token.accessToken,
            refreshToken: token.refreshToken,
            refreshUrl: "${ENV.TRACKER_HOST}/api/refresh_token",
            refreshPayload: {'refresh_token': '{refreshToken}'}),
        stopOnTerminate: false,
        startOnBoot: true,
        enableHeadless: true))
        .then((bg.State state) {
      print("[ready] ${state.toMap()}");
      setState(() {
        _enabled = state.enabled;
        bool? move = state.isMoving;
        if (move != null) {
          _isMoving = move;
        }
      });
    }).catchError((error) {
      print('[ready] ERROR: $error');
    });
  }

  void _onClickEnable(enabled) {
    if (enabled) {
      // Reset odometer.
      bg.BackgroundGeolocation.start().then((bg.State state) {
        print('[start] success $state');
        setState(() {
          _enabled = state.enabled;
          bool? move = state.isMoving;
          if (move != null) {
            _isMoving = move;
          }
        });
      }).catchError((error) {
        print('[start] ERROR: $error');
      });
    } else {
      bg.BackgroundGeolocation.stop().then((bg.State state) {
        print('[stop] success: $state');

        setState(() {
          _enabled = state.enabled;
          bool? move = state.isMoving;
          if (move != null) {
            _isMoving = move;
          }
        });
      });
    }
  }

  // Manually toggle the tracking state:  moving vs stationary
  void _onClickChangePace() {
    setState(() {
      if (_isMoving != null) {
      _isMoving = !_isMoving;}
    });
    print("[onClickChangePace] -> $_isMoving");

    bg.BackgroundGeolocation.changePace(_isMoving).then((bool isMoving) {
      print('[changePace] success $isMoving');
    }).catchError((e) {
      print('[changePace] ERROR: ' + e.code.toString());
    });
  }

  // Manually fetch the current position.
  void _onClickGetCurrentPosition() {
    bg.BackgroundGeolocation.getCurrentPosition(
        persist: true, // <-- do persist this location
        desiredAccuracy: 0, // <-- desire best possible accuracy
        timeout: 30, // <-- wait 30s before giving up.
        samples: 3 // <-- sample 3 location before selecting best.
    )
        .then((bg.Location location) {
      print('[getCurrentPosition] - $location');
    }).catchError((error) {
      print('[getCurrentPosition] ERROR: $error');
    });
  }


  void _onLocation(bg.Location location) {
    print('[location] - $location');

    String odometerKM = (location.odometer / 1000.0).toStringAsFixed(1);

    setState(() {
      _content = encoder.convert(location.toMap());
      _odometer = odometerKM;
    });
  }

  void _onLocationError(bg.LocationError error) {
    print('[location] ERROR - $error');
  }

  void _onMotionChange(bg.Location location) {
    print('[motionchange] - $location');
  }

  void _onActivityChange(bg.ActivityChangeEvent event) {
    print('[activitychange] - $event');
    setState(() {
      _motionActivity = event.activity;
    });
  }

  void _onHttp(bg.HttpEvent event) async {
    print('[${bg.Event.HTTP}] - $event');
  }

  void _onAuthorization(bg.AuthorizationEvent event) async {
    print('[${bg.Event.AUTHORIZATION}] = $event');

    bg.BackgroundGeolocation.setConfig(
        bg.Config(url: ENV.TRACKER_HOST + '/api/locations'));
  }

  void _onProviderChange(bg.ProviderChangeEvent event) {
    print('$event');

    setState(() {
      _content = encoder.convert(event.toMap());
    });
  }

  void _onConnectivityChange(bg.ConnectivityChangeEvent event) {
    print('$event');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(
        this, ModalRoute.of(context) as PageRoute<dynamic>?);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _loadingController!.dispose();
    super.dispose();
  }

  @override
  void didPushAfterTransition() => _loadingController!.forward();

  AppBar _buildAppBar(ThemeData theme) {
    final menuBtn = IconButton(
      color: theme.accentColor,
      icon: const Icon(FontAwesomeIcons.bars),
      onPressed: () {},
      iconSize: 0.0,
    );
    final signOutBtn = IconButton(
      icon: const Icon(FontAwesomeIcons.signOutAlt),
      color: theme.accentColor,
      onPressed: () => _goToLogin(context),
    );
    final title = Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),

          ),
          HeroText(
            Constants.appName,
            tag: Constants.titleTag,
            viewState: ViewState.shrunk,
            style: LoginThemeHelper.loginTextStyle,
          ),
          SizedBox(width: 20),
        ],
      ),
    );

    return AppBar(
      leading: FadeIn(
        controller: _loadingController,
        offset: .3,
        curve: headerAniInterval,
        fadeDirection: FadeDirection.startToEnd,
        child: Image.asset(
          'assets/images/pride-east-logo.gif',
          filterQuality: FilterQuality.high,
          height: 30,
        ),
      ),
      actions: <Widget>[
        FadeIn(
          controller: _loadingController,
          offset: .3,
          curve: headerAniInterval,
          fadeDirection: FadeDirection.endToStart,
          child: signOutBtn,
        ),
      ],
      title: title,
      backgroundColor: theme.primaryColor.withOpacity(.8),
      elevation: 0,
      textTheme: theme.accentTextTheme,
      iconTheme: theme.accentIconTheme,
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final primaryColor =
        Colors.primaries.where((c) => c == theme.primaryColor).first;
    final accentColor =
        Colors.primaries.where((c) => c == theme.accentColor).first;
    final linearGradient = LinearGradient(colors: [
      primaryColor.shade800,
      primaryColor.shade200,
    ]).createShader(Rect.fromLTWH(0.0, 0.0, 418.0, 78.0));

    bool isSwitched = false;

    return ScaleTransition(
      scale: _headerScaleAnimation,
      child: FadeIn(
        controller: _loadingController,
        curve: headerAniInterval,
        fadeDirection: FadeDirection.bottomToTop,
        offset: .5,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              color: primaryColor,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  /*Text(
                    'Tracking Status: ',
                    style: theme.textTheme.headline3!.copyWith(
                      fontWeight: FontWeight.w300,
                      color: accentColor.shade400,
                    ),
                  ),

                  SizedBox(width: 5),*/
                  Text('GPS TRACKING:                               ',
                    style:  TextStyle(color: accentColor.shade400),),
                  Text('OFF',
                    style:  TextStyle(color: accentColor.shade400),),
                  Switch(value: _enabled, onChanged: _onClickEnable),
                  Text('ON',
                    style:  TextStyle(color: accentColor.shade400),),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButton(
      {Widget? icon, String? label, required Interval interval}) {
    return RoundButton(
      icon: icon,
      label: label,
      loadingController: _loadingController,
      interval: Interval(
        interval.begin,
        interval.end,
        curve: ElasticOutCurve(0.42),
      ),
      onPressed: () {},
    );
  }

  Widget _buildDashboardGrid() {
    const step = 0.04;
    const aniInterval = 0.75;

    return GridView.count(
      padding: const EdgeInsets.symmetric(
        horizontal: 32.0,
        vertical: 20,
      ),
      childAspectRatio: .9,
      // crossAxisSpacing: 5,
      crossAxisCount: 3,
      children: [
        _buildButton(
          icon: Icon(FontAwesomeIcons.user),
          label: 'Profile',
          interval: Interval(0, aniInterval),
        ),

        _buildButton(
          label: 'Questionnaire',
          icon: Icon(FontAwesomeIcons.clipboardList, size: 20),
          interval: Interval(step, aniInterval + step),
        ),
        _buildButton(
          icon: Icon(FontAwesomeIcons.slidersH, size: 20),
          label: 'Settings',
          interval: Interval(step * 2, aniInterval + step * 2),
        ),
      ],
    );
  }

  Widget _buildDebugButtons() {
    const textStyle = TextStyle(fontSize: 12, color: Colors.white);

    return Positioned(
      bottom: 0,
      right: 0,
      child: Row(
        // children: <Widget>[
        //   MaterialButton(
        //     materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        //     color: Colors.red,
        //     onPressed: () => _loadingController!.value == 0
        //         ? _loadingController!.forward()
        //         : _loadingController!.reverse(),
        //     child: Text('loading', style: textStyle),
        //   ),
        // ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return WillPopScope(
      onWillPop: () => _goToLogin(context),
      child: SafeArea(
        child: Scaffold(
          appBar: _buildAppBar(theme),
          body: Container(
            width: double.infinity,
            height: double.infinity,
            color: theme.primaryColor.withOpacity(.1),
            child: Stack(
              children: <Widget>[
                Column(
                  children: <Widget>[
                    SizedBox(height: 40),
                    Expanded(
                      flex: 2,
                      child: _buildHeader(theme),
                    ),
                    Expanded(
                      flex: 8,
                      child: ShaderMask(
                        // blendMode: BlendMode.srcOver,
                        shaderCallback: (Rect bounds) {
                          return LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            tileMode: TileMode.clamp,
                            colors: <Color>[
                              Colors.deepPurpleAccent.shade100,
                              Colors.deepPurple.shade100,
                              Colors.deepPurple.shade100,
                              Colors.deepPurple.shade100,
                              // Colors.red,
                              // Colors.yellow,
                            ],
                          ).createShader(bounds);
                        },
                        child: _buildDashboardGrid(),
                      ),
                    ),
                  ],
                ),
                if (!kReleaseMode) _buildDebugButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class SwitchScreen extends StatefulWidget {
  @override
  SwitchClass createState() => new SwitchClass();
}

class SwitchClass extends State {
  bool isSwitched = false;
  var textValue = 'Switch is OFF';

  void toggleSwitch(bool value) {

    if(isSwitched == false)
    {
      setState(() {
        isSwitched = true;
      });
      print('Switch Button is ON');
    }
    else
    {
      setState(() {
        isSwitched = false;
      });
      print('Switch Button is OFF');
    }
  }
  @override
  Widget build(BuildContext context) {
    return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children:[ Transform.scale(
            scale: 1,
            child: Switch(
              onChanged: toggleSwitch,
              value: isSwitched,
              activeColor: Colors.blue,
              activeTrackColor: Colors.yellow,
              inactiveThumbColor: Colors.redAccent,
              inactiveTrackColor: Colors.orange,
            )
        ),
        ]);
  }
}