#!/bin/bash

# Configuración
EXPLANATION=""
ADDITIONAL_PARAMS=""
COMMAND=""
CONTAINER_OPTS=()
CONFIG_FILE="docker-simplifier.conf"
CUSTOM_FILE=0
ADD_FOLLOW=0
CONTAINER_NAME_NUM=0
CONTAINER_NAME=""
FORCE=""
FILE_NAME=""
NO_CACHE=""
ALL=0
TAIL=""
ADD_TAIL=0
ADD_TIME=0
EXPLAIN=0
TIME=""
DOCKER_OPTS=()
TAG_NAME=0
NO_COMPOSE=0
VERSION="2.0.0"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# PARAMETER
PARAM_1=$1
DOCKER_COMPOSE_FILE_EXIST=0

for param in "${ADDITIONAL_PARAMS[@]}"; do
  if [[ "$param" =~ ^-- ]]; then
    DOCKER_OPTS+=("$param")
  else
    CONTAINER_OPTS+=("$param")
  fi
done

get_container_name() {
  local __resultvar=$1
  read -r -p "Please write container name: " container_name
  eval "$__resultvar=\"\$container_name\""
}

# Implementar funciones para limpieza avanzada
docker_cleanup() {
    echo -e "${YELLOW}Opciones de limpieza:${NC}"
    echo "1. Eliminar contenedores detenidos"
    echo "2. Eliminar imágenes sin usar"
    echo "3. Eliminar volúmenes no utilizados"
    echo "4. Eliminar redes no utilizadas"
    echo "5. Limpieza completa (prune)"
    echo "6. Volver"

    read -p "Seleccione opción: " choice

    case $choice in
        1)
            docker container prune
            ;;
        2)
            docker image prune
            ;;
        3)
            docker volume prune
            ;;
        4)
            docker network prune
            ;;
        5)
            docker system prune -a
            ;;
        6)
            return
            ;;
        *)
            echo -e "${RED}Opción inválida${NC}"
            ;;
    esac
}

usage() {
  echo -e "${YELLOW}Dockify v${VERSION}${NC}"
  cat <<EOF
  Usage: dockify [OPTIONS] [FLAGS]
  Options:
    container:start            <container_name>  Start a Docker container.
    container:stop             <container_name>  Stop a Docker container.
    container:restart          <container_name>  Restart a Docker container.
    container:status          <container_name>  Check the status of a Docker container.
    container:logs            <container_name>  View logs of a Docker container.

  Flags
    -f, --file <file>          Specify a custom Dockerfile or docker-compose file.
    -t, --tag <tag>            Set the image tag name.
    -l, --local                Use local Dockerfile.
    -y, --yes                  Skip confirmation prompts.
    -n, --no                   Do not skip confirmation prompts.
    -p, --project              Manage Docker Compose projects.
    -h, --help                 Show this help message.
    -c, --compatibility        Enable compatibility mode.
    -i, --image-name <name>    Set a custom image name.
    --force                    Force build even if cache is available.
    --no-cache                 Build without cache.
    --name <container_name>    Set a custom container name.
    --command <command>        Run a specific command in the container.
EOF
  exit 0
}

list_compose_projects() {
    echo -e "${GREEN}Lista de proyectos Docker Compose:${NC}"
    find . -name "docker-compose.yml" -exec dirname {} \; | sort
}

dockerComposeExist() {
  # Buscar en el directorio actual
  local found_files=($(find . -maxdepth 1 -name "docker-compose*.yml" -not -path '*/.*'))

  if [ ${#found_files[@]} -gt 0 ]; then
    if [ -f "docker-compose.yml" ]; then
      DOCKER_COMPOSE_FILE="docker-compose.yml"
    else
      DOCKER_COMPOSE_FILE="${found_files[0]}"
    fi
    DOCKER_COMPOSE_FILE_EXIST=1
    return 0
  else
    echo -e "${GREEN}No se encontraron archivos docker-compose${NC}"
    DOCKER_COMPOSE_FILE_EXIST=0
    return 1
  fi
}

showCommand() {
  local __var=$1
  if [ $EXPLAIN -eq 1 ]; then
    echo -e "${GREEN}Executing:${NC} ${YELLOW}$__var${NC}"
  fi
}

explainCommand() {
  local __var=$1
  if [ $EXPLAIN -eq 1 ]; then
    echo -e "${GREEN}Explanation:${NC}\n ${YELLOW}$__var${NC}"
  fi
}

allExplanations() {
  case $1 in
  logs)
    EXPLANATION=$(cat <<'EOF'
The command docker-compose logs -f <CONTAINER_NAME> does the following:

docker-compose logs: Shows the logs (output) of services managed by Docker Compose.
-f: Follows the log output, similar to tail -f, so you see new log entries in real time.
CONTAINER_NAME: Specifies the service name (in this case, <CONTAINER_NAME>) whose logs you want to view.
Additional useful docker-compose log commands:

docker-compose logs <CONTAINER_NAME>: Shows all logs for the <CONTAINER_NAME> service.
docker-compose logs --tail 100 <CONTAINER_NAME>: Shows only the last 100 lines of logs.
docker-compose logs --timestamps <CONTAINER_NAME>: Shows logs with timestamps.
docker-compose logs -f --tail 50 <CONTAINER_NAME>: Follows the last 50 lines of logs in real time.
docker-compose logs -f: Follows logs for all services in real time.
docker-compose logs --no-color Produce monochrome output.
docker-compose logs --no-log-prefix Do not print prefix in logs.

These options help you monitor and debug your Docker Compose services more effectively.
EOF
    )
    ;;
    stop)
      EXPLANATION=$(cat <<'EOF'
docker-compose -f <DOCKER_COMPOSE_FILE> stop <CONTAINER_NAME>
Uses Docker Compose to stop the specified service (<CONTAINER_NAME>) defined in the compose file (<DOCKER_COMPOSE_FILE>).
It stops the container(s) managed by that Compose project, using the configuration in the YAML file.

docker stop <CONTAINER_NAME>:
Directly stops a running container with the name or ID <CONTAINER_NAME> using the Docker CLI, regardless of how it was started.

Summary:
Use docker-compose stop for containers managed by Compose projects; use docker stop for any container by name or ID.
EOF
      )
    ;;
    show)
      EXPLANATION=$(cat <<'EOF'
The command docker ps lists all running Docker containers on your system.
It shows details like container ID, image, command, creation time, status, ports, and names.
By default, it only displays running containers; to see all containers (including stopped ones),
use docker ps -a.
EOF
    )
    ;;
    start)
      EXPLANATION=$(cat <<'EOF'
The command docker-compose -f <DOCKER_COMPOSE_FILE> up -d <CONTAINER_NAME> does the following:
Starts a Docker container defined in a Docker Compose file.
-f <DOCKER_COMPOSE_FILE>: Specifies the Docker Compose file to use.
-d: Runs the container in detached mode (in the background).
<CONTAINER_NAME>: The name of the service/container to start as defined in the Docker Compose file.
If the container is already running, it will not restart it unless you use the --force-recreate option.
If the container is not running, it will create and start it based on the configuration in the Docker Compose file.
If not use docker-compose, the command docker start <CONTAINER_NAME> is used to start a stopped container.
EOF
    )
    ;;
    *)
      EXPLANATION=""
    ;;
  esac
}

getParams() {
  # Saltar los primeros 2 argumentos (comando y subcomando)
  shift 1

  # Array para almacenar parámetros adicionales
  ADDITIONAL_PARAMS=()

  while [ "$#" -gt 0 ]; do
    case "${1,,}" in
      -a|--all)
        ALL=1
      ;;
      -f|--file)
        CUSTOM_FILE=1
        ADD_FOLLOW=1
        FILE_NAME="$2"
        ;;
      --folow)
        ADD_FOLLOW=1
        ;;
      -t|--tag)
        TAG_NAME=1
        IMAGE_NAME="$2"
        ;;
      -i|--image-name)
        TAG_NAME=1
        IMAGE_NAME="$2"
        ;;
      --force)
        FORCE="--force"
        ;;
      --no-cache)
        NO_CACHE="--no-cache"
        ;;
      --name)
        CONTAINER_NAME_NUM=1
        CONTAINER_NAME="$2"
        ;;
      --command)
        COMMAND="$2"
        ;;
      -~|--tail)
        ADD_TAIL=1
        TAIL="$2"
        ;;
      --time)
        ADD_TIME=1
        TIME="$2"
        ;;
      --no-compose)
        NO_COMPOSE=1
        DOCKER_COMPOSE_FILE_EXIST=0
        ;;
      --explain)
        EXPLAIN=1
        ;;
      *)
        # Agregar parámetros no reconocidos al array
        ADDITIONAL_PARAMS+=("$1")
        ;;
    esac
    shift
  done
}

# Función principal
main() {
  case "$1" in
    "c:s"|"container:start")
      getParams "$@"
      dockerComposeExist
      allExplanations "start"

      if [ $DOCKER_COMPOSE_FILE_EXIST -eq 1 ] && [ $NO_COMPOSE -eq 0 ]; then
        if [ "$CUSTOM_FILE" -eq 1 ]; then
          DOCKER_COMPOSE_FILE="$FILE_NAME"
        fi

        # Construir comando docker-compose con todos los parámetros
        local docker_cmd="docker-compose -f $DOCKER_COMPOSE_FILE up -d $CONTAINER_NAME"

        # Agregar parámetros adicionales si existen
        if [ ${#ADDITIONAL_PARAMS[@]} -gt 1 ]; then
          docker_cmd+=" ${ADDITIONAL_PARAMS[*]:2}"
        fi
      else
        if [ $CONTAINER_NAME_NUM -eq 0 ]; then
          get_container_name CONTAINER_NAME
        fi

        if [ $CUSTOM_FILE -eq 1 ]; then
          DOCKER_COMPOSE_FILE="$FILE_NAME"
        fi

        local docker_cmd="docker start $CONTAINER_NAME"

        # Agregar parámetros adicionales si existen
        if [ ${#ADDITIONAL_PARAMS[@]} -gt 1 ]; then
          docker_cmd+=" ${ADDITIONAL_PARAMS[*]:1}"
        fi
      fi
      ;;
    "c:stop"|"container:stop")
      getParams "$@"
      dockerComposeExist
      allExplanations "stop"

      if [ $DOCKER_COMPOSE_FILE_EXIST -eq 1 ] && [ $NO_COMPOSE -eq 0 ]; then
        if [ $CUSTOM_FILE -eq 1 ]; then
          DOCKER_COMPOSE_FILE="$FILE_NAME"
        fi

        local docker_cmd="docker-compose -f $DOCKER_COMPOSE_FILE stop $CONTAINER_NAME"
      else
        if [ "$CONTAINER_NAME" == "" ]; then
          get_container_name CONTAINER_NAME
        fi

        local docker_cmd="docker stop $CONTAINER_NAME"
      fi
    ;;
    "c:show"|"container:show")
      getParams "$@"
      allExplanations "show"

      docker_cmd="docker ps"
      if [ $ALL -eq 1 ]; then
        docker_cmd+=" -a"
      fi
    ;;
    "c:l"|"container:logs")
      getParams "$@"
      dockerComposeExist
      allExplanations "logs"

      add_params=""
      if [ $ADD_FOLLOW -eq 1 ]; then
        add_params="-f"
      fi

      if [ $ADD_TAIL -eq 1 ]; then
        add_params+=" --tail $TAIL"
      fi

      if [ $ADD_TIME -eq 1 ]; then
        add_params+=" --timestamps"
      fi

      if [ $DOCKER_COMPOSE_FILE_EXIST -eq 1 ]; then
        if [ $CUSTOM_FILE -eq 1 ]; then
          DOCKER_COMPOSE_FILE="$FILE_NAME"
        fi

        if [ ${#ADDITIONAL_PARAMS[@]} -gt 1 ]; then
          add_params+=" ${ADDITIONAL_PARAMS[*]:1}"
        fi

        docker_cmd="docker-compose logs $add_params $CONTAINER_NAME"
      else
        if [ $CONTAINER_NAME_NUM -eq 0 ]; then
          get_container_name CONTAINER_NAME
        fi

        docker_cmd="docker logs $add_params $CONTAINER_NAME"
      fi
    ;;
    -h|--help)
      usage
      ;;
    *)
      usage
      ;;
  esac

  eval "$docker_cmd"

  showCommand "$docker_cmd"
  explainCommand "$EXPLANATION"
}

# Start script
main "$@"
