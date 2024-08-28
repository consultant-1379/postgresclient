#!/bin/bash

EXTR_NAME="EXTRpostgresclient2"
LATEST_PG_BIN="/usr/pgsql-13/bin/"
PG_BIN="/opt/postgresql/bin/"
PKG_NAME="postgresql13"
PREVIOUS_PKG_1="postgresql12-12.6-1PGDG.rhel7.x86_64.rpm"
PREVIOUS_PKG_2="postgresql13-13.8-1PGDG.rhel7.x86_64.rpm"
# For the Future uplift use the following 2 Previous_PKGs
#PREVIOUS_PKG_1="postgresql13-13.8-1PGDG.rhel7.x86_64.rpm"
#PREVIOUS_PKG_2="postgresql13-13.8-1PGDG.rhel8.x86_64.rpm"
RPM_PATH="/opt/ericsson/pgsql/rpm2/client/resources/"
# RPM_PATH_OLD is required to remove rpm from old EXTR package
RPM_PATH_OLD="/opt/ericsson/pgsql/rpm/client/resources/"


log() {
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

# Setting Package Names
# Determine if RHEL7 or Above
grep "7\." /etc/redhat-release >/dev/null 2>&1
IS_RHEL7=$?
if [ $IS_RHEL7 -eq 0 ]; then
  PKG="postgresql13-13.8-1PGDG.rhel7.x86_64.rpm"
  log debug "RHEL7 Deployment: Installing ${PKG}"
else
  PKG="postgresql13-13.8-1PGDG.rhel8.x86_64.rpm"
  log debug "RHEL8 Deployment: Installing ${PKG}"
fi


removing_old_rpm() {
  old_rpm=$1
  if [ -f "${old_rpm}" ]; then
    log debug "Removing ${old_rpm}."
    out=$(rm -f ${old_rpm} 2>&1)
    # shellcheck disable=SC2181
    if [ $? -ne 0 ]; then
      log debug "Failed to remove ${old_rpm}. OUTPUT: $out"
    else
      log debug "Successfully removed ${old_rpm}"
    fi
  else
    log debug "${old_rpm} not present"
  fi
}


remove_package() {
  package=$1
  log debug "Attempting to uninstall ${package}"
  out=$(rpm -e --nodeps --allmatches "$package" 2>&1)
  installed=$(rpm -qa | grep -c "${package}")
  if [ "${installed}" -eq 0 ]; then
    log info "Successfully uninstalled ${package}"
  else
    log debug "${package} is still installed. Output: ${out}"
  fi
}

uninstall_old_postgres_versions() {
  # Get a list of all installed old postgres versions RPM packages
  # May need to remove EXTRclient once postgres version greater than 13
  # via a post uplift step
  # Need to ensure rh-postgresql96-postgresql-libs.x86_64
  # & rh-postgresql96-runtime.x86_64 do NOT get installed while RHEL7 exists
  old_postgres_packages=$(rpm -qa | grep -E 'postgresql10|postgresql11|postgresql92|postgresql94|postgresql-libs|ERICpostgresqlclient')
  # shellcheck disable=SC2181
  if [ $? -eq 0 ]; then
    log debug "Old postgres versions packages installed"
    while IFS= read -r pkg; do
      # On RHEL 7 psycopg2 needs postgres96 packages
      if [ $IS_RHEL7 -eq 0 ]; then
        # secserv and shmcoreserv require 94....This to be remove post tls1.3 phase 1 delivery
        if [[ "$pkg" == *"rh-postgresql96-postgresql-libs"* ]] || [[ "$pkg" == *"rh-postgresql94"* ]] || [[ "$pkg" == *"postgresql-libs"* ]]; then
          log debug "Skipping $pkg"
        else
          rm -f /var/lib/rpm/.rpm.lock
          remove_package "${pkg}"
        fi
      else
        rm -f /var/lib/rpm/.rpm.lock
        remove_package "${pkg}"
      fi
    done <<<"$old_postgres_packages"
  else
    log debug "No old postgres versions packages installed"
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
      /bin/grep 'is already installed' <<<"${out}"
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


create_slink() {
  # $1: source dir path
  # $2: file name
  # $3: target dir path
  log debug "Creating symbolic link from $1 to $3"
  ln -sf "$1""$2" "$3"
  if [[ $? -ne 0 ]]; then
    log error "Failed to set $1/$2 slink to $3. Exiting ${EXTR_NAME} postinstall"
    exit 1
  fi
}


# Guaranties compatibility of 'unknown' scripts that use 92 and 94 hardcoded paths
# on ENM initial install
set_slinks_to_deprecated_bin() {
  depr_bin=$1
  if [[ ! -f ${depr_bin}psql ]]; then
    log debug "Creating ${depr_bin} directory"
    mkdir -p "${depr_bin}"
    if [[ $? -ne 0 ]]; then
      log error "Failed to create ${depr_bin}. Exiting ${EXTR_NAME} postinstall"
      exit 1
    fi
    create_slink "${PG_BIN}" psql "${depr_bin}"
    create_slink "${PG_BIN}" dropdb "${depr_bin}"
    create_slink "${PG_BIN}" createdb "${depr_bin}"
    create_slink "${PG_BIN}" pg_isready "${depr_bin}"
  fi
}


set_slinks_to_latest() {
  mkdir -p ${PG_BIN}
  log debug "Removing any existing symbolic links from ${PG_BIN}"
  rm -rf "${PG_BIN}"*
  log info "Setting Postgres binary slinks from ${LATEST_PG_BIN} to ${PG_BIN}"
  ln -s "${LATEST_PG_BIN}"* "${PG_BIN}"

}


# Main
log info "Running ${EXTR_NAME} RPM Post-Install"

uninstall_old_postgres_versions
# For Future remove the following PG13 RPMs
#removing_old_rpm ${RPM_PATH}${PREVIOUS_PKG_1}
#removing_old_rpm ${RPM_PATH}${PREVIOUS_PKG_2}
# Next line is TD for the old EXTR
removing_old_rpm ${RPM_PATH_OLD}${PREVIOUS_PKG_2}
rpm_install
set_slinks_to_latest
set_slinks_to_deprecated_bin /opt/rh/postgresql/bin/
set_slinks_to_deprecated_bin /opt/rh/postgresql92/root/usr/bin/
set_slinks_to_deprecated_bin /opt/rh/rh-postgresql94/root/usr/bin/

log info "Finished ${EXTR_NAME} RPM Post-Install"
