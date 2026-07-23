import from jaclang.byllm.lib { Model }


obj City {
    has name: str,
        population: int,
        country: str;
}

obj Weather {
    has temperature: float,
        condition: str;
}

obj Forecast {
    has city: City,
        weather: Weather;
}

obj ForecastRequest {
    has city_name: str,
        country_code: str;
}

obj Person{
    has name: str;
}


def inquire(city:City, person: Person, Forecast) -> Forecast by llm();
