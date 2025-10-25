# Mysql Bulk User Creation and Deletion Automation Script

These bash scripts automate bulk management of MySQL users across multiple environments, QA, production, or both.

The creation script reads user information from a CSV file and:

- Creates Mysql users automatically
- Assigns roles and default privileges.
- Stores generated credentials in CSV files
- Logs errors separately.
- Sends credentials via email to each individuals users.

The deletion script reads a CSV file with usernames and:

- Deletes Mysql users from the specified environments.
- Logs each deletion or failure to a separate log file.
- Supports QA, PROD, or BOTH environments in a single execution.

## CSV File Format

### Creation Script

The CSV file should have the following columns:

```csv
username,role,email
phonisingh,QA,phonisingh@gmail.com
rahul,DEVELOPER,rahul@gmail.com
alex,ADMIN,alex@gmail.com
```

### Deletion Script

The CSV file should have the following columns:

```csv
username
phonisingh
rahul
alex
```

## .env file Format

This is how the environment file looks like:

```bash
# Common
ADMIN_USER="admin_user"

# QA Environment
QA_DBS_HOST=("qa1.example.com" "qa2.example.com")
QA_DBS_PASSWORD=("pass" "qapass2")
QA_DBS_PORT=("3315")
QA_ROLES=("intern" "BA" "sr_software" "QA")
QA_STORAGE_LOCATION=("/home/umx/userManagementScript/user_created")
QA_ERROR_LOGS=("/home/umx/userManagementScript/user_created")

# PROD Environment
PROD_DBS_HOST=("prod1.example.com" "prod2.example.com")
PROD_DBS_PASSWORD=("prod1_pass" "prod2_pass")
PROD_DBS_PORT=("3306" "3306")
PROD_ROLES=("APPLICATION" "BA" "DEVELOPER" "QA" "INTERN" "LEAD_DEVELOPER" "SYS_ADMIN")
PROD_STORAGE_LOCATION=("/home/umx/userManagementScript/user_created")
PROD_ERROR_LOGS=("/home/umx/userManagementScript/user_created")
```

## Create Users

```bash
./create_user.sh create_name.csv
```

## Delete Users

```bash
./delete_user.sh delete_name.csv
```
