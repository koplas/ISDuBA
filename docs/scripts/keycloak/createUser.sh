#!/usr/bin/env bash

# This file is Free Software under the Apache-2.0 License
# without warranty, see README.md and LICENSES/Apache-2.0.txt for details.
#
# SPDX-License-Identifier: Apache-2.0
#
# SPDX-FileCopyrightText: 2024 German Federal Office for Information Security (BSI) <https://www.bsi.bund.de>
# Software-Engineering: 2024 Intevation GmbH <https://intevation.de>

set -e # to exit if a command in the script fails

# arguments:
# $1: username
# $2: first Name
# $3: last Name
# $4: E-Mail
# $5: password
# $6: role

if sudo /opt/keycloak/bin/kcadm.sh get 'http://localhost:8080/admin/realms/isduba/users' | grep -F -q "\"username\" : \"$1\"" ; then
  echo "User $1 already exists."
else
  # create user
  userid=$(sudo /opt/keycloak/bin/kcadm.sh create users --target-realm isduba \
      --set username=$1 --set enabled=true \
      --set firstName=$2 --set lastName=$3 \
      --set email=$4 \
      --set emailVerified=true)

  # set password for user
  sudo /opt/keycloak/bin/kcadm.sh set-password --target-realm isduba \
      --username $1 --new-password "$5"

  # set role for user
  sudo /opt/keycloak/bin/kcadm.sh add-roles -r isduba --uusername $1 --rolename $6
fi
