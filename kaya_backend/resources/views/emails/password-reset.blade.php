<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            background-color: #F2F4F5;
            margin: 0;
            padding: 20px;
        }
        .container {
            max-width: 600px;
            margin: 0 auto;
            background-color: #FFFFFF;
            border-radius: 16px;
            overflow: hidden;
            box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
        }
        .header {
            background-color: #0B3D4C;
            padding: 32px 24px;
            text-align: center;
        }
        .header h1 {
            color: #FFFFFF;
            margin: 0;
            font-size: 28px;
            font-weight: 700;
        }
        .content {
            padding: 32px 24px;
        }
        .greeting {
            font-size: 18px;
            font-weight: 600;
            color: #1A1A1A;
            margin-bottom: 16px;
        }
        .message {
            font-size: 14px;
            color: #5C5C5C;
            line-height: 1.6;
            margin-bottom: 24px;
        }
        .code-box {
            background-color: #F2F4F5;
            border: 2px solid #0B3D4C;
            border-radius: 12px;
            padding: 24px;
            text-align: center;
            margin: 24px 0;
        }
        .code-label {
            font-size: 12px;
            color: #5C5C5C;
            text-transform: uppercase;
            letter-spacing: 1px;
            margin-bottom: 8px;
        }
        .code {
            font-size: 36px;
            font-weight: 700;
            color: #0B3D4C;
            letter-spacing: 8px;
            font-family: 'Courier New', monospace;
        }
        .expiry {
            font-size: 13px;
            color: #E0A106;
            background-color: #FFF9E6;
            padding: 12px;
            border-radius: 8px;
            margin: 24px 0;
            text-align: center;
        }
        .warning {
            font-size: 13px;
            color: #5C5C5C;
            background-color: #F2F4F5;
            padding: 16px;
            border-radius: 8px;
            border-left: 4px solid #D9534F;
            margin-top: 24px;
        }
        .footer {
            background-color: #F2F4F5;
            padding: 24px;
            text-align: center;
            font-size: 12px;
            color: #5C5C5C;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>KAYA</h1>
        </div>
        
        <div class="content">
            <div class="greeting">Hello{{ $userName ? ', ' . $userName : '' }}!</div>
            
            <div class="message">
                We received a request to reset your password for your KAYA account. Use the verification code below to reset your password:
            </div>
            
            <div class="code-box">
                <div class="code-label">Your Reset Code</div>
                <div class="code">{{ $resetCode }}</div>
            </div>
            
            <div class="expiry">
                ⏰ This code will expire in 15 minutes
            </div>
            
            <div class="message">
                Enter this code in the KAYA app to create a new password. If you didn't request a password reset, you can safely ignore this email.
            </div>
            
            <div class="warning">
                <strong>Security Tip:</strong> Never share this code with anyone. KAYA staff will never ask for your reset code.
            </div>
        </div>
        
        <div class="footer">
            <p>© {{ date('Y') }} KAYA. All rights reserved.</p>
            <p>This is an automated message, please do not reply to this email.</p>
        </div>
    </div>
</body>
</html>
