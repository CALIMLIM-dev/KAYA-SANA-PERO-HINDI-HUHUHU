<?php
/*
    Routes bound to a controller method that does not exist.

    Laravel does not check this until the route is hit, so a typo or a
    method deleted in a refactor sits there looking fine and 500s the
    first time a user reaches it. Reflection settles it in one pass.
*/
$root = dirname(__DIR__, 2) . '/kaya_backend';
require $root . '/vendor/autoload.php';
$app = require $root . '/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();

$bad = 0;
foreach (app('router')->getRoutes() as $route) {
    $action = $route->getActionName();
    if (!str_contains($action, '@')) continue;
    [$class, $method] = explode('@', $action, 2);
    if (!class_exists($class)) {
        printf("  MISSING CLASS   %-38s %s\n", $route->uri(), $class);
        $bad++;
        continue;
    }
    if (!method_exists($class, $method)) {
        printf("  MISSING METHOD  %-38s %s::%s\n", $route->uri(), class_basename($class), $method);
        $bad++;
    }
}
echo $bad === 0 ? "  none - every route resolves\n" : "\n  $bad broken route(s)\n";
