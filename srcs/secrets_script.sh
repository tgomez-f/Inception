#!/bin/bash
# echo "PWD=$(pwd)"

# PATH_EXEC_SH="$(dirname "$0")"
# ABS_PATH="$(cd "$PATH_EXEC_SH/.." && pwd)"


mkdir -p "secrets"

echo "mypassword" > "secrets/db_password.txt"
echo "myrootpassword" > "secrets/db_root_password.txt"
echo "adminpass" > "secrets/wp_admin_password.txt"
echo "userpass" > "secrets/wp_user_password.txt"

echo "Secrets added."

# $0	chemin du script
# dirname	extrait le dossier
# SCRIPT_DIR	dossier du script
# cd ...	remonte à la racine
# pwd	donne chemin absolu
# ROOT_DIR	racine du projet