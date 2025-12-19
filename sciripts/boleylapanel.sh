#!/usr/bin/env bash
set -e

APP_NAME="boleylapanel"
APP_DIR="/opt/$APP_NAME"
COMPOSE_FILE="$APP_DIR/docker-compose.yml"
ENV_FILE="$APP_DIR/.env"

cecho() {
  local c=$1; shift
  case $c in
    red)    echo -e "\e[91m$*\e[0m";;
    green)  echo -e "\e[92m$*\e[0m";;
    yellow) echo -e "\e[93m$*\e[0m";;
    blue)   echo -e "\e[94m$*\e[0m";;
    *) echo "$*";;
  esac
}

require_env() {
  if [ ! -f "$ENV_FILE" ]; then
    cecho red "❌ .env not found"
    cecho yellow "👉 cp .env.example .env"
    exit 1
  fi
}

cmd_install() {
  require_env
  docker compose -f "$COMPOSE_FILE" up -d --build
  cecho green "✅ BoleylaPanel started"
}

cmd_up()        { docker compose -f "$COMPOSE_FILE" up -d; }
cmd_down()      { docker compose -f "$COMPOSE_FILE" down; }
cmd_logs()      { docker compose -f "$COMPOSE_FILE" logs -f; }
cmd_status()    { docker compose -f "$COMPOSE_FILE" ps; }

cmd_update() {
  cecho blue "🔄 Updating BoleylaPanel..."
  git -C "$APP_DIR" pull
  docker compose -f "$COMPOSE_FILE" pull
  docker compose -f "$COMPOSE_FILE" up -d --build
  cecho green "✅ Updated"
}

cmd_uninstall() {
  cecho red "⚠️ This will REMOVE everything!"
  read -p "Are you sure? [yes]: " ans
  if [ "$ans" = "yes" ]; then
    docker compose -f "$COMPOSE_FILE" down -v --remove-orphans
    rm -rf "$APP_DIR"
    rm -f "/usr/local/bin/$APP_NAME"
    cecho green "✅ Removed completely"
  fi
}

cmd_doctor() {
  docker version
  docker compose version
  docker ps
}

menu() {
  clear
  cecho blue "===================================="
  cecho blue "        BoleylaPanel Manager         "
  cecho blue "===================================="
  echo "1) Install / Start"
  echo "2) Stop"
  echo "3) Status"
  echo "4) Logs"
  echo "5) Update"
  echo "6) Uninstall"
  echo "7) Doctor"
  echo "0) Exit"
  read -p "> " opt

  case "$opt" in
    1) cmd_install;;
    2) cmd_down;;
    3) cmd_status;;
    4) cmd_logs;;
    5) cmd_update;;
    6) cmd_uninstall;;
    7) cmd_doctor;;
    0) exit 0;;
    *) menu;;
  esac
}

case "$1" in
  install)   cmd_install;;
  up)        cmd_up;;
  down)      cmd_down;;
  status)    cmd_status;;
  logs)      cmd_logs;;
  update)    cmd_update;;
  uninstall) cmd_uninstall;;
  doctor)    cmd_doctor;;
  "" )       menu;;
  * )        cecho red "Unknown command";;
esac
