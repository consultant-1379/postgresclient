#!/bin/bash

EXTR_NAME="EXTRpostgresclient"
PKG_NAME="postgresql13.x86_64"
LIB_PKG_NAME="postgresql13-libs"


log(){
  msg=$2
  dev_log=/dev/log
  if [[ -S "$dev_log" ]]; then
    case $1 in
    info)
      logger -s -t ${EXTR_NAME}-pre_uninstall -p 'user.notice' "$msg"
    ;;
    error)
      logger -s -t ${EXTR_NAME}-pre_uninstall -p 'user.error' "$msg"
    ;;
    debug)
      logger -s -t ${EXTR_NAME}-pre_uninstall -p 'user.debug' "$msg"
    ;;
    esac
  else
    case $1 in
    info)
      echo "$(date +'%b  %u %T') ${EXTR_NAME}-pre_uninstall [INFO]" "$msg"
    ;;
    error)
      echo "$(date +'%b  %u %T') ${EXTR_NAME}-pre_uninstall [ERROR]" "$msg"
    ;;
    debug)
      echo "$(date +'%b  %u %T') ${EXTR_NAME}-pre_uninstall [DEBUG]" "$msg"
    ;;
    esac
  fi
}


rpm_uninstall() {
  pkg=$1
  log debug "Attempting to uninstall ${pkg}"
  rm -f /var/lib/rpm/.rpm.lock
  out=$(rpm -e "$pkg" 2>&1)
  installed=$(rpm -qa | grep -c "${pkg}")
  if [ "${installed}" -eq 0 ]; then
    log info "Successfully uninstalled ${pkg}"
  else
    log error "${pkg} is still installed. Output: ${out}"
  fi
}


# Main
log info "Running ${EXTR_NAME} RPM Pre-Uninstall"

rpm_uninstall $PKG_NAME
rpm_uninstall $LIB_PKG_NAME

log info "Finished ${EXTR_NAME} RPM Pre-Uninstall"