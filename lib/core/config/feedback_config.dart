/// In-app feedback is sent with [mailto:] to this address.
///
/// Default is the product inbox. Override per build (e.g. white-label) with:
/// `--dart-define=FEEDBACK_EMAIL=other@example.com`
///
/// Flutter has no built-in `.env` file; compile-time values come from
/// `--dart-define` or constants like this. Packages such as `flutter_dotenv`
/// exist if you prefer loading a `.env` at runtime (still shipped with the app).
const String kFeedbackMailtoAddress = String.fromEnvironment(
  'FEEDBACK_EMAIL',
  defaultValue: 'onifkay@gmail.com',
);
