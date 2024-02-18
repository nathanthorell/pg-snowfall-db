#!/bin/zsh

if [ -f ".env" ]; then
    source .env
else
    echo "Error: .env file not found."
    exit 1
fi

# Read environment variables
PG_HOST=$PG_HOST
PG_PORT=$PG_PORT
PG_DB=$PG_DB
FLYWAY_USER=$FLYWAY_USER
FLYWAY_PASSWORD=$FLYWAY_PASSWORD

# Verify required environment variables are present
if [ -z "$PG_HOST" ] || [ -z "$PG_PORT" ] || [ -z "$PG_DB" ] || [ -z "$FLYWAY_USER" ] || [ -z "$FLYWAY_PASSWORD" ]; then
    echo "Missing required environment variables"
    exit 1
fi

db_url="jdbc:postgresql://$PG_HOST:$PG_PORT/$PG_DB"

# Set the PostgreSQL from the flyway conf
export PGPASSWORD="$FLYWAY_PASSWORD"

# SQL query to check if the database exists
check_db_query="SELECT COUNT(*) FROM pg_database WHERE datname = '$PG_DB';"
result=$(psql -h "$PG_HOST" -p "$PG_PORT" -d "postgres" -U "$FLYWAY_USER" -1 -t -c "$check_db_query" | tr -d '()[:space:]')

if [ $? -eq 0 ] && [ "$result" -eq 1 ]; then
    echo "Database '$PG_DB' already exists. Dropping..."

    # Check for active sessions and terminate them
    active_sessions=$(psql -h "$PG_HOST" \
                            -p "$PG_PORT" \
                            -d "postgres" \
                            -U "$FLYWAY_USER" \
                            -t -c "SELECT COUNT(*) FROM pg_stat_activity WHERE datname = '$PG_DB';")

    if [ "$active_sessions" -gt 0 ]; then
        echo "Terminating active sessions..."
        psql -h "$PG_HOST" \
             -p "$PG_PORT" \
             -d "postgres" \
             -U "$FLYWAY_USER" \
             -c "SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE datname = '$PG_DB';" \
             > /dev/null 2>&1
    fi

    drop_db_query="DROP DATABASE $PG_DB;"
    psql -h "$PG_HOST" -p "$PG_PORT" -d "postgres" -U "$FLYWAY_USER" -c "$drop_db_query"

    if [ $? -eq 0 ]; then
        echo "Database '$PG_DB' dropped successfully."
    else
        echo "Failed to drop the database '$PG_DB'."
        exit 1
    fi
fi

create_db_query="CREATE DATABASE $PG_DB;"
psql -h "$PG_HOST" -p "$PG_PORT" -d "postgres" -U "$FLYWAY_USER" -c "$create_db_query"

if [ $? -eq 0 ]; then
    echo "Database created successfully."
else
    echo "Failed to create the database."
fi
