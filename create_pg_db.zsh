#!/bin/zsh

conf_file="flyway.conf"

if [ -f "$conf_file" ]; then
    flyway_url=$(grep '^flyway.url=' "$conf_file" | cut -d'=' -f2-)
    flyway_user=$(grep '^flyway.user=' "$conf_file" | cut -d'=' -f2-)
    flyway_password=$(grep '^flyway.password=' "$conf_file" | cut -d'=' -f2-)
else
    echo "Configuration file not found: $conf_file"
    exit 1
fi

# Verify required configuration values are present
if [ -z "$flyway_url" ] || [ -z "$flyway_user" ] || [ -z "$flyway_password" ]; then
    echo "Missing configuration values in $conf_file"
    exit 1
fi

# Extract server, port, database from flyway.url
server_port_db=$(echo "$flyway_url" | sed -n 's|jdbc:postgresql://\([^:/]*\):\([0-9]*\)/\([^?]*\)?*|\1 \2 \3|p')

# Assign components to variables
read -r server port db <<<"$server_port_db"

# Set the PostgreSQL from the flyway conf
export PGPASSWORD="$flyway_password"

# SQL query to check if the database exists
check_db_query="SELECT COUNT(*) FROM pg_database WHERE datname = '$db';"
result=$(psql -h "$server" -p "$port" -d "postgres" -U "$flyway_user" -1 -t -c "$check_db_query" | tr -d '()[:space:]')

if [ $? -eq 0 ] && [ "$result" -eq 1 ]; then
    echo "Database '$db' already exists. Dropping..."

    # Check for active sessions and terminate them
    active_sessions=$(psql -h "$server" \
                            -p "$port" \
                            -d "postgres" \
                            -U "$flyway_user" \
                            -t -c "SELECT COUNT(*) FROM pg_stat_activity WHERE datname = '$db';")

    if [ "$active_sessions" -gt 0 ]; then
        echo "Terminating active sessions..."
        psql -h "$server" \
             -p "$port" \
             -d "postgres" \
             -U "$flyway_user" \
             -c "SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE datname = '$db';" \
             > /dev/null 2>&1
    fi

    drop_db_query="DROP DATABASE $db;"
    psql -h "$server" -p "$port" -d "postgres" -U "$flyway_user" -c "$drop_db_query"

    if [ $? -eq 0 ]; then
        echo "Database '$db' dropped successfully."
    else
        echo "Failed to drop the database '$db'."
        exit 1
    fi
fi

create_db_query="CREATE DATABASE $db;"
psql -h "$server" -p "$port" -d "postgres" -U "$flyway_user" -c "$create_db_query"

if [ $? -eq 0 ]; then
    echo "Database created successfully."
else
    echo "Failed to create the database."
fi
