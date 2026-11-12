import 'package:flutter/foundation.dart';

// WHY: The stage page is pushed inside a tab navigator, so the parent app
// shell needs a shared signal to hide its persistent navigation chrome.
final ValueNotifier<bool> stageModeIsActive = ValueNotifier<bool>(false);
