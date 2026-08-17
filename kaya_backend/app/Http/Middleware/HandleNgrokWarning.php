<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class HandleNgrokWarning
{
    /**
     * Handle an incoming request.
     *
     * Adds ngrok-skip-browser-warning header to bypass ngrok's interstitial warning page
     * which can break sessions and CSRF tokens.
     *
     * @param  Closure(Request): (Response)  $next
     */
    public function handle(Request $request, Closure $next): Response
    {
        // Add header to skip ngrok warning
        $request->headers->set('ngrok-skip-browser-warning', 'true');
        
        $response = $next($request);
        
        // Also add to response for subsequent requests
        if ($response instanceof Response) {
            $response->headers->set('ngrok-skip-browser-warning', 'true');
        }
        
        return $response;
    }
}
