
import json
import logging
from db_module import repository as repository 
from db_module import schemas as schemas

logger = logging.getLogger('uvicorn.error')

country_list = []

def init_data():
  global country_list
  with open("population_data_jsonline.json", "r") as user_file:
    logger.info("Initialzing data from file...")
    country_list = []
    for x in user_file:
        parsed = json.loads(x)
        country = schemas.CountryCreate(country_name=parsed['country_name'], country_code=parsed['country_code'], year=parsed['year'], population=f"{parsed['population']}")
        country_list.append(country)
    logger.info(f"...file reading finished, number of rows: {len(country_list)}")
    
