#!/bin/bash

########################################################
# Created by: Umesh Rana
# Date: Oct 2025
# Version: 1.0
# Purpose: Bulk MySQL User Deletion Script
# Supports: QA, PROD, BOTH environments
# Input: CSV file with column -> username
########################################################

source .env   # Load environment variables

CSV_FILE=$1   # First argument: path to CSV file

#-------------------- Helper Function ---------------------#

# Validate CSV file existence
check_csv() {
    if [[ ! -f "$CSV_FILE" ]]; then
        echo "CSV file not found: $CSV_FILE"
        exit 1
    fi
}

# Delete MySQL user
delete_user() {
    local host="$1"
    local admin_user="$2"
    local admin_pass="$3"
    local port="$4"
    local target_user="$5"
    local log_file="$6"

    #echo "Deleting user '$target_user' from $host ..."

    mysql -h "$host" -P "$port" -u "$admin_user" -p"$admin_pass" -e "DROP USER IF EXISTS '$target_user'@'%'; FLUSH PRIVILEGES;" 2>>"$log_file"

    if [[ $? -eq 0 ]]; then
        echo "User '$target_user' deleted from $host ✅"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Deleted $target_user from $host" >> "$log_file"
    else
        echo "Failed to delete user '$target_user' from $host"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Failed to delete $target_user from $host" >> "$log_file"
    fi
}

#-------------------- QA Environment ---------------------#
delete_qa_users() {
    local qa_hosts=(${QA_DBS_HOST[*]})
    local qa_pass=(${QA_DBS_PASSWORD[*]})
    local qa_port=(${QA_DBS_PORT[*]})
    local qa_log=${QA_ERROR_LOGS[0]}
    local total_hosts=${#qa_hosts[@]}

    echo "Deleting users from QA environment..."
    echo ""
    while IFS=',' read -r target_user; do
        [[ -z "$target_user" || "$target_user" == "username" ]] && continue
        for ((i=0; i<$total_hosts; i++)); do
            delete_user "${qa_hosts[$i]}" "$ADMIN_USER" "${qa_pass[$i]}" "${qa_port[$i]}" "$target_user" "$qa_log/qa_user_deletion.log"
        done
    done < "$CSV_FILE"
}

#-------------------- PROD Environment ---------------------#
delete_prod_users() {
    local prod_hosts=(${PROD_DBS_HOST[*]})
    local prod_pass=(${PROD_DBS_PASSWORD[*]})
    local prod_port=(${PROD_DBS_PORT[*]})
    local prod_log=${PROD_ERROR_LOGS[0]}
    local total_hosts=${#prod_hosts[@]}

    echo "Deleting users from PROD environment..."
    echo ""
    while IFS=',' read -r target_user; do
        [[ -z "$target_user" || "$target_user" == "username" ]] && continue
        for ((i=0; i<$total_hosts; i++)); do
            delete_user "${prod_hosts[$i]}" "$ADMIN_USER" "${prod_pass[$i]}" "${prod_port[$i]}" "$target_user" "$prod_log/prod_user_deletion.log"
        done
    done < "$CSV_FILE"
}

#-------------------- Main Logic ---------------------#

check_csv

echo "==============================================="
echo "   MySQL Bulk User Deletion Utility   "
echo "==============================================="

select ENV in QA PRODUCTION BOTH; do
    case $ENV in
        QA)
            echo "Selected QA environment"
            delete_qa_users
            break
            ;;
        PRODUCTION)
            echo "Selected PRODUCTION environment"
            delete_prod_users
            break
            ;;
        BOTH)
            echo "Selected BOTH environments"
            echo "--------- QA DELETION ---------"
            delete_qa_users
            echo "--------- PROD DELETION ---------"
            delete_prod_users
            break
            ;;
        *)
            echo "Invalid choice. Please select a valid option."
            ;;
    esac
done
