#!/bin/bash

########################################################
# Created by: Umesh Rana
# Date: Oct 2025
# Purpose: Bulk MySQL Role Creation & Privilege Assignment
# Supports: QA, PROD, BOTH environments
# Input: CSV file with columns -> role_name,privileges
########################################################

source .env  # Load environment variables

CSV_FILE=$1   # CSV file path

#-------------------- Helper Functions ---------------------#

trim() {
    # remove leading/trailing whitespace
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

# Validate CSV file existence
check_csv() {
    if [[ ! -f "$CSV_FILE" ]]; then
        echo "CSV file not found: $CSV_FILE"
        exit 1
    fi
}

# Create role and assign privileges
create_role_mysql() {
    local host=$1
    local admin_user=$2
    local password=$3
    local port=$4
    local role_name=$5
    local privileges=$6
    local error_log=$7

    # Check if role exists
    local check_role="SELECT COUNT(*) FROM mysql.roles_mapping WHERE role='$role_name';"
    local exists=$(mysql -h "$host" -P "$port" -u "$admin_user" -p"$password" -N -B -e "$check_role" 2>>"$error_log")
    
    if [[ "$exists" -gt 0 ]]; then
        echo "Role '$role_name' already exists on $host"
    else
        # Create role
        local create_stmt="CREATE ROLE '$role_name';"
        mysql -h "$host" -P "$port" -u "$admin_user" -p"$password" -e "$create_stmt" 2>>"$error_log"
        if [[ $? -eq 0 ]]; then
            echo "Role '$role_name' created on $host ✅"
        else
            echo "Failed to create role '$role_name' on $host (see $error_log)"
        fi
    fi

    # Grant privileges
    if [[ -n "$privileges" ]]; then
        local grant_stmt="GRANT $privileges TO '$role_name';"
        mysql -h "$host" -P "$port" -u "$admin_user" -p"$password" -e "$grant_stmt" 2>>"$error_log"
        if [[ $? -eq 0 ]]; then
            echo "Privileges granted to role '$role_name' on $host ✅"
        else
            echo "Failed to grant privileges to role '$role_name' on $host (see $error_log)"
        fi
    fi
}

#-------------------- QA Roles ---------------------#
create_qa_roles() {
    local hosts=(${QA_DBS_HOST[*]})
    local pass=(${QA_DBS_PASSWORD[*]})
    local port=(${QA_DBS_PORT[*]})
    local error_log=${QA_ERROR_LOGS[0]}
    local total_hosts=${#hosts[@]}

    while IFS=',' read -r role_name privileges; do
        # trim fields
        role_name=$(trim "$role_name")
        privileges=$(trim "$privileges")
        [[ -z "$role_name" ]] && continue
        for ((i=0; i<$total_hosts; i++)); do
            create_role_mysql "${hosts[$i]}" "$ADMIN_USER" "${pass[$i]}" "${port[$i]}" "$role_name" "$privileges" "$error_log"
        done
    done < <(tail -n +2 "$CSV_FILE")
}

#-------------------- PROD Roles ---------------------#
create_prod_roles() {
    local hosts=(${PROD_DBS_HOST[*]})
    local pass=(${PROD_DBS_PASSWORD[*]})
    local port=(${PROD_DBS_PORT[*]})
    local error_log=${PROD_ERROR_LOGS[0]}
    local total_hosts=${#hosts[@]}

   while IFS=',' read -r role_name privileges; do
        # trim fields
        role_name=$(trim "$role_name")
        privileges=$(trim "$privileges")
        [[ -z "$role_name" ]] && continue
        for ((i=0; i<$total_hosts; i++)); do
            create_role_mysql "${hosts[$i]}" "$ADMIN_USER" "${pass[$i]}" "${port[$i]}" "$role_name" "$privileges" "$error_log"
        done
    done < <(tail -n +2 "$CSV_FILE")    
}

#-------------------- Main Logic ---------------------#

check_csv

echo "==============================================="
echo " MySQL Bulk Role Creation Utility "
echo "==============================================="

select ENV in QA PRODUCTION BOTH; do
    case $ENV in
        QA)
            echo "Selected QA environment"
            create_qa_roles
            break
            ;;
        PRODUCTION)
            echo "Selected PRODUCTION environment"
            create_prod_roles
            break
            ;;
        BOTH)
            echo "Selected BOTH environments"
            echo "--------- QA ROLES ---------"
            create_qa_roles
            echo "--------- PROD ROLES ---------"
            create_prod_roles
            break
            ;;
        *)
            echo "Invalid choice!"
            ;;
    esac
done
