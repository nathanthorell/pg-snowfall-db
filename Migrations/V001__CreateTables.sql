CREATE TABLE weather_station (
    station_id varchar(20) NOT NULL,
    station_name varchar(255) NOT NULL,
    latitude decimal,
    longitude decimal,
    elevation decimal,
    CONSTRAINT pk_weather_station PRIMARY KEY (station_id)
);

CREATE TABLE weather_data (
    id serial NOT NULL,
    station_id varchar(20) NOT NULL,
    date date,
    precipitation decimal,
    precipitation_attributes varchar(50),
    snowfall decimal,
    snowfall_attributes varchar(50),
    snow_depth decimal,
    snow_depth_attributes varchar(50),
    temp_max int,
    temp_max_attributes varchar(50),
    temp_min int,
    temp_min_attributes varchar(50),
    CONSTRAINT pk_weather_data PRIMARY KEY (id),
    CONSTRAINT fk_weather_data_station FOREIGN KEY (station_id) REFERENCES weather_station (station_id),
    CONSTRAINT uq_weather_data_station_id_date UNIQUE (station_id, date)
);
