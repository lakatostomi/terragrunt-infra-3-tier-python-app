from sqlalchemy import create_engine
from sqlalchemy.engine.url import URL
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
import sys
sys.path.append('.')
from config import settings

def create_cloudsql_url():
    print(settings.model_dump())
    return f"postgresql+pg8000://{settings.POSTGRES_USER}:{settings.POSTGRES_PASSWORD}@/{settings.TABLE_ID}?unix_sock={settings.INSTANCE_UNIX_SOCKET}/.s.PGSQL.5432"

def create_localdb_url():
    return f"postgresql://{settings.POSTGRES_USER}:{settings.POSTGRES_PASSWORD}@{settings.LOCAL_POSTGRES_HOST}/{settings.TABLE_ID}"


DATABASE_URL = create_localdb_url() if not settings.INSTANCE_UNIX_SOCKET  else create_cloudsql_url()

engine = create_engine(DATABASE_URL)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()
