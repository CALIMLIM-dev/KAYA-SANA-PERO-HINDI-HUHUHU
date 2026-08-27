#!/usr/bin/env bash
# Routes registered in app_router.dart that nothing ever navigates to.
#
# Reachability is transitive: a route can be reached directly
# (Navigator.pushNamed(context, AppRouter.x) or the raw '/x' string) or
# through one of the router's own to* helpers. Checking only the direct
# form reports every helper-reached route as dead, which is wrong for
# about a third of them.
set -u
cd "$(dirname "$0")/../../kaya_app/lib" || exit 1
R=core/navigation/app_router.dart

grep -oP "static const String \K\w+(?= = ')" "$R" | while read -r name; do
  path=$(grep -oP "static const String $name = '\K[^']+" "$R")

  direct=$(grep -rn --include=*.dart -e "AppRouter\.$name\b" -e "'$path'" . \
           | grep -v "$R" | grep -v 'core/routes/' | wc -l)

  # Helpers in the router whose body pushes this route.
  helpers=$(grep -B4 "context, $name\b" "$R" \
            | grep -oP "static void \K\w+" | sort -u)

  via=0
  for h in $helpers; do
    n=$(grep -rn --include=*.dart "AppRouter\.$h\b" . | grep -v "$R" | wc -l)
    via=$((via + n))
  done

  [ $((direct + via)) -eq 0 ] && printf "  %-26s %s\n" "$name" "$path"
done
exit 0
