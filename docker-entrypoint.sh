#!/bin/bash
# Docker entrypoint of the docker image of the slurm and openssh docker container 
#
# Copyright (C) 2025  Manuel G. Marciani
# BSC-CNS - Earth Sciences

# Kindly shared by Elifarley
# Ref: https://superuser.com/a/917112

wait_str() {
  local file="$1"; shift
  local search_term="$1"; shift
  local wait_time="${1:-5m}"; shift # 5 minutes as default timeout

  (timeout $wait_time tail -F -n0 "$file" &) | grep -q "$search_term" && return 0

  echo "Timeout of $wait_time reached. Unable to find '$search_term' in '$file'"
  return 1
}

# wait_server() {
#   echo "Waiting for server..."
#   local server_log="$1"; shift
#   local wait_time="$1"; shift

#   wait_file "$server_log" 10 || { echo "Server log file missing: '$server_log'"; return 1; }

#   wait_str "$server_log" "Server Started" "$wait_time"
# }

wait_file() {
  local file="$1"; shift
  local wait_seconds="${1:-10}"; shift # 10 seconds as default timeout

  until test $((wait_seconds--)) -eq 0 -o -f "$file" ; do sleep 1; done

  ((++wait_seconds))
}

# SSH
/usr/sbin/sshd & 
# MySQL
/usr/bin/mariadbd-safe --skip-kill-mysqld --skip-syslog --log_error=/var/lib/mysql/mariadb.err &
wait_file "/var/lib/mysql/mariadb.err" 3
# Slurm BD
/usr/sbin/slurmdbd & 
# Slurm daemon
/usr/sbin/slurmd -N slurmctld -vvv &
wait_file "/var/log/slurm/slurmd.log" 3
wait_str "/var/log/slurm/slurmd.log" "slurmd started" 3
# Slurm controller
/usr/sbin/slurmctld -Dvvv
