<?php
$f="test/pin_location_match_test.dart";
$s=str_replace("\r\n","\n",file_get_contents($f));

$cut = strpos($s, "\n  /*\n      The label has to follow the pin when the pin is more specific.");
if ($cut === false) { echo "MISS cut\n"; exit(1); }
$s = rtrim(substr($s, 0, $cut), "\n");

$block = "\n\n  /*\n"
 . "      The label has to follow the pin when the pin is more specific.\n\n"
 . "      isSamePlace stops the app asking \"are you sure?\" for a pin dropped\n"
 . "      inside the city you chose. That is right, but the caller took \"same\n"
 . "      place\" to mean \"nothing to update\": it stored the coordinates and left\n"
 . "      the field reading \"Urdaneta City\" after the user pinned a barangay of\n"
 . "      it. The pin had registered and nothing on screen said so, so pinning\n"
 . "      looked like it did nothing — the text only ever changed through the\n"
 . "      \"Use pinned\" dialog, which fires just for pins in another city.\n"
 . "  */\n"
 . "  test('a barangay inside the chosen city is a sharper answer', () {\n"
 . "    expect(\n"
 . "      isSharperThan(nancamaliran, urdaneta),\n"
 . "      isTrue,\n"
 . "      reason: 'Pinning a barangay after choosing the city should upgrade '\n"
 . "          'the label, not be discarded as \"same place\".',\n"
 . "    );\n"
 . "  });\n\n"
 . "  test('a different barangay of the same city is a sharper answer', () {\n"
 . "    expect(isSharperThan(poblacion, nancamaliran), isTrue);\n"
 . "  });\n\n"
 . "  /*\n"
 . "      The direction that must not apply.\n\n"
 . "      /locations/nearest can answer with the city when it has no barangay\n"
 . "      for that spot. Adopting it over a barangay the user picked themselves\n"
 . "      would throw away detail they chose — the pin would make their address\n"
 . "      vaguer, which is the opposite of what dropping one is for.\n"
 . "  */\n"
 . "  test('a chosen barangay survives a pin that resolves to the city', () {\n"
 . "    expect(isSharperThan(urdaneta, nancamaliran), isFalse);\n"
 . "  });\n\n"
 . "  test('the same place is not an upgrade', () {\n"
 . "    expect(isSharperThan(urdaneta, urdaneta), isFalse);\n"
 . "  });\n\n"
 . "  test('another city entirely is not an upgrade', () {\n"
 . "    expect(\n"
 . "      isSharperThan(binalonan, urdaneta),\n"
 . "      isFalse,\n"
 . "      reason: 'That is a genuine conflict and belongs in the confirm '\n"
 . "          'dialog, not adopted silently.',\n"
 . "    );\n"
 . "  });\n\n"
 . "  test('a barangay of another city is not an upgrade', () {\n"
 . "    expect(isSharperThan(bued, urdaneta), isFalse);\n"
 . "  });\n}\n";

if (substr($s, -1) !== '}') { echo "MISS tail\n"; exit(1); }
$s = substr($s, 0, -1) . $block;
file_put_contents($f, str_replace("\n","\r\n",$s));
echo "written\n";
