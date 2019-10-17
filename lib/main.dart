import "dart:async" show runZoned;

import "package:flutter/material.dart";
import "package:flutter/services.dart";

import "package:firebase_crashlytics/firebase_crashlytics.dart";
import "package:path_provider/path_provider.dart";
import "package:shared_preferences/shared_preferences.dart";

import "package:ramaz/constants.dart";  // for route keys
import "package:ramaz/pages.dart";
import "package:ramaz/services.dart";
import "package:ramaz/services_collection.dart";
import "package:ramaz/widgets.dart";

/// Completely refresh the user's schedule 
/// Basically simulate the login sequence
Future<void> refresh(ServicesCollection services) async {
	final String email = await Auth.email;
	if (email == null) {
		throw StateError(
			"Cannot refresh schedule because the user is not logged in."
		);
	}
	await services.initOnLogin(email, first: false);
	services.reminders.setup();
	services.schedule.setup(services.reader);
}

Future<void> updateCalendar(ServicesCollection services) async {
	final Map<String, dynamic> calendar = await Firestore.month;
	services.reader.calendarData = calendar;
	services.schedule.setup(services.reader);
}

Future<void> main({bool restart = false}) async {
	// This shows a splash screen but secretly 
	// determines the desired `platformBrightness`
	Brightness brightness;
	runApp (
		SplashScreen(
			setBrightness: 
				(Brightness platform) => brightness = platform
		)
	);
	await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

	// Initialize basic backend
	// 
	// First, get the raw materials. 
	// 	This is done here since they are `Future`s, and this is
	// 	the only place those `Future`s can be reliably `await`ed. 
	final SharedPreferences prefs = await SharedPreferences.getInstance();
	final String dir = (await getApplicationDocumentsDirectory()).path;

	ServicesCollection services;
	Reader reader;
	bool ready;
	try {
		// Now, actually initialize the backend services.

		// Reader is kept out of ServicesCollection so it can be used to reset
		reader = Reader(dir);
		services = ServicesCollection(
			reader: reader,
			prefs: Preferences(prefs),
		);
		
		// To download, and login or go to main
		ready = services.reader.ready && await Auth.ready;
		if (ready) {
			services.init();
		}
	// We want to at least try again on ANY error. 
	// ignore: avoid_catches_without_on_clauses
	} catch (_) {
		debugPrint ("Error on main.");
		if (!restart) {
			debugPrint ("Trying again...");
			await Auth.signOut();
			reader.deleteAll();
			return main(restart: true);
		} else {
			rethrow;
		}
	}

	// Determine the appropriate brightness. 
	final bool savedBrightness = services.prefs.brightness;
	if (savedBrightness != null) {
		brightness = savedBrightness
			? Brightness.light
			: Brightness.dark;
	}

	// Register for FCM notifications. 
	// We don't care when this happens
	// ignore: unawaited_futures 
	Future(
		() async {
			await FCM.registerNotifications(
				{
					"refresh": () => refresh(services),
					"updateCalendar": () => updateCalendar(services),
				}
			);
			await FCM.subscribeToCalendar();
		}
	);

	// Now we are ready to run the app (with error catching)
	// FlutterError.onError = Crashlytics.instance.recordFlutterError;
	FlutterError.onError = (_) {
		print("Flutter caught an error");
		onCrash();
	};
	runZoned(
		() => runApp (
			MaterialApp(
				home: TempApp(),
			),
			// RamazApp (
			// 	ready: ready,
			// 	brightness: brightness,
			// 	services: services,
			// )
		),
		// onError: Crashlytics.instance.recordError,
		onError: (_, [__]) {
			print("Zone caught an error");
			onCrash();
		}
	);
}

void onCrash() {
	runApp(
		MaterialApp(
			home: Scaffold(
				appBar: AppBar(title: Text("Error")),
				body: Center(child: Text("There was an error")),
			)
		)
	);
}

class RamazApp extends StatefulWidget {
	final Brightness brightness;
	final ServicesCollection services;
	final bool ready;
	const RamazApp ({
		@required this.brightness,
		@required this.ready,
		@required this.services,
	});

	@override MainAppState createState() => MainAppState();
}

class MainAppState extends State<RamazApp> {
	@override 
	Widget build (BuildContext context) => Services (
		services: widget.services,
		child: ThemeChanger (
			defaultBrightness: widget.brightness,
			light: ThemeData (
				brightness: Brightness.light,
				primarySwatch: Colors.blue,
				primaryColor: RamazColors.blue,
				primaryColorBrightness: Brightness.dark,
				primaryColorLight: RamazColors.blueLight,
				primaryColorDark: RamazColors.blueDark,
				accentColor: RamazColors.gold,
				accentColorBrightness: Brightness.light,
				cursorColor: RamazColors.blueLight,
				textSelectionHandleColor: RamazColors.blueLight,
				buttonColor: RamazColors.gold,
				buttonTheme: ButtonThemeData (
					buttonColor: RamazColors.gold,
					textTheme: ButtonTextTheme.normal,
				),
			),
			dark: ThemeData(
				brightness: Brightness.dark,
				scaffoldBackgroundColor: Colors.grey[850],
				primarySwatch: Colors.blue,
				primaryColorBrightness: Brightness.dark,
				primaryColorLight: RamazColors.blueLight,
				// primaryColor: RamazColors.blue,
				primaryColorDark: RamazColors.blueDark,
				accentColor: RamazColors.goldDark,
				accentColorBrightness: Brightness.light,
				iconTheme: IconThemeData (color: RamazColors.goldDark),
				primaryIconTheme: IconThemeData (color: RamazColors.goldDark),
				accentIconTheme: IconThemeData (color: RamazColors.goldDark),
				floatingActionButtonTheme: FloatingActionButtonThemeData(
					backgroundColor: RamazColors.goldDark,
					foregroundColor: RamazColors.blue
				),
				cursorColor: RamazColors.blueLight,
				textSelectionHandleColor: RamazColors.blueLight,
				cardTheme: CardTheme (
					color: Colors.grey[820]
				),
				toggleableActiveColor: RamazColors.blueLight,
				buttonColor: RamazColors.blueDark,
				buttonTheme: ButtonThemeData (
					buttonColor: RamazColors.blueDark, 
					textTheme: ButtonTextTheme.accent,
				),
			),
			builder: (BuildContext context, ThemeData theme) => MaterialApp (
				home: widget.ready
					? HomePage()
					: Login(),
				title: "Student Life",
				color: RamazColors.blue,
				theme: theme,
				routes: {
					Routes.login: (_) => Login(),
					Routes.home: (_) => HomePage(),
					Routes.schedule: (_) => SchedulePage(),
					Routes.reminders: (_) => RemindersPage(),
					Routes.feedback: (_) => FeedbackPage(),
				}
			)
		)
	);
}

Future<void> throwError() async {
	await Future.delayed(Duration(seconds: 1));
	throw Exception("This is an error");
}

class TempApp extends StatelessWidget {
	@override
	Widget build(BuildContext context) => Scaffold(
		appBar: AppBar(title: Text("Demo")),
		body: Center(child: Text("This will crash")),
		floatingActionButton: FloatingActionButton(
			child: Icon(Icons.error),
			onPressed: throwError,
		)
	);
}

	
// Placeholder
// class PlaceholderPage extends StatelessWidget {
// 	final String title;
// 	PlaceholderPage (this.title);

// 	@override Widget build (BuildContext context) => Scaffold (
// 		drawer: NavigationDrawer(),
// 		appBar: AppBar (
// 			title: Text (title),
// 			actions: [
// 				IconButton (
// 					icon: Icon (Icons.home),
// 					onPressed: () => Navigator.of(context).pushReplacementNamed(HOME_PAGE)
// 				)
// 			]
// 		),
// 		body: Center (
// 			child: Text ("This page is coming soon!", textScaleFactor: 2)
// 		)
// 	);
// }

// Widget Function(BuildContext) placeholder(String text) => 
// 	(BuildContext context) => PlaceholderPage (text);
