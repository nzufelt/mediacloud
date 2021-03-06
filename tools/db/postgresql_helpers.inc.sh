#
# PostgreSQL helpers to take care of utility path differences among various
# platforms and provide commonly used variables to "create database" / "drop
# database" scripts.
#
# This script not intended to be run directly.
#


# XPath selectors for databases to create / drop
declare -a DB_CREDENTIALS_SELECTORS=(

    # first entry in mediawords.yml is the production database
    "//database[1]"

    # test database
    "//database[label='test']"

)


# Returns true (0) if the host is localhost; used for skipping the "--host"
# parameter when creating databases on local machines (because otherwise user
# gets asked for a password)
function _host_is_localhost {
    local db_host="$1"

    if [ "$db_host" == "localhost" ] || [ "$db_host" == "127.0.0.1" ]; then
        return 0    # "true" in Bash
    else
        return 1    # "false" in Bash
    fi
}


# "psql" shorthand
function run_psql {
    local db_host="$1"
    local sql_command="$2"
    local db_name="$3"

    PSQL_OPTIONS="-q -t"
    if ! _host_is_localhost "$db_host"; then
        PSQL_OPTIONS="$PSQL_OPTIONS --host=$db_host"
    fi

    if [ `uname` == 'Darwin' ]; then
        # Mac OS X
        local run_psql_result=`/usr/local/bin/psql $PSQL_OPTIONS "$db_name" --command="$sql_command" 2>&1 || echo `
    else
        # assume Ubuntu
        local run_psql_result=`sudo su -l postgres -c "psql $PSQL_OPTIONS "$db_name" --command=\" $sql_command \" 2>&1 " || echo `
    fi
    echo "$run_psql_result"
}

# "dropdb" shorthand
function run_dropdb {
    local db_host="$1"
    local db_name="$2"

    dropdb_sql=$( cat <<EOF
        DROP DATABASE $db_name
EOF
)
    MAX_STORIES=1000000


    NUM_STORIES=`run_psql "$db_credentials_host" "select count(*) from ( select 1 from stories limit $MAX_STORIES) q" "$db_name"`;

    if [ $NUM_STORIES -eq $MAX_STORIES ]; then
        echo "refusing to drop database with >= $MAX_STORIES stories" 1>&2;
        set -e;
        exit 1;
    fi

    run_dropdb_result=`run_psql "$db_credentials_host" "$dropdb_sql" "$db_name"`

    echo "$run_dropdb_result"
}

# "createdb" shorthand
function run_createdb {
    local db_host="$1"
    local db_name="$2"
    local db_owner="$3"

    createdb_sql=$( cat <<EOF

        CREATE DATABASE $db_name WITH

        OWNER = $db_owner

        -- "template1" is preinitialized with "LATIN1" encoding on some systems and
        -- thus doesn't work, so using a cleaner "template0":
        TEMPLATE = template0

        -- Force UTF-8 encoding because some PostgreSQL installations default to
        -- "LATIN1" and then LENGTH() and similar functions don't work correctly
        ENCODING = 'UTF-8'
        LC_COLLATE = 'en_US.UTF-8'
        LC_CTYPE = 'en_US.UTF-8'
EOF
)

    run_createdb_result=`run_psql "$db_credentials_host" "$createdb_sql" postgres`

    echo "$run_createdb_result"
}
