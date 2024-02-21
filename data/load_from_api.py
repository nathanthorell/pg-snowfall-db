import requests
import psycopg2
import os
import json
from dotenv import load_dotenv


def get_api_data(station_id, start_date, end_date):
    base_url = (
        "https://www.ncei.noaa.gov/access/services/data/v1?dataset=daily-summaries"
    )
    api_url = (
        f"{base_url}&startDate={start_date}&endDate={end_date}&stations={station_id}"
        f"&dataTypes=SNOW,PRCP,SNWD,TAVG,TMAX,TMIN&includeStationLocation=1"
        f"&includeStationName=true&includeAttributes=true&format=json"
    )

    response = requests.get(api_url)
    if response.status_code == 200:
        data = response.json()
        print("Data received")
        return data
    else:
        print(f"Error: {response.status_code} - {response.text}")


def parse_numeric(value):
    return float(value) if value is not None else None


def load_sql_data(conn_str: str, data: list):
    try:
        conn = psycopg2.connect(conn_str)
        cur = conn.cursor()

        for row in data:
            cur.execute(
                """
                INSERT INTO weather_data (
                    station_id, date,
                    precipitation, precipitation_attributes,
                    snowfall, snowfall_attributes,
                    snow_depth, snow_depth_attributes,
                    temp_max, temp_max_attributes,
                    temp_min, temp_min_attributes
                )
                VALUES (
                    %s, %s, %s, %s, %s, %s,
                     %s, %s, %s, %s, %s, %s
                )
                ON CONFLICT (station_id, date) DO NOTHING
            """,
                (
                    row["station_id"],
                    row["date"],
                    parse_numeric(row["precipitation"]),
                    row["precipitation_attributes"],
                    parse_numeric(row["snowfall"]),
                    row["snowfall_attributes"],
                    parse_numeric(row["snow_depth"]),
                    row["snow_depth_attributes"],
                    parse_numeric(row["temp_max"]),
                    row["temp_max_attributes"],
                    parse_numeric(row["temp_min"]),
                    row["temp_min_attributes"],
                ),
            )

        # Commit the changes to the database
        conn.commit()

        print("Data successfully inserted into the 'weather_data' table.")

    except psycopg2.Error as e:
        print("Error inserting data into the database:", e)

    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()


def load_sql_station(conn_str: str, station_info: dict):
    try:
        conn = psycopg2.connect(conn_str)
        cur = conn.cursor()

        select_query = "SELECT * FROM weather_station WHERE station_id = %s;"
        cur.execute(select_query, (station_info["station_id"],))
        existing_record = cur.fetchone()

        if not existing_record:
            insert_query = """
            INSERT INTO weather_station (station_id, station_name, latitude, longitude, elevation)
            VALUES (%s, %s, %s, %s, %s);
            """

            cur.execute(
                insert_query,
                (
                    station_info["station_id"],
                    station_info["station_name"],
                    station_info["latitude"],
                    station_info["longitude"],
                    station_info["elevation"],
                ),
            )
            conn.commit()
            print("Data successfully inserted into the 'weather_station' table.")
        else:
            print(f"Station ID {station_info['station_id']} already exists.")

    except psycopg2.Error as e:
        print("Error interacting with the database:", e)

    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()


def main():
    load_dotenv()
    script_dir = os.path.dirname(__file__)
    config_path = os.path.join(script_dir, "load_data_config.json")
    with open(config_path, "r") as f:
        config = json.load(f)

    conn_string = (
        f"host={os.getenv('PG_HOST')} port={os.getenv('PG_PORT')} "
        f"dbname={os.getenv('PG_DB')} "
        f"user={os.getenv('FLYWAY_USER')} "
        f"password={os.getenv('FLYWAY_PASSWORD')}"
        f""
    )

    stations = config["stations"]
    start_date = config["start_date"]
    end_date = config["end_date"]

    for station in stations:
        curr_rows = []
        data = get_api_data(station, start_date, end_date)
        station_info = {
            "station_id": station,
            "station_name": data[0]["NAME"],
            "latitude": data[0]["LATITUDE"],
            "longitude": data[0]["LONGITUDE"],
            "elevation": data[0]["ELEVATION"],
        }
        load_sql_station(conn_str=conn_string, station_info=station_info)

        for row in data:
            mapped_dict = {
                "station_id": row["STATION"],
                "date": row["DATE"],
                "precipitation": row.get("PRCP", None),
                "precipitation_attributes": row.get("PRCP_ATTRIBUTES", None),
                "snowfall": row.get("SNOW", None),
                "snowfall_attributes": row.get("SNOW_ATTRIBUTES", None),
                "snow_depth": row.get("SNWD", None),
                "snow_depth_attributes": row.get("SNWD_ATTRIBUTES", None),
                "temp_max": row.get("TMAX", None),
                "temp_max_attributes": row.get("TMAX_ATTRIBUTES", None),
                "temp_min": row.get("TMIN", None),
                "temp_min_attributes": row.get("TMIN_ATTRIBUTES", None),
            }
            curr_rows.append(mapped_dict)
        load_sql_data(conn_str=conn_string, data=curr_rows)


if __name__ == "__main__":
    main()
