import "package:flutter/foundation.dart" show ChangeNotifier;

import "package:ramaz/data.dart";
import "package:ramaz/models.dart";

/// A view model for the creating a new [Day].
// ignore: prefer_mixin
class DayBuilderModel with ChangeNotifier {
	/// The admin creating this [Day].
	/// 
	/// This is used to create [userSpecials].
	final AdminUserModel admin;

	Letters _letter;
	Special _special;

	/// Creates a view model for modifying a [Day].
	DayBuilderModel(AdminModel adminModel) : admin = adminModel.user {
		admin.addListener(notifyListeners);
	}

	@override 
	void dispose() {
		admin.removeListener(notifyListeners);
		super.dispose();
	}

	/// The letter for this day. 
	Letters get letter => _letter;
	set letter (Letters value) {
		_letter = value;
		notifyListeners();
	}

	/// The special for this day. 
	Special get special => _special;
	set special (Special value) {
		if (value == null) {
			return;
		}
		_special = value;
		if(
			!presetSpecials.any(
				(Special preset) => preset.name == value.name
			) && !userSpecials.any(
				(Special preset) => preset.name == value.name
			)
		) {
			admin.addSpecial(value);
		}

		notifyListeners();
	}
	
	/// The day being created (in present state). 
	/// 
	/// The model uses [letter] and [special]. 
	Day get day => Day (letter: letter, special: special);

	/// The built-in specials.  
	List<Special> get presetSpecials => Special.specials;

	/// Custom user-created specials. 
	List<Special> get userSpecials => admin.admin.specials;

	/// Whether this day is ready to be created. 
	bool get ready => letter != null && special != null;
}
