import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base

DATABASE_URL = os.getenv("DATABASE_URL")

enable_db = bool(DATABASE_URL)

engine = create_engine(DATABASE_URL, pool_pre_ping=True) if enable_db else None
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine) if enable_db else None
Base = declarative_base()
