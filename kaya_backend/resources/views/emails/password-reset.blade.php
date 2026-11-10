@extends('emails.layout')

@section('title', 'Reset your KAYA password')
@section('preheader', "Your KAYA password reset code is {$resetCode}. It expires in 15 minutes.")

@section('content')
    <h1 style="margin:0 0 16px; font-size:22px; line-height:1.3; font-weight:700; color:#111827;">Reset your password</h1>
    <p style="margin:0 0 8px; font-size:15px; line-height:1.6; color:#111827;">Hi {{ $userName }},</p>
    <p style="margin:0 0 20px; font-size:15px; line-height:1.6; color:#374151;">Someone asked to reset the password on your KAYA account. Enter this code in the app to choose a new one.</p>
    @include('emails.partials.code', ['code' => $resetCode, 'minutes' => 15])
@endsection
