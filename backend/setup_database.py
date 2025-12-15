#!/usr/bin/env python3
"""
Database Setup Script - Runs migrations and creates admin user
"""
import sys
import subprocess
from pathlib import Path


def run_command(cmd, description):
    """Run a shell command and handle errors"""
    print(f"\n[STEP] {description}...")
    print(f"[CMD] {' '.join(cmd)}")

    result = subprocess.run(cmd, capture_output=True, text=True)

    if result.returncode != 0:
        print(f"[ERROR] {description} failed!")
        print(f"STDOUT: {result.stdout}")
        print(f"STDERR: {result.stderr}")
        return False

    print(f"[OK] {description} completed successfully")
    if result.stdout:
        print(result.stdout)

    return True


def main():
    print("=" * 60)
    print("DATABASE SETUP - Boleylapanel")
    print("=" * 60)

    # Check if alembic.ini exists
    if not Path("alembic.ini").exists():
        print("[ERROR] alembic.ini not found!")
        print("Make sure you're running this from the backend directory")
        sys.exit(1)

    # Step 1: Check current migration status
    print("\n" + "=" * 60)
    print("STEP 1: Checking current migration status")
    print("=" * 60)
    run_command(["alembic", "current"], "Check current version")

    # Step 2: Run migrations
    print("\n" + "=" * 60)
    print("STEP 2: Running database migrations")
    print("=" * 60)

    if not run_command(["alembic", "upgrade", "head"], "Run migrations"):
        print("\n[FATAL] Migration failed! Check database connection.")
        sys.exit(1)

    # Step 3: Verify migrations
    print("\n" + "=" * 60)
    print("STEP 3: Verifying migrations")
    print("=" * 60)
    run_command(["alembic", "current"], "Verify current version")

    # Step 4: Create admin user (if script exists)
    admin_script = Path("create_admin.py")
    if admin_script.exists():
        print("\n" + "=" * 60)
        print("STEP 4: Creating admin user")
        print("=" * 60)

        if not run_command([sys.executable, "create_admin.py"], "Create admin user"):
            print("\n[WARN] Admin user creation failed (might already exist)")

    print("\n" + "=" * 60)
    print("DATABASE SETUP COMPLETED!")
    print("=" * 60)
    print("\nNext steps:")
    print("1. Start the backend: uvicorn app.main:app --reload")
    print("2. Access the panel: http://localhost:8000")
    print("3. Login with: username=admin, password=admin")
    print("=" * 60)


if __name__ == "__main__":
    main()
