# PostgreSQL Snowfall Database

Basic PostgreSQL database to store snowfall data from [NOAA NCEI](https://www.ncei.noaa.gov/).  Uses Flyway for migrations.

## Create Local PostgreSQL Database

- For local migration testing you will need a local Postgres DB instance
- Docker Example:

    ```bash
    docker run --name postgresdb -e POSTGRES_PASSWORD=YOUR_SECRET_PASSWORD_HERE -d -p 5432:5432 -v postgres_data:/var/lib/postgresql/data postgres:16
    ```

- Flyway requires a database before it can connect.  To speed up this process for development iteration, I've added `create_pg_db.zsh` which parses the flyway.conf file and pulls the server connection information.  It then connects and checks if the database exists, if so it drops the database then creates a new empty one.

## CI Migrations

Migrations are structured for use with FlywayDB

- For local testing, you will need FlywayDB Community Edition installed
  - [Download FlywayDB](https://flywaydb.org/download/community)

- For local migration testing edit the `flyway.conf` file in this project's root directory with your local connection configuration.

- Then run `flyway migrate`
