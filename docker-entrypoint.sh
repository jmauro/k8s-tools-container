#!/usr/bin/env bash

set -e

[ ! -z ${DEBUG} ]  && set -x

N="\e[0m"
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
MAGENTA="\e[35m"
CYAN="\e[36m"
LIGHT_RED="\e[91m"
LIGHT_GREEN="\e[92m"
LIGHT_YELLOW="\e[93m"
LIGHT_BLUE="\e[94m"
LIGHT_MAGENTA="\e[95m"
LIGHT_CYAN="\e[96m"

B="\e[1m"
U="\e[4m"

if [[ -t 1 ]]; then
  # Display information when attached to TTY
  # Ref: https://stackoverflow.com/questions/911168/how-can-i-detect-if-my-shell-script-is-running-through-a-pipe/30520299#30520299

  # Getting information you need to display
  AWS_LIST="$(aws configure list | egrep 'profile|region'| sed -e 's/<not set>/default/g' | awk '{print $2}')"
  PROFILE="$(echo ${AWS_LIST} | cut -d' ' -f1)"
  AWS_REGION="$(echo ${AWS_LIST} | cut -d' ' -f2)"
  CLUSTER="$(kubectx -c)"
  NAMESPACE="$(kubens -c)"

  printf "\n----------------------------------------------------\n"
  printf "${B}>>> ${BLUE}%-19b${LIGHT_BLUE}: %-s${N}\n" "${U}AWS PROFILE${N}" "${PROFILE}"
  printf "${B}>>> ${CYAN}%-19b${LIGHT_CYAN}: %-s${N}\n" "${U}AWS REGION${N}" "${AWS_REGION}"
  printf "${B}>>> ${GREEN}%-19b${LIGHT_GREEN}: %-s${N}\n" "${U}CLUSTER${N}" "${CLUSTER}"
  printf "${B}>>> ${YELLOW}%-19b${LIGHT_YELLOW}: %-s${N}\n" "${U}NAMESPACE${N}" "${NAMESPACE}"
  printf -- "----------------------------------------------------\n"
fi

exec "${@}"
