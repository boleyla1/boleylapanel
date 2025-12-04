#!/usr/bin/env python3
"""
Database initialization script.
Creates all tables defined in models.

Usage:
    python -m app.scripts.init_db
"""

import sys
from pathlib import Path

# Add backend directory to path
backend_dir = Path(__file__).parent.parent.parent
sys.path.insert(0, str(backend_dir))

from app.db.database import engine
from app.db.base import Base

# Import all models to register them with Base
from app.models import User, Server, Config, AuditLog


def init_database():
    """Create all database tables"""

    print("=" * 60)
    print("🗄️  Initializing BoleylaPanel Database")
    print("=" * 60)

    try:
        print("\n[1/2] Creating tables...")
        Base.metadata.create_all(bind=engine)
        print("✅ Tables created successfully!")

        print("\n[2/2] Verifying tables...")
        tables = Base.metadata.tables.keys()
        for table in tables:
            print(f"   ✓ {table}")

        print("\n" + "=" * 60)
        print(f"🎉 Database initialized successfully!")
        print(f"📊 Total tables: {len(tables)}")
        print("=" * 60)

    except Exception as e:
        print(f"\n❌ Error initializing database: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    init_database()
