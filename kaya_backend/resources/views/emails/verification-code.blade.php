@extends('emails.layout')

@section('title', 'Your KAYA code')
@section('preheader', "Your KAYA code is {$code}. It expires in 10 minutes.")

@section('content')
    <h1 style="margin:0 0 16px; font-size:22px; line-height:1.3; font-weight:700; color:#111827;">Confirm your {{ $subjectOfVerification }}</h1>
    <p style="margin:0 0 8px; font-size:15px; line-height:1.6; color:#111827;">Hi {{ $userName }},</p>
    <p style="margin:0 0 20px; font-size:15px; line-height:1.6; color:#374151;">Enter this code in the KAYA app to confirm your {{ $subjectOfVerification }}.</p>
    @include('emails.partials.code', ['code' => $code, 'minutes' => 10])
@endsection
