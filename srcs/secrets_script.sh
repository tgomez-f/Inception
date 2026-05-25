#!/bin/bash

mkdir -p "secrets"

[ ! -f "secrets/db_password.txt" ]      && openssl rand -base64 15 > "secrets/db_password.txt"
[ ! -f "secrets/db_root_password.txt" ] && openssl rand -base64 15 > "secrets/db_root_password.txt"
[ ! -f "secrets/wp_admin_password.txt" ] && openssl rand -base64 15 > "secrets/wp_admin_password.txt"
[ ! -f "secrets/wp_user_password.txt" ] && openssl rand -base64 15 > "secrets/wp_user_password.txt"


echo "Secrets added."

# openssl rand : génère des octets aléatoires
# -base64 : converti les donnees binaires en texte lisible
