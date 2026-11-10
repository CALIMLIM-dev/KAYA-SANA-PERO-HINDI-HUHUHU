@extends('emails.layout')

@section('title', $heading)
@section('preheader', $body)

@section('content')
    <h1 style="margin:0 0 16px; font-size:22px; line-height:1.3; font-weight:700; color:#111827;">{{ $heading }}</h1>
    <p style="margin:0 0 8px; font-size:15px; line-height:1.6; color:#111827;">Hi {{ $userName }},</p>
    <p style="margin:0 0 20px; font-size:15px; line-height:1.6; color:#374151;">{{ $body }}</p>
    <p style="margin:0 0 6px; font-size:14px; line-height:1.6; color:#374151;">When: {{ $when }}</p>
    <p style="margin:0; padding-top:20px; margin-top:20px; border-top:1px solid #E6E9F0; font-size:14px; line-height:1.6; color:#374151;">
        <strong>Not you?</strong> Reset your password from the KAYA sign-in screen right away, then open Help and support in the app and tell us.
    </p>
@endsection
