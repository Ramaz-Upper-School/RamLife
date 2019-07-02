import "package:flutter/material.dart";
import "package:flutter/services.dart" show PlatformException;

import "package:url_launcher/url_launcher.dart";

import "package:ramaz/widgets/icons.dart";
import "package:ramaz/widgets/theme_changer.dart";

// Used to actually login
import "package:ramaz/services/reader.dart";
import "package:ramaz/services/auth.dart" as Auth;
import "package:ramaz/services/preferences.dart";
// import "package:ramaz/services/dynamic_links.dart" as DynamicLinks;
import "package:ramaz/services/main.dart" show initOnLogin;

class Login extends StatefulWidget {
	final Reader reader;
	final Preferences prefs;
	Login(this.reader, this.prefs);

	@override LoginState createState() => LoginState();
}

class LoginState extends State <Login> {
	static final RegExp usernameRegex = RegExp ("[a-z]+");
	static final RegExp passwordRegex = RegExp (r"([a-z]|\d)+");
	final PageController pageController = PageController();
	final TextEditingController usernameController = TextEditingController();
	final FocusNode userNode = FocusNode();
	final GlobalKey<ScaffoldState> key = GlobalKey();

	Brightness brightness;
	String usernameError, passwordError;
	bool loading = false, ready = false;

	@override void initState() {
		// DynamicLinks.getLink().then (
		// 	(Uri uri) {
		// 		if (uri == null) 
		// 			print ("There is no dynamic link");
		// 		else {
		// 			print (uri.toString());
		// 			print (Auth.isSignInLink(uri.toString()));
		// 		}
		// 	}
		// );
		super.initState();
		Auth.signOut();  // To log in, one must first log out  --Levi
		widget.reader.deleteAll();
		bool userPreference = widget.prefs.brightness;
		if (brightness != null) brightness = userPreference
			? Brightness.light
			: Brightness.dark;
		// usernameController.text = "Coming soon";  // TODO
	}

	@override void dispose() {
		super.dispose();
		usernameController.dispose();
	}

	@override
	Widget build (BuildContext context) => Scaffold(
		key: key,
		appBar: AppBar (
			title: Text ("Login"),
			actions: [
				IconButton (
					icon: Icon (
						brightness == null
							?	Icons.brightness_auto
							: brightness == Brightness.light
								? Icons.brightness_5
								: Icons.brightness_4
					),
					onPressed: toggleBrightness
				)
			]
		),
		body: Column (
			children: [
				if (loading) LinearProgressIndicator(),
				Padding (
					padding: EdgeInsets.all (20),
					child: Column (
						children: [
							ThemeChanger.of(context).brightness == Brightness.light 
								? ClipRRect (
									borderRadius: BorderRadius.circular (20),
									child: RamazLogos.teal
								)
								: RamazLogos.ram_square_words, 
							// TextField(
							// 	controller: usernameController,
							// 	focusNode: userNode,
							// 	textInputAction: TextInputAction.done,
							// 	onChanged: validateUsername,
							// 	onSubmitted: login,
							// 	decoration: InputDecoration(
							// 		enabled: false,
							// 		icon: Icon (Icons.verified_user),
							// 		labelText: "Username",
							// 		hintText: "Enter your Ramaz username",
							// 		errorText: usernameError,
							// 		suffix: IconButton (
							// 			icon: Icon (Icons.done),
							// 			onPressed: ready ? login : null,
							// 			color: Colors.green,
							// 		)
							// 	)
							// ),
							// SizedBox (height: 20),
							// Center (child: Text ("OR", textScaleFactor: 1)),
							SizedBox (height: 50),
							Center (
								child: Container (
									decoration: BoxDecoration (
										border: Border.all(color: Colors.blue),
										borderRadius: BorderRadius.circular(20),
									),
									child: ListTile (
										leading: Logos.google,
										title: Text ("Sign in with Google"),
										onTap: googleLogin
									)
								)
							)
						]
					)
				)
			]
		)
	);

	static bool capturesAll (String text, RegExp regex) => 
		text.isEmpty || regex.matchAsPrefix(text)?.end == text.length;

	void validateUsername(String text) {
		String error;
		ready = text.isNotEmpty;
		if (text.contains("@"))
			error = "Do not enter your Ramaz email, just your username";
		else if (!capturesAll (text, usernameRegex))
			error = "Only lower case letters allowed";
		else error = null;
		if (error != null) ready = false;
		setState(() => usernameError = error);
	}

	// void login ([String username]) async {
	// 	// TODO: Check if user exists and has email set up
	// 	userNode.unfocus();
	// 	await Auth.signInWithEmail("leschesl@ramaz.org");
	// 	// downloadData(username ?? usernameController.text);

	// 	// final String username = usernameController.text;
	// 	// try {await Auth.signIn(username, password);}
	// 	// on PlatformException catch (error) {
	// 	// 	switch (error.code) {
	// 	// 		case "ERROR_USER_NOT_FOUND":
	// 	// 			setState(() => usernameError = "User does not exist");
	// 	// 			break;
	// 	// 		case "ERROR_WRONG_PASSWORD": 
	// 	// 			// Check if we can sign in with a password
	// 	// 			if ((await Auth.getSignInMethods(username)).contains ("password")) 
	// 	// 				setState(() => passwordError = "Invalid password");
	// 	// 			else setState(
	// 	// 				() => passwordError = "This account has no password -- sign in with Google."
	// 	// 			);
	// 	// 			break;
	// 	// 		default: throw "Cannot handle error: ${error.code}";
	// 	// 	}
	// 	// 	return;
	// 	// }
	// 	// downloadData(username);
	// }

	void googleLogin() async {
		try {
			final account = await Auth.signInWithGoogle(
				() => key.currentState.showSnackBar(
					SnackBar (
						content: Text ("You need to sign in with your Ramaz email")
					)
				)
			);
			if (account == null) return;
			await downloadData(account.email.toLowerCase().split("@")[0], google: true);
		}
		catch (error) {
			setState(() => loading = false);
			showDialog (
				context: context,
				builder: (dialogContext) => AlertDialog (
					title: Text ("Account corrupted"),
					content: Column (
						mainAxisSize: MainAxisSize.min,
						children: [
							Text (
								"Due to technical difficulties, your account cannot be accessed.\n"
								// "Please contact Mr. Vovsha or Levi Lesches (class of '21) for help:"
								"Please contact Levi Lesches (class of '21) for help" 
								// "\n\n\tvovshae@ramaz.org\n\n\tlevilesches@gmail.com"
							),
						],
					),
					actions: [
						FlatButton (
							child: Text ("Cancel"),
							onPressed: Navigator.of(dialogContext).pop
						),
						// FlatButton (
						// 	child: Text ("vovshae@ramaz.org"),
						// 	onPressed: () => launch ("mailto:vovshae@ramaz.org")
						// ),
						RaisedButton (
							child: Text ("levilesches@gmail.com"),
							onPressed: () => launch ("mailto:levilesches@gmail.com"),
							color: const Color(0XFF4A76BE)  // light Ramaz blue
						)
					]
				)
			);
			rethrow;
		}
	}

	void downloadData(String username, {bool google = false}) async {
		setState(() => loading = true);
		if (google) key.currentState.showSnackBar(
			SnackBar (
				content: Text ("Make sure to use Google to sign in next time")
			)
		); 
		try {await initOnLogin(widget.reader, widget.prefs, username);}
		on PlatformException {
			setState(() => loading = false);
			key.currentState.showSnackBar(
				SnackBar (content: Text ("Login failed"))
			);
			rethrow;
		}
		Navigator.of(context).pushReplacementNamed("home");
	}

	void toggleBrightness() {
		switch (brightness) {
			case Brightness.light: 
				setState(() => brightness = Brightness.dark);
				widget.prefs.brightness = false;
				break;
			case Brightness.dark: 
				setState(() => brightness = null);
				widget.prefs.brightness = null;
				break;
			default: 
				setState (() => brightness = Brightness.light);
				widget.prefs.brightness = true;
				break;
		}
		ThemeChanger.of(context).brightness = brightness;
	}
}
