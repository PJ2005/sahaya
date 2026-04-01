enum Flavor { ngo, volunteer }

class F {
  static late final Flavor appFlavor;

  static String get name => appFlavor.name;

  static String get title {
    switch (appFlavor) {
      case Flavor.ngo:
        return 'Sahaya NGO';
      case Flavor.volunteer:
        return 'Sahaya Volunteer';
    }
  }
}
