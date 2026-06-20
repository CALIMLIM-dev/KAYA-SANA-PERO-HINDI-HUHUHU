# KAYA Setup Instructions

## Step 1: Start MySQL Server

1. Open XAMPP Control Panel
2. Start **MySQL** module
3. Click **Admin** to open phpMyAdmin

## Step 2: Create Database

**Option A: Using phpMyAdmin**
1. Open phpMyAdmin (http://localhost/phpmyadmin)
2. Click "SQL" tab
3. Copy and paste content from `setup_database.sql`
4. Click "Go"

**Option B: Using MySQL Command Line**
1. Open XAMPP Shell (or CMD)
2. Navigate to MySQL bin folder:
   ```
   cd C:\xampp\mysql\bin
   ```
3. Run:
   ```
   mysql -u root -e "CREATE DATABASE IF NOT EXISTS kaya_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
   ```

## Step 3: Configure Laravel

The database is now ready for Laravel migrations.

Database name: `kaya_db`
Host: `127.0.0.1`
Port: `3306`
User: `root`
Password: (empty by default in XAMPP)
