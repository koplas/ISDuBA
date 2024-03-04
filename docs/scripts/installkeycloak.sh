#!/usr/bin/env bash

# This file is Free Software under the MIT License
# without warranty, see README.md and LICENSES/MIT.txt for details.
#
# SPDX-License-Identifier: Apache-2.0
#
# SPDX-FileCopyrightText: 2024 German Federal Office for Information Security (BSI) <https://www.bsi.bund.de>
# Software-Engineering: 2024 Intevation GmbH <https://intevation.de>

set -e # to exit if a command in the script fails

sudo apt install -y unzip # needed to unzip the keycloak archive

# download and extract keycloak
sudo wget https://github.com/keycloak/keycloak/releases/download/23.0.5/keycloak-23.0.5.zip

sudo unzip keycloak-23.0.5.zip

sudo mkdir -p /opt/

sudo mv keycloak-23.0.5 /opt/keycloak

# create a keycloak user and give them the rights over keycloak
sudo useradd keycloak
sudo chown -R keycloak: /opt/keycloak