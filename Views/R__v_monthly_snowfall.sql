CREATE OR REPLACE VIEW v_monthly_snowfall AS
SELECT
    wd.station_id,
    ws.name AS station_name,
    EXTRACT(YEAR FROM wd.date) AS year,
    EXTRACT(MONTH FROM wd.date) AS month,
    SUM(wd.snowfall) AS monthly_snowfall
FROM weather_data wd
JOIN weather_station ws ON wd.station_id = ws.station_id
GROUP BY
    wd.station_id,
    ws.name,
    year,
    month
ORDER BY wd.station_id, year, month;
