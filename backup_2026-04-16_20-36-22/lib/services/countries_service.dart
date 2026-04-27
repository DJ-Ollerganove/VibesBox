import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/debug_log.dart';

/// Eintrag für die Firestore-Collection [CountriesService.collectionId].
class CountryEntry {
  final String name;
  final String code;

  const CountryEntry({required this.name, required this.code});

  Map<String, dynamic> toMap() => {'name': name, 'code': code};
}

/// Länderliste (ISO 3166-1 alpha-2, Englisch, alphabetisch).
/// Einmalig [seedCountries] aufrufen, um die Firestore-Collection zu füllen.
class CountriesService {
  static const String collectionId = 'countries';

  /// Einmalig aufrufen (z. B. aus Admin-Seite oder Setup), um die Collection zu befüllen.
  static Future<void> seedCountries() async {
    try {
      final list = List<CountryEntry>.from(_allCountriesEnglish);
      list.sort((a, b) => a.name.compareTo(b.name));
      final col = FirebaseFirestore.instance.collection(collectionId);
      final batch = FirebaseFirestore.instance.batch();
      for (final c in list) {
        final ref = col.doc(c.code);
        batch.set(ref, c.toMap());
      }
      await batch.commit();
    } catch (e) {
      // Permission-Fehler oder Netzwerkprobleme: leise im Hintergrund abfangen, App nicht abstürzen lassen
      debugLog('CountriesService.seedCountries: $e');
    }
  }

  /// Stream aller Länder aus Firestore (für Dropdown). Leer, bis [seedCountries] ausgeführt wurde.
  static Stream<List<CountryEntry>> getCountriesStream() {
    return FirebaseFirestore.instance
        .collection(collectionId)
        .orderBy('name')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) {
              final data = d.data();
              return CountryEntry(
                name: data['name'] as String? ?? '',
                code: data['code'] as String? ?? d.id,
              );
            })
            .where((e) => e.name.isNotEmpty)
            .toList());
  }

  /// Einmalige Abfrage der Länderliste (z. B. für Dialog).
  static Future<List<CountryEntry>> getCountriesOnce() async {
    final snap = await FirebaseFirestore.instance
        .collection(collectionId)
        .orderBy('name')
        .get();
    return snap.docs.map((d) {
      final data = d.data();
      return CountryEntry(
        name: data['name'] as String? ?? '',
        code: data['code'] as String? ?? d.id,
      );
    }).where((e) => e.name.isNotEmpty).toList();
  }

  static final List<CountryEntry> _allCountriesEnglish = [
    const CountryEntry(name: 'Afghanistan', code: 'AF'),
    const CountryEntry(name: 'Åland Islands', code: 'AX'),
    const CountryEntry(name: 'Albania', code: 'AL'),
    const CountryEntry(name: 'Algeria', code: 'DZ'),
    const CountryEntry(name: 'American Samoa', code: 'AS'),
    const CountryEntry(name: 'Andorra', code: 'AD'),
    const CountryEntry(name: 'Angola', code: 'AO'),
    const CountryEntry(name: 'Anguilla', code: 'AI'),
    const CountryEntry(name: 'Antarctica', code: 'AQ'),
    const CountryEntry(name: 'Antigua and Barbuda', code: 'AG'),
    const CountryEntry(name: 'Argentina', code: 'AR'),
    const CountryEntry(name: 'Armenia', code: 'AM'),
    const CountryEntry(name: 'Aruba', code: 'AW'),
    const CountryEntry(name: 'Australia', code: 'AU'),
    const CountryEntry(name: 'Austria', code: 'AT'),
    const CountryEntry(name: 'Azerbaijan', code: 'AZ'),
    const CountryEntry(name: 'Bahamas', code: 'BS'),
    const CountryEntry(name: 'Bahrain', code: 'BH'),
    const CountryEntry(name: 'Bangladesh', code: 'BD'),
    const CountryEntry(name: 'Barbados', code: 'BB'),
    const CountryEntry(name: 'Belarus', code: 'BY'),
    const CountryEntry(name: 'Belgium', code: 'BE'),
    const CountryEntry(name: 'Belize', code: 'BZ'),
    const CountryEntry(name: 'Benin', code: 'BJ'),
    const CountryEntry(name: 'Bermuda', code: 'BM'),
    const CountryEntry(name: 'Bhutan', code: 'BT'),
    const CountryEntry(name: 'Bolivia, Plurinational State of', code: 'BO'),
    const CountryEntry(name: 'Bonaire, Sint Eustatius and Saba', code: 'BQ'),
    const CountryEntry(name: 'Bosnia and Herzegovina', code: 'BA'),
    const CountryEntry(name: 'Botswana', code: 'BW'),
    const CountryEntry(name: 'Bouvet Island', code: 'BV'),
    const CountryEntry(name: 'Brazil', code: 'BR'),
    const CountryEntry(name: 'British Indian Ocean Territory', code: 'IO'),
    const CountryEntry(name: 'Brunei Darussalam', code: 'BN'),
    const CountryEntry(name: 'Bulgaria', code: 'BG'),
    const CountryEntry(name: 'Burkina Faso', code: 'BF'),
    const CountryEntry(name: 'Burundi', code: 'BI'),
    const CountryEntry(name: 'Cabo Verde', code: 'CV'),
    const CountryEntry(name: 'Cambodia', code: 'KH'),
    const CountryEntry(name: 'Cameroon', code: 'CM'),
    const CountryEntry(name: 'Canada', code: 'CA'),
    const CountryEntry(name: 'Cayman Islands', code: 'KY'),
    const CountryEntry(name: 'Central African Republic', code: 'CF'),
    const CountryEntry(name: 'Chad', code: 'TD'),
    const CountryEntry(name: 'Chile', code: 'CL'),
    const CountryEntry(name: 'China', code: 'CN'),
    const CountryEntry(name: 'Christmas Island', code: 'CX'),
    const CountryEntry(name: 'Cocos (Keeling) Islands', code: 'CC'),
    const CountryEntry(name: 'Colombia', code: 'CO'),
    const CountryEntry(name: 'Comoros', code: 'KM'),
    const CountryEntry(name: 'Congo', code: 'CG'),
    const CountryEntry(name: 'Congo, Democratic Republic of the', code: 'CD'),
    const CountryEntry(name: 'Cook Islands', code: 'CK'),
    const CountryEntry(name: 'Costa Rica', code: 'CR'),
    const CountryEntry(name: "Côte d'Ivoire", code: 'CI'),
    const CountryEntry(name: 'Croatia', code: 'HR'),
    const CountryEntry(name: 'Cuba', code: 'CU'),
    const CountryEntry(name: 'Curaçao', code: 'CW'),
    const CountryEntry(name: 'Cyprus', code: 'CY'),
    const CountryEntry(name: 'Czechia', code: 'CZ'),
    const CountryEntry(name: 'Denmark', code: 'DK'),
    const CountryEntry(name: 'Djibouti', code: 'DJ'),
    const CountryEntry(name: 'Dominica', code: 'DM'),
    const CountryEntry(name: 'Dominican Republic', code: 'DO'),
    const CountryEntry(name: 'Ecuador', code: 'EC'),
    const CountryEntry(name: 'Egypt', code: 'EG'),
    const CountryEntry(name: 'El Salvador', code: 'SV'),
    const CountryEntry(name: 'Equatorial Guinea', code: 'GQ'),
    const CountryEntry(name: 'Eritrea', code: 'ER'),
    const CountryEntry(name: 'Estonia', code: 'EE'),
    const CountryEntry(name: 'Eswatini', code: 'SZ'),
    const CountryEntry(name: 'Ethiopia', code: 'ET'),
    const CountryEntry(name: 'Falkland Islands (Malvinas)', code: 'FK'),
    const CountryEntry(name: 'Faroe Islands', code: 'FO'),
    const CountryEntry(name: 'Fiji', code: 'FJ'),
    const CountryEntry(name: 'Finland', code: 'FI'),
    const CountryEntry(name: 'France', code: 'FR'),
    const CountryEntry(name: 'French Guiana', code: 'GF'),
    const CountryEntry(name: 'French Polynesia', code: 'PF'),
    const CountryEntry(name: 'French Southern Territories', code: 'TF'),
    const CountryEntry(name: 'Gabon', code: 'GA'),
    const CountryEntry(name: 'Gambia', code: 'GM'),
    const CountryEntry(name: 'Georgia', code: 'GE'),
    const CountryEntry(name: 'Germany', code: 'DE'),
    const CountryEntry(name: 'Ghana', code: 'GH'),
    const CountryEntry(name: 'Gibraltar', code: 'GI'),
    const CountryEntry(name: 'Greece', code: 'GR'),
    const CountryEntry(name: 'Greenland', code: 'GL'),
    const CountryEntry(name: 'Grenada', code: 'GD'),
    const CountryEntry(name: 'Guadeloupe', code: 'GP'),
    const CountryEntry(name: 'Guam', code: 'GU'),
    const CountryEntry(name: 'Guatemala', code: 'GT'),
    const CountryEntry(name: 'Guernsey', code: 'GG'),
    const CountryEntry(name: 'Guinea', code: 'GN'),
    const CountryEntry(name: 'Guinea-Bissau', code: 'GW'),
    const CountryEntry(name: 'Guyana', code: 'GY'),
    const CountryEntry(name: 'Haiti', code: 'HT'),
    const CountryEntry(name: 'Heard Island and McDonald Islands', code: 'HM'),
    const CountryEntry(name: 'Holy See', code: 'VA'),
    const CountryEntry(name: 'Honduras', code: 'HN'),
    const CountryEntry(name: 'Hong Kong', code: 'HK'),
    const CountryEntry(name: 'Hungary', code: 'HU'),
    const CountryEntry(name: 'Iceland', code: 'IS'),
    const CountryEntry(name: 'India', code: 'IN'),
    const CountryEntry(name: 'Indonesia', code: 'ID'),
    const CountryEntry(name: 'Iran, Islamic Republic of', code: 'IR'),
    const CountryEntry(name: 'Iraq', code: 'IQ'),
    const CountryEntry(name: 'Ireland', code: 'IE'),
    const CountryEntry(name: 'Isle of Man', code: 'IM'),
    const CountryEntry(name: 'Israel', code: 'IL'),
    const CountryEntry(name: 'Italy', code: 'IT'),
    const CountryEntry(name: 'Jamaica', code: 'JM'),
    const CountryEntry(name: 'Japan', code: 'JP'),
    const CountryEntry(name: 'Jersey', code: 'JE'),
    const CountryEntry(name: 'Jordan', code: 'JO'),
    const CountryEntry(name: 'Kazakhstan', code: 'KZ'),
    const CountryEntry(name: 'Kenya', code: 'KE'),
    const CountryEntry(name: 'Kiribati', code: 'KI'),
    const CountryEntry(name: 'Korea, Democratic People\'s Republic of', code: 'KP'),
    const CountryEntry(name: 'Korea, Republic of', code: 'KR'),
    const CountryEntry(name: 'Kuwait', code: 'KW'),
    const CountryEntry(name: 'Kyrgyzstan', code: 'KG'),
    const CountryEntry(name: 'Lao People\'s Democratic Republic', code: 'LA'),
    const CountryEntry(name: 'Latvia', code: 'LV'),
    const CountryEntry(name: 'Lebanon', code: 'LB'),
    const CountryEntry(name: 'Lesotho', code: 'LS'),
    const CountryEntry(name: 'Liberia', code: 'LR'),
    const CountryEntry(name: 'Libya', code: 'LY'),
    const CountryEntry(name: 'Liechtenstein', code: 'LI'),
    const CountryEntry(name: 'Lithuania', code: 'LT'),
    const CountryEntry(name: 'Luxembourg', code: 'LU'),
    const CountryEntry(name: 'Macao', code: 'MO'),
    const CountryEntry(name: 'Madagascar', code: 'MG'),
    const CountryEntry(name: 'Malawi', code: 'MW'),
    const CountryEntry(name: 'Malaysia', code: 'MY'),
    const CountryEntry(name: 'Maldives', code: 'MV'),
    const CountryEntry(name: 'Mali', code: 'ML'),
    const CountryEntry(name: 'Malta', code: 'MT'),
    const CountryEntry(name: 'Marshall Islands', code: 'MH'),
    const CountryEntry(name: 'Martinique', code: 'MQ'),
    const CountryEntry(name: 'Mauritania', code: 'MR'),
    const CountryEntry(name: 'Mauritius', code: 'MU'),
    const CountryEntry(name: 'Mayotte', code: 'YT'),
    const CountryEntry(name: 'Mexico', code: 'MX'),
    const CountryEntry(name: 'Micronesia, Federated States of', code: 'FM'),
    const CountryEntry(name: 'Moldova, Republic of', code: 'MD'),
    const CountryEntry(name: 'Monaco', code: 'MC'),
    const CountryEntry(name: 'Mongolia', code: 'MN'),
    const CountryEntry(name: 'Montenegro', code: 'ME'),
    const CountryEntry(name: 'Montserrat', code: 'MS'),
    const CountryEntry(name: 'Morocco', code: 'MA'),
    const CountryEntry(name: 'Mozambique', code: 'MZ'),
    const CountryEntry(name: 'Myanmar', code: 'MM'),
    const CountryEntry(name: 'Namibia', code: 'NA'),
    const CountryEntry(name: 'Nauru', code: 'NR'),
    const CountryEntry(name: 'Nepal', code: 'NP'),
    const CountryEntry(name: 'Netherlands, Kingdom of the', code: 'NL'),
    const CountryEntry(name: 'New Caledonia', code: 'NC'),
    const CountryEntry(name: 'New Zealand', code: 'NZ'),
    const CountryEntry(name: 'Nicaragua', code: 'NI'),
    const CountryEntry(name: 'Niger', code: 'NE'),
    const CountryEntry(name: 'Nigeria', code: 'NG'),
    const CountryEntry(name: 'Niue', code: 'NU'),
    const CountryEntry(name: 'Norfolk Island', code: 'NF'),
    const CountryEntry(name: 'North Macedonia', code: 'MK'),
    const CountryEntry(name: 'Northern Mariana Islands', code: 'MP'),
    const CountryEntry(name: 'Norway', code: 'NO'),
    const CountryEntry(name: 'Oman', code: 'OM'),
    const CountryEntry(name: 'Pakistan', code: 'PK'),
    const CountryEntry(name: 'Palau', code: 'PW'),
    const CountryEntry(name: 'Palestine, State of', code: 'PS'),
    const CountryEntry(name: 'Panama', code: 'PA'),
    const CountryEntry(name: 'Papua New Guinea', code: 'PG'),
    const CountryEntry(name: 'Paraguay', code: 'PY'),
    const CountryEntry(name: 'Peru', code: 'PE'),
    const CountryEntry(name: 'Philippines', code: 'PH'),
    const CountryEntry(name: 'Pitcairn', code: 'PN'),
    const CountryEntry(name: 'Poland', code: 'PL'),
    const CountryEntry(name: 'Portugal', code: 'PT'),
    const CountryEntry(name: 'Puerto Rico', code: 'PR'),
    const CountryEntry(name: 'Qatar', code: 'QA'),
    const CountryEntry(name: 'Réunion', code: 'RE'),
    const CountryEntry(name: 'Romania', code: 'RO'),
    const CountryEntry(name: 'Russian Federation', code: 'RU'),
    const CountryEntry(name: 'Rwanda', code: 'RW'),
    const CountryEntry(name: 'Saint Barthélemy', code: 'BL'),
    const CountryEntry(name: 'Saint Helena, Ascension and Tristan da Cunha', code: 'SH'),
    const CountryEntry(name: 'Saint Kitts and Nevis', code: 'KN'),
    const CountryEntry(name: 'Saint Lucia', code: 'LC'),
    const CountryEntry(name: 'Saint Martin (French part)', code: 'MF'),
    const CountryEntry(name: 'Saint Pierre and Miquelon', code: 'PM'),
    const CountryEntry(name: 'Saint Vincent and the Grenadines', code: 'VC'),
    const CountryEntry(name: 'Samoa', code: 'WS'),
    const CountryEntry(name: 'San Marino', code: 'SM'),
    const CountryEntry(name: 'Sao Tome and Principe', code: 'ST'),
    const CountryEntry(name: 'Saudi Arabia', code: 'SA'),
    const CountryEntry(name: 'Senegal', code: 'SN'),
    const CountryEntry(name: 'Serbia', code: 'RS'),
    const CountryEntry(name: 'Seychelles', code: 'SC'),
    const CountryEntry(name: 'Sierra Leone', code: 'SL'),
    const CountryEntry(name: 'Singapore', code: 'SG'),
    const CountryEntry(name: 'Sint Maarten (Dutch part)', code: 'SX'),
    const CountryEntry(name: 'Slovakia', code: 'SK'),
    const CountryEntry(name: 'Slovenia', code: 'SI'),
    const CountryEntry(name: 'Solomon Islands', code: 'SB'),
    const CountryEntry(name: 'Somalia', code: 'SO'),
    const CountryEntry(name: 'South Africa', code: 'ZA'),
    const CountryEntry(name: 'South Georgia and the South Sandwich Islands', code: 'GS'),
    const CountryEntry(name: 'South Sudan', code: 'SS'),
    const CountryEntry(name: 'Spain', code: 'ES'),
    const CountryEntry(name: 'Sri Lanka', code: 'LK'),
    const CountryEntry(name: 'Sudan', code: 'SD'),
    const CountryEntry(name: 'Suriname', code: 'SR'),
    const CountryEntry(name: 'Svalbard and Jan Mayen', code: 'SJ'),
    const CountryEntry(name: 'Sweden', code: 'SE'),
    const CountryEntry(name: 'Switzerland', code: 'CH'),
    const CountryEntry(name: 'Syrian Arab Republic', code: 'SY'),
    const CountryEntry(name: 'Taiwan, Province of China', code: 'TW'),
    const CountryEntry(name: 'Tajikistan', code: 'TJ'),
    const CountryEntry(name: 'Tanzania, United Republic of', code: 'TZ'),
    const CountryEntry(name: 'Thailand', code: 'TH'),
    const CountryEntry(name: 'Timor-Leste', code: 'TL'),
    const CountryEntry(name: 'Togo', code: 'TG'),
    const CountryEntry(name: 'Tokelau', code: 'TK'),
    const CountryEntry(name: 'Tonga', code: 'TO'),
    const CountryEntry(name: 'Trinidad and Tobago', code: 'TT'),
    const CountryEntry(name: 'Tunisia', code: 'TN'),
    const CountryEntry(name: 'Türkiye', code: 'TR'),
    const CountryEntry(name: 'Turkmenistan', code: 'TM'),
    const CountryEntry(name: 'Turks and Caicos Islands', code: 'TC'),
    const CountryEntry(name: 'Tuvalu', code: 'TV'),
    const CountryEntry(name: 'Uganda', code: 'UG'),
    const CountryEntry(name: 'Ukraine', code: 'UA'),
    const CountryEntry(name: 'United Arab Emirates', code: 'AE'),
    const CountryEntry(name: 'United Kingdom of Great Britain and Northern Ireland', code: 'GB'),
    const CountryEntry(name: 'United States of America', code: 'US'),
    const CountryEntry(name: 'United States Minor Outlying Islands', code: 'UM'),
    const CountryEntry(name: 'Uruguay', code: 'UY'),
    const CountryEntry(name: 'Uzbekistan', code: 'UZ'),
    const CountryEntry(name: 'Vanuatu', code: 'VU'),
    const CountryEntry(name: 'Venezuela, Bolivarian Republic of', code: 'VE'),
    const CountryEntry(name: 'Viet Nam', code: 'VN'),
    const CountryEntry(name: 'Virgin Islands (British)', code: 'VG'),
    const CountryEntry(name: 'Virgin Islands (U.S.)', code: 'VI'),
    const CountryEntry(name: 'Wallis and Futuna', code: 'WF'),
    const CountryEntry(name: 'Western Sahara', code: 'EH'),
    const CountryEntry(name: 'Yemen', code: 'YE'),
    const CountryEntry(name: 'Zambia', code: 'ZM'),
    const CountryEntry(name: 'Zimbabwe', code: 'ZW'),
  ];
}
