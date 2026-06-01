from .database import Base
from sqlalchemy import Column, Integer, String

class Country(Base):
    __tablename__ = "countries"

    id = Column(Integer, primary_key=True)
    country_name = Column(String)
    country_code = Column(String, index=True)
    year = Column(Integer)
    population = Column(String)