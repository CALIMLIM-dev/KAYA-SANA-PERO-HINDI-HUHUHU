<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Default Filesystem Disk
    |--------------------------------------------------------------------------
    |
    | Here you may specify the default filesystem disk that should be used
    | by the framework. The "local" disk, as well as a variety of cloud
    | based disks are available to your application for file storage.
    |
    */

    'default' => env('FILESYSTEM_DISK', 'local'),

    /*
    |--------------------------------------------------------------------------
    | Which disk each kind of upload goes to
    |--------------------------------------------------------------------------
    |
    | KAYA stores two very different kinds of file, and they must not share a
    | disk:
    |
    |   media     — profile photos, job photos, employer logos, certificate and
    |               licence scans. Served straight to the app by URL.
    |   documents — government IDs, liveness selfies, resumes. Never served by
    |               URL; every read goes through a controller that checks who is
    |               asking. A resume carries a phone number, a home address and a
    |               full employment history.
    |
    | These are indirections on purpose. The disk names were hardcoded as
    | 'public' and 'local' at more than twenty call sites, which meant setting
    | FILESYSTEM_DISK=s3 changed nothing at all — every upload still went to the
    | container filesystem and still died on the next redeploy. Moving to object
    | storage is now two environment variables instead of an edit to twenty
    | controllers.
    |
    | Note the asymmetry when you switch these to S3: media goes to 's3', but
    | documents must go to 's3_private' below. Pointing documents at the public
    | bucket would undo the whole reason the private disk exists.
    |
    */

    'media' => env('MEDIA_DISK', 'public'),

    'documents' => env('DOCUMENT_DISK', 'local'),

    /*
    |--------------------------------------------------------------------------
    | Filesystem Disks
    |--------------------------------------------------------------------------
    |
    | Below you may configure as many filesystem disks as necessary, and you
    | may even configure multiple disks for the same driver. Examples for
    | most supported storage drivers are configured here for reference.
    |
    | Supported drivers: "local", "ftp", "sftp", "s3"
    |
    */

    'disks' => [

        'local' => [
            'driver' => 'local',
            'root' => storage_path('app/private'),
            'serve' => true,
            'throw' => false,
            'report' => false,
        ],

        'public' => [
            'driver' => 'local',
            'root' => storage_path('app/public'),
            'url' => rtrim(env('APP_URL', 'http://localhost'), '/').'/storage',
            'visibility' => 'public',
            'throw' => false,
            'report' => false,
        ],

        's3' => [
            'driver' => 's3',
            'key' => env('AWS_ACCESS_KEY_ID'),
            'secret' => env('AWS_SECRET_ACCESS_KEY'),
            'region' => env('AWS_DEFAULT_REGION'),
            'bucket' => env('AWS_BUCKET'),
            'url' => env('AWS_URL'),
            'endpoint' => env('AWS_ENDPOINT'),
            'use_path_style_endpoint' => env('AWS_USE_PATH_STYLE_ENDPOINT', false),
            'throw' => false,
            'report' => false,
        ],

        /*
            The same bucket, but nothing written here is world-readable.

            'throw' is true, unlike every disk above it. A silent false from a
            failed write is survivable for a profile photo; for a government ID
            it means the verification record points at a file that does not
            exist, and nobody finds out until an admin opens the review screen.
            Fail loudly instead.
        */
        's3_private' => [
            'driver' => 's3',
            'key' => env('AWS_ACCESS_KEY_ID'),
            'secret' => env('AWS_SECRET_ACCESS_KEY'),
            'region' => env('AWS_DEFAULT_REGION'),
            'bucket' => env('AWS_BUCKET'),
            'endpoint' => env('AWS_ENDPOINT'),
            'use_path_style_endpoint' => env('AWS_USE_PATH_STYLE_ENDPOINT', false),
            'visibility' => 'private',
            'throw' => true,
            'report' => false,
        ],

    ],

    /*
    |--------------------------------------------------------------------------
    | Symbolic Links
    |--------------------------------------------------------------------------
    |
    | Here you may configure the symbolic links that will be created when the
    | `storage:link` Artisan command is executed. The array keys should be
    | the locations of the links and the values should be their targets.
    |
    */

    'links' => [
        public_path('storage') => storage_path('app/public'),
    ],

];
