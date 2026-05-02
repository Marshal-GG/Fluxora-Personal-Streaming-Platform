/// Border-radius scale used by the desktop redesign.
///
/// Locked set — every radius below appears verbatim in the prototype CSS.
/// `pill` is the conventional 9999 used for fully-rounded ends.
class AppRadii {
  AppRadii._();

  static const double xs = 6;
  static const double sm = 8; // buttons, inputs
  static const double md = 10; // hover-tiles, quick-access cells
  static const double lg = 12; // cards
  static const double pill = 9999;
}
