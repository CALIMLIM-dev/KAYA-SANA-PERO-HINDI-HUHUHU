# Appendix: Third-Party Components and Licences

Everything KAYA is built on that was not written for KAYA, with its licence. All of it is open source or open data, and none of it requires a fee or restricts a non-commercial or commercial deployment. The two items that require attribution in the product itself, OpenStreetMap and GeoNames, are attributed where they appear.

## Frameworks and runtimes

| Component | Use | Licence |
|---|---|---|
| Flutter and the Dart SDK | The Android app | BSD 3-Clause |
| Laravel 12 | The API and admin panel | MIT |
| Laravel Sanctum | API tokens | MIT |
| Laravel Reverb | WebSocket server (present, switched off in deployment) | MIT |
| PHP 8.2 | Server runtime | PHP License 3.01 |
| MySQL | Database | GPL 2 (server), used unmodified |
| nginx | Web server | BSD 2-Clause |

## Flutter packages (pub.dev)

| Package | Use | Licence |
|---|---|---|
| provider | State | MIT |
| dio | HTTP client | MIT |
| flutter_secure_storage | Token storage | BSD 3-Clause |
| shared_preferences, path_provider, path | Local storage and paths | BSD 3-Clause |
| sqflite | Offline message cache | MIT |
| google_sign_in | Google sign-in | BSD 3-Clause |
| google_fonts | Loads the Inter typeface at runtime | Apache 2.0 |
| flutter_map, latlong2 | Map and pin | BSD 3-Clause |
| geolocator | Device location | MIT |
| flutter_foreground_task | Location sharing service during a hire | MIT |
| flutter_local_notifications | Notifications on the shade | BSD 3-Clause |
| workmanager | Background notification poll | MIT |
| image_picker, file_picker | Photos, documents, resume | Apache 2.0, MIT |
| open_filex, url_launcher | Opening files and links | BSD 3-Clause |
| cached_network_image, flutter_svg | Images and the logo | MIT |
| shimmer, badges, flutter_rating_bar, fl_chart | UI pieces | MIT |
| web_socket_channel, collection | Networking and utilities | BSD 3-Clause |
| cupertino_icons | Icon set | MIT |

## Admin panel (loaded from CDN)

| Component | Licence |
|---|---|
| Tailwind CSS | MIT |
| Chart.js | MIT |
| Lucide icons | ISC |

## Fonts and icons

| Component | Licence |
|---|---|
| Inter (Rasmus Andersson), via google_fonts | SIL Open Font License 1.1 |
| Material Icons (Google), bundled with Flutter | Apache 2.0 |

## Data

| Source | Use | Licence and attribution |
|---|---|---|
| Philippine Standard Geographic Code (Philippine Statistics Authority) | Regions, provinces, cities, municipalities, barangays | Open government data, PSA |
| GeoNames Philippines dataset | Coordinates for the places above | Creative Commons Attribution 4.0. Attribution: "Data from GeoNames (geonames.org), CC BY 4.0" |
| OpenStreetMap tiles | Every map in the app | Open Database License (ODbL). Attribution "OpenStreetMap contributors" is shown on every map, as the OSM tile usage policy requires. The app identifies itself to the tile server with its package name |

## Services

| Service | Data it receives | Terms |
|---|---|---|
| PayMongo | Barya purchases; the buyer pays PayMongo directly | PayMongo merchant terms |
| Google Identity | Google sign-in tokens | Google APIs Terms of Service |
| Resend | Outgoing email (verification and reset codes) | Resend terms |
| Semaphore | Outgoing SMS (phone verification codes) | Semaphore terms |
| BIR ORUS | A business account's TIN is checked by the admin on the public registry | Public government service |

## KAYA's own material

The name, logo, app design, source code, copy, and the legal documents are the authors' own work, produced as coursework for the degree of Bachelor of Science in Information Technology. The logo is an original vector drawing. No stock imagery is used. The repository is not licensed for redistribution.
