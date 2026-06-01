from pydantic import BaseModel

class CountryBase(BaseModel):
    country_name: str | None = None
    country_code: str | None = None
    year: int | None = None
    population: str | None = None

class CountryCreate(CountryBase):
    pass

class Country(CountryBase):
    id: int

    class Config:
        from_attributes = True