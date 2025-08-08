import 'package:flutter/material.dart';
import 'package:life_pilot/l10n/app_localizations.dart';

void showLoginError(BuildContext context, String result, AppLocalizations loc) {
  String errorMessage;
  switch (result) {
    case 'wrongUserPassword':
      errorMessage = loc.wrongUserPassword;
      break;
    case 'tooManyRequests':
      errorMessage = loc.tooManyRequests;
      break;
    case 'networkError':
      errorMessage = loc.networkError;
      break;
    case 'invalidEmail':
      errorMessage = loc.invalidEmail;
      break;
    case 'noEmailError':
      errorMessage = loc.noEmailError;
      break;
    case 'noPasswordError':
      errorMessage = loc.noPasswordError;
      break;
    case 'loginError':
      errorMessage = loc.loginError;
      break;
    case 'resetPasswordEmailNotFound':
      errorMessage = loc.resetPasswordEmailNotFound;
      break;
    case 'emailAlreadyInUse':
      errorMessage = loc.emailAlreadyInUse;
      break;
    case 'weakPassword':
      errorMessage = loc.weakPassword;
      break;
    case 'registerError':
      errorMessage = loc.registerError;
      break;
    case 'logoutError':
      errorMessage = loc.logoutError;
      break;
    default:
      errorMessage = loc.unknownError;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(errorMessage)),
  );
}

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}