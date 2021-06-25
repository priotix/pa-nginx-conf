#!/bin/bash

read_var() {
    VAR=$(grep -n ^$1= $2 | cut -d '=' -f 2-)
    echo $(sed -e "s/^'//" -e "s/'$//" <<<"$VAR")
}

NGINX_CONF_ROOT="/tmp/nginx-conf"
NGINX_CONF_SH_TPL="${NGINX_CONF_ROOT}/security-headers.conf"
NGINX_DEFAULT_CONF_DIR="${NGINX_CONF_ROOT}/conf.d"
NGINX_TPL_HOSTS_DIR="${NGINX_CONF_ROOT}/hosts"
NGINX_DEFAULT_SERVER_CONF="${NGINX_CONF_ROOT}/default-server.conf"

NGINX_DIR="/etc/nginx"
NGINX_CONF="${NGINX_DIR}/nginx.conf"
NGINX_CONF_SH="${NGINX_DIR}/security-headers.conf"
NGINX_CONF_DIR="${NGINX_DIR}/conf.d"

echo "Starting preparing nginx..."

[ -f ${NGINX_CONF_ROOT}/.env ] && chmod a+x ${NGINX_CONF_ROOT}/.env && . ${NGINX_CONF_ROOT}/.env

NGINX_TPL_PRODUCT_HOSTS_DIR="${NGINX_TPL_HOSTS_DIR}/${HOST_ENV}"

echo "Searching for nginx server config for ${HOST_ENV}"
if [ -f "${NGINX_CONF_ROOT}/nginx.conf" ];then
  NGINX_CONF_TPL="${NGINX_CONF_ROOT}/nginx.conf"
else
  echo "No nginx config found => skipping ${HOST_ENV}"
  echo "Tried"
  echo "${NGINX_CONF_ROOT}/nginx-${HOST_ENV}.conf"
  echo "${NGINX_CONF_ROOT}/nginx.conf"
  continue
fi

echo "Using nginx server config ${NGINX_CONF_TPL}"

cp $NGINX_CONF_TPL $NGINX_CONF
sed -i "s/{{ulimit}}/$(ulimit -n)/" $NGINX_CONF

cp $NGINX_CONF_SH_TPL $NGINX_CONF_SH

echo "Setting up default configs"
cp -r ${NGINX_DEFAULT_CONF_DIR} ${NGINX_DIR}
cp ${NGINX_DEFAULT_SERVER_CONF} ${NGINX_DIR}

cd $NGINX_TPL_PRODUCT_HOSTS_DIR

BASIC_AUTH_HOST_LIST=$(echo $BASIC_AUTH_HOSTS | sed "s/,/ /g")

for d in $(echo $HOSTS | sed "s/,/ /g");do
  if [ -f "$d/.project.proj" ];then
    PROJ=$(head -n 1 "$d/.project.proj")

    echo "Configuring host for project ${PROJ}..."

    echo "Searching for nginx config for ${PROJ} ${HOST_ENV}"
    if [ -f "${d}/conf.d/nginx.conf" ];then
      CONF="${d}/conf.d/nginx.conf"
    else
      echo "No nginx config found => skipping ${PROJ}"
      echo "Tried"
      echo "${d}/conf.d/nginx.conf"
      continue
    fi
    echo "Using nginx config for ${PROJ} in ${CONF}"

    cp "${CONF}" "${NGINX_CONF_DIR}/${PROJ}.conf"

    DOMAIN="${PROJ}.${PRODUCT_NAME}"
    sed -i "s/{{domain}}/${DOMAIN}/g" "${NGINX_CONF_DIR}/${PROJ}.conf"
    sed -i "s/{{project}}/${PROJ}/g" "${NGINX_CONF_DIR}/${PROJ}.conf"
    sed -i "s/{{product}}/${PRODUCT_NAME}/g" "${NGINX_CONF_DIR}/${PROJ}.conf"

    if [[ $BASIC_AUTH_HOST_LIST =~ (^|[[:space:]])$d($|[[:space:]]) ]];then
      echo "Setting up basic authentication for $d"

      echo $BASIC_AUTH_CRED > /etc/nginx/.htpasswd

      sed -i "/#auth_basic.*/s/#//g" "${NGINX_CONF_DIR}/${PROJ}.conf"
    fi
  fi
done


[ "$?" == 0 ] && echo "done" || echo "FAIL"

echo "Finished preparing nginx."

echo "Starting nginx..."

nginx -g 'daemon off;'
