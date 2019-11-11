#!/bin/bash

readonly CURRENT_DIR=${PWD##*/}
readonly CONTAINER="$CURRENT_DIR"_db_1
readonly DB=${DB:-db666}
readonly MIG_TABLE="${MIG_TABLE:-migrations}"
readonly MIG_DIR="${MIG_DIR:-migrations}"

readonly EXP_PDW="export MYSQL_PWD=root;"

readonly ACTION=$1

# ----------------------------------------------------------------------------------------------------------------------
# always performed tasks
#
# creates the migrations table if needed
# creates the migrations folder and the up and down subfolders if needed

echo

CHECK=$(docker exec -t "$CONTAINER" bash -c "$EXP_PDW mysql -u root -D $DB -e 'SHOW tables;' | grep '$MIG_TABLE'")
if [[ ! $CHECK ]]; then
  echo "Création de la table '$MIG_TABLE'"
  ERR=$(docker exec -t "$CONTAINER" bash -c "$EXP_PDW mysql -u root -D $DB -e 'CREATE TABLE $MIG_TABLE (version INT UNSIGNED PRIMARY KEY NOT NULL);'")
  if [[ $ERR ]]; then
    echo "$ERR"
    exit 0
  fi
fi

if [[ ! -d $MIG_DIR ]]; then
  echo "Création du dossier '$MIG_DIR'"
  mkdir "./$MIG_DIR"
fi

if [[ ! -d $MIG_DIR"/up" ]]; then
  echo "Création du dossier '$MIG_DIR/up'"
  mkdir "./$MIG_DIR/up"
fi

if [[ ! -d $MIG_DIR"/down" ]]; then
  echo "Création du dossier '$MIG_DIR/down'"
  mkdir "./$MIG_DIR/down"
fi

echo

# ----------------------------------------------------------------------------------------------------------------------
# init ACTION

if [[ $ACTION == "init" ]]; then
  echo "Initialisation terminée"
  exit 0

# ----------------------------------------------------------------------------------------------------------------------
# create ACTION
#
# creates a new version
#     — a new row in the migrations table
#     - a new SQL file in the 'up' folder
#     - a new SQL file in the 'down' folder

elif [[ $ACTION == "create" ]]; then

  # create a new version
  readonly NEW_VERSION="$(date +%s)"

  # create sql files
  UP_FILE="$MIG_DIR/up/$NEW_VERSION.sql"
  DOWN_FILE="$MIG_DIR/down/$NEW_VERSION.sql"

  touch "$UP_FILE"
  touch "$DOWN_FILE"

  echo "-- Version $NEW_VERSION - UP" >>"$UP_FILE"
  echo "-- Version $NEW_VERSION - DOWN" >>"$DOWN_FILE"

  echo "Nouvelle version: $NEW_VERSION 🥳"
  echo
  echo "Fichiers SQL (à remplir):"
  echo "    $UP_FILE"
  echo "    $DOWN_FILE"
  exit 0

# ----------------------------------------------------------------------------------------------------------------------

else
  # search for current version in db
  VERSION=$(docker exec -t "$CONTAINER" bash -c "$EXP_PDW mysql -s -u root -D $DB -e 'SELECT MAX(version) FROM $MIG_TABLE' | sed -n 1p")

  # sanitize return as int
  VERSION=${VERSION//[^0-9]/}
  VERSION=${VERSION:-0}

  CURRENT_VERSION=$((VERSION))

# ----------------------------------------------------------------------------------------------------------------------
# up ACTION
#
# executes the next up migration available

  if [[ $ACTION == "up" ]]; then
    # get next version
    next_version=$((CURRENT_VERSION))

    for f in "$MIG_DIR"/"$ACTION"/*.sql; do
      filename=$(basename -- "$f")
      a_version="${filename%.*}"

      if [[ $a_version -gt $CURRENT_VERSION ]]; then

        if [[ $next_version -eq $CURRENT_VERSION ]]; then
          next_version="$a_version"
        fi

        if [[ $a_version -lt $next_version ]]; then
          next_version="$a_version"
        fi
      fi
    done

    if [[ $next_version -eq $CURRENT_VERSION ]]; then
      echo "Migrations à jour 😎"
      exit 0
    fi

    echo "Montée vers la version: $next_version"
    echo

    readonly SQL_UP_FILE="$MIG_DIR/$ACTION/$next_version.sql"

    printf -v TRANSACTION \
      "START TRANSACTION;\n%s\nINSERT INTO %s VALUES (%s);\nCOMMIT;" \
      "$(cat "$SQL_UP_FILE");" \
      "$MIG_TABLE" \
      "$next_version"

    echo "• $next_version"
    echo "------------"
    cat "$SQL_UP_FILE"
    echo

    # execute SQL from file and persist version
    error=$(docker exec -t "$CONTAINER" bash -c "$EXP_PDW mysql -s -u root -D $DB -e '$TRANSACTION'")

    if [[ ! "$error" ]]; then
      echo "Migration effectuée avec succès vers la version $next_version"
      exit 0
    else
      echo "La migration vers la version $next_version a échoué"
      echo "$error"
      exit 0
    fi

# ----------------------------------------------------------------------------------------------------------------------
# down ACTION
#
# rewinds the current migration

  elif [[ $ACTION == "down" ]]; then

    if [ "$CURRENT_VERSION" -eq 0 ]; then
      echo "Aucune migration disponible 🤨"
      exit 0
    fi

    SQL_DOWN_FILE="$MIG_DIR/$ACTION/$CURRENT_VERSION.sql"

    printf -v TRANSACTION \
      "START TRANSACTION;\n%s\nDELETE FROM %s WHERE version = %s;\nCOMMIT;" \
      "$(cat "$SQL_DOWN_FILE");" \
      "$MIG_TABLE" \
      "$CURRENT_VERSION"

    echo "• $CURRENT_VERSION"
    echo "------------"
    cat "$SQL_DOWN_FILE"
    echo

    # execute SQL from file and persist version
    error=$(docker exec -t "$CONTAINER" bash -c "$EXP_PDW mysql -s -u root -D $DB -e '$TRANSACTION'")

    if [ ! "$error" ]; then
      PREV_VERSION=$(docker exec -t "$CONTAINER" bash -c "$EXP_PDW mysql -s -u root -D $DB -e 'SELECT MAX(version) FROM $MIG_TABLE' | sed -n 1p")

      # filter int
      PREV_VERSION=${PREV_VERSION//[^0-9]/}

      echo "Migration inverse effectuée avec succès vers la version ${PREV_VERSION:-0}"
      exit 0
    else
      echo "Echec de la migration"
      echo "$error"
      exit 0
    fi

# ----------------------------------------------------------------------------------------------------------------------
# latest ACTION
#
# executes all next available migrations in order

  elif [[ $ACTION == "latest" ]]; then
    echo "Migration..."
    echo

    cur_version=$((CURRENT_VERSION))

    while :; do
      next_version=$((cur_version))

      for f in "$MIG_DIR/up"/*.sql; do
        filename=$(basename -- "$f")
        v="${filename%.*}"

        if [[ $v -gt $cur_version ]]; then

          if [[ $next_version -eq $cur_version ]]; then
            next_version="$v"
          fi

          if [[ $v -lt $next_version ]]; then
            next_version=$v
          fi
        fi
      done

      if [[ $next_version -eq $cur_version ]]; then
        break
      fi

      SQL_FILE="$MIG_DIR/up/$next_version.sql"

      printf -v TRANSACTION \
        "START TRANSACTION;\n%s\nINSERT INTO %s VALUES (%s);\nCOMMIT;" \
        "$(cat "$SQL_FILE");" \
        "$MIG_TABLE" \
        "$next_version"

      echo "• $next_version"
      echo "------------"
      cat "$SQL_FILE"
      echo

      # execute SQL from file and persist version
      error=$(docker exec -t "$CONTAINER" bash -c "$EXP_PDW mysql -s -u root -D $DB -e '$TRANSACTION'")

      if [ "$error" ]; then
        echo "Migration impossible vers la version $next_version"
        echo "$error"
        exit 0
      fi

      cur_version="$next_version"

    done

    if [ "$next_version" == "$CURRENT_VERSION" ]; then
      echo "...à jour 😎"
      exit 0
    fi

    echo "...terminée"
    exit 0

# ----------------------------------------------------------------------------------------------------------------------

  else
    echo "Action non reconnue"
    exit 0
  fi

fi
