#!/bin/bash

########################################################
# Created by: Umesh Rana (based on Roshan Thapa’s concept)
# Date: Oct 2025
# Version: 2.0
# Purpose: Bulk MySQL User Creation Automation Script
# Supports: QA, PROD, BOTH environments
# Input: CSV file with columns -> username,role
########################################################

source .env   # load environment variables (DB creds, hosts, etc.)

csv_file=$1   # first argument: path to CSV file (username,role)

#-------------------- Helper Functions ---------------------#

# Validate CSV file existence
function check_csv() {
    if [[ ! -f "$csv_file" ]]; then
        echo "❌ CSV file not found: $csv_file"
        exit 1
    fi
}

# Create MySQL user
function mysql_create() {
    local host=$1
    local admin_user=$2
    local password=$3
    local port=$4
    local new_user=$5
    local role=$6
    local pass_storage=$7
    local error_log=$8

    local check_user="SELECT user FROM mysql.user WHERE user='$new_user';"
    local existing_user=$(mysql -h "$host" -P "$port" -u "$admin_user" -p"$password" -N -B -e "$check_user" 2>>"$error_log")

    if [[ "$existing_user" == "$new_user" ]]; then
        echo "⚠️  User '$new_user' already exists on $host"
    else
        # Generate a random secure password
        local gen_pass=$(openssl rand -base64 12)
        local create_stmt="CREATE USER '$new_user'@'%' IDENTIFIED BY '$gen_pass';
                           GRANT '$role' TO '$new_user'@'%';
                           SET DEFAULT ROLE ALL TO '$new_user'@'%';
                           ALTER USER '$new_user'@'%' WITH MAX_USER_CONNECTIONS 20 PASSWORD EXPIRE INTERVAL 180 DAY;"

        mysql -h "$host" -P "$port" -u "$admin_user" -p"$password" -e "$create_stmt" 1>>"$pass_storage" 2>>"$error_log"

        if [[ $? -eq 0 ]]; then
            echo "User '$new_user' created successfully on $host"
            echo "$new_user,$role,$gen_pass,$host" >> "$pass_storage"
        else
            echo "Failed to create user '$new_user' on $host (see $error_log)"
        fi
    fi
}

#-------------------- QA Environment ---------------------#
function create_qa_users() {
    local qa_hosts=(${QA_DBS_HOST[*]})
    local qa_pass=(${QA_DBS_PASSWORD[*]})
    local qa_port=(${QA_DBS_PORT[*]})
    local existing_roles=(${QA_ROLES[*]})
    local qa_store=(${QA_STORAGE_LOCATION[*]})
    local qa_err=(${QA_ERROR_LOGS[*]})
    local no_of_dbs=${#qa_hosts[@]}   # ✅ set number of QA DBs

    echo "Processing CSV users for QA..."
    while IFS=',' read -r new_user role; do
        [[ -z "$new_user" || -z "$role" ]] && continue  # skip invalid rows
        # trim leading/trailing whitespace from role
        role=$(echo "$role" | xargs | tr '[:upper:]' '[:lower:]')

        local valid=0
        for r in "${existing_roles[@]}"; do
            r_lower=$(echo "$r" | tr '[:upper:]''[:lower:]')
            if [[ "$r_lower" == "$role" ]]; then
                valid=1
                break 
            fi 
        done
        if [[ $valid -eq 0 ]]; then
            echo "❌ Invalid role '$role' for user '$new_user'"
            continue
        fi

        # no flag check, apply to all QA DB hosts
        for ((i=0; i<$no_of_dbs; i++)); do
            host="${qa_hosts[$i]}"
            storage_file="$qa_store/qa_users_${host//./_}.csv"
            error_file="$qa_err/qa_errors_${host//./_}.log"
            mysql_create "${qa_hosts[$i]}" "$ADMIN_USER" "${qa_pass[$i]}" "${qa_port[$i]}" "$new_user" "$role" "$storage_file" "$error_file"
        done
    done < <(tail -n +2 "$csv_file")
}

#-------------------- PROD Environment ---------------------#
function create_prod_users() {
    #local prod_dbs=(${PROD_DBS[*]})
    local prod_hosts=(${PROD_DBS_HOST[*]})
    local prod_pass=(${PROD_DBS_PASSWORD[*]})
    local prod_port=(${PROD_DBS_PORT[*]})
    local existing_roles=(${PROD_ROLES[*]})
    local prod_store=(${PROD_STORAGE_LOCATION[*]})
    local prod_err=(${PROD_ERROR_LOGS[*]})
    local no_of_dbs=${#prod_hosts[*]}

    echo "Processing CSV users for PROD..."
    while IFS=',' read -r new_user role; do
        [[ -z "$new_user" || -z "$role" ]] && continue
        
        role=$(echo "$role" | xargs | tr '[:upper:]''[:lower:]')
        local valid=0
        for r in "${existing_roles[@]}"; do
            r_lower=$(echo "$r" | tr '[:upper:]''[:lower:]')
            if [[ "$r_lower" == "$role" ]]; then 
                valid=1
                break 
            fi 
        done
        if [[ $valid -eq 0 ]]; then
            echo "❌ Invalid role '$role' for user '$new_user'"
            continue
        fi

        for ((i=0; i<$no_of_dbs; i++)); do
            host="${prod_hosts[$i]}"
            storage_file="$prod_store/prod_users_${host//./_}.csv"
            error_file="$prod_err/prod_errors_${host//./_}.log"
            mysql_create "${prod_hosts[$i]}" "$ADMIN_USER" "${prod_pass[$i]}" "${prod_port[$i]}" "$new_user" "$role" "$storage_file" "$error_file"
        done
    done < <(tail -n +2 "$csv_file")
}

#-------------------- Main Logic ---------------------#

check_csv

echo "==============================================="
echo " MySQL Bulk User Creation Utility "
echo "==============================================="
select ENV in QA PRODUCTION BOTH; do
    case $ENV in
        QA)
            echo "Selected QA environment"
            create_qa_users
            break
            ;;
        PRODUCTION)
            echo "Selected PRODUCTION environment"
            create_prod_users
            break
            ;;
        BOTH)
            echo "Selected BOTH environments"
            echo "--------- QA CREATION ---------"
            create_qa_users
            echo "--------- PROD CREATION ---------"
            create_prod_users
            break
            ;;
        *)
            echo "Invalid choice!"
            ;;
    esac
done
