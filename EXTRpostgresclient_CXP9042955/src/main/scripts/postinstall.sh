#!/bin/bash

EXTR_NAME="EXTRpostgresclient"
PKG="postgresql13-13.8-1PGDG.rhel7.x86_64.rpm"
PREVIOUS_PKG="postgresql12-12.6-1PGDG.rhel7.x86_64.rpm"
RPM_PATH="/opt/ericsson/pgsql/rpm/client/resources/"
PKG_NAME="postgresql13"


log(){
  msg=$2
  dev_log=/dev/log
  if [[ -S "$dev_log" ]]; then
    case $1 in
    info)
      logger -s -t ${EXTR_NAME}-install -p 'user.notice' "$msg"
    ;;
    error)
      logger -s -t ${EXTR_NAME}-install -p 'user.error' "$msg"
    ;;
    debug)
      logger -s -t ${EXTR_NAME}-install -p 'user.debug' "$msg"
    ;;
    esac
  else
    case $1 in
    info)
      echo "$(date +'%b  %u %T') ${EXTR_NAME}-install [INFO]" "$msg"
    ;;
    error)
      echo "$(date +'%b  %u %T') ${EXTR_NAME}-install [ERROR]" "$msg"
    ;;
    debug)
      echo "$(date +'%b  %u %T') ${EXTR_NAME}-install [DEBUG]" "$msg"
    ;;
    esac
  fi
}


removing_old_rpm() {
  if [ -f "${RPM_PATH}${PREVIOUS_PKG}" ]; then
    log debug "Removing ${PREVIOUS_PKG}."
    out=$(rm -f ${RPM_PATH}${PREVIOUS_PKG} 2>&1)
    # shellcheck disable=SC2181
    if [ $? -ne 0 ]; then
      log debug "Failed to remove ${PREVIOUS_PKG}. OUTPUT: $out"
    else
      log debug "Successfully removed ${PREVIOUS_PKG}"
    fi
  fi
}


rpm_install() {
  if [ ! -f "${RPM_PATH}${PKG}" ]; then
    log error "${PKG_NAME} not deployed in desired location"
    exit 1
  else
    log debug "Attempting to install ${PKG_NAME}"
    # Need to remove the RPM lock - inception
    rm -f /var/lib/rpm/.rpm.lock
    out=$(rpm -i "$RPM_PATH${PKG}" --nodeps 2>&1)
    # shellcheck disable=SC2181
    if [ $? -ne 0 ]; then
      /bin/grep 'is already installed' <<< "${out}"
      log debug "${PKG} is already installed"
    else
      installed=$(rpm -qa | grep -c "${PKG_NAME}")
      if [ "${installed}" -eq 0 ]; then
        log error "Issue with installing ${PKG} via rpm -i"
        log error "rpm -i OUTPUT: ${out}"
        exit 1
      fi
    fi
  fi
  log info "Installed ${PKG_NAME} rpm"
}


# Main
log info "Running ${EXTR_NAME} RPM Post-Install"

removing_old_rpm
rpm_install

log info "Finished ${EXTR_NAME} RPM Post-Install"