#!/bin/bash

PARAM_1=$1
PARAM_2=$2
PARAM_3=$3

RCol='\e[0m';
Yel='\e[0;33m';
Red='\e[0;31m';
Gre='\e[0;32m';
Divider='==============================================================';

case "$PARAM_1" in
    "containers:stop")
    echo "${Yel}";
    echo "Stopping all containers"
    docker stop $(docker ps -a -q)
    echo "${RCol}";
   ;;
   "containers:remove")
    echo "${Yel}";
    echo "Removing all containers";
    docker stop $(docker ps -a -q)
    docker rm $(docker ps -a -q)
    # Remove with filters
    # docker rm $(docker ps -a -f status=exited -f status=created)
    echo "${RCol}";
   ;;
   "images:remove")
    echo "${Yel}";
    echo "Removing all images";
    docker rmi $(docker images -a -q)
    echo "${RCol}";
   ;;
   *)
    echo "${Red}";
    echo "I don't know what to do";
    echo "${RCol}";
   ;;
esac

exit 1;
