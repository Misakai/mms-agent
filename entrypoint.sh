#!/bin/bash
set -e

: ${MMS_SERVER:=https://mms.mongodb.com}
: ${MMS_MUNIN:=true}
: ${MMS_CHECK_SSL_CERTS:=true}

if [ ! "$MMS_API_KEY" ]; then
	{
		echo 'error: MMS_API_KEY was not specified'
		echo 'try something like: docker run -e MMS_API_KEY=... ...'
		echo '(see https://mms.mongodb.com/settings/monitoring-agent for your mmsApiKey)'
		echo
		echo 'Other optional variables:'
		echo ' - MMS_SERVER='"$MMS_SERVER"
		echo ' - MMS_MUNIN='"$MMS_MUNIN"
		echo ' - MMS_CHECK_SSL_CERTS='"$MMS_CHECK_SSL_CERTS"
	} >&2
	exit 1
fi

# "sed -i" can't operate on the file directly, and it tries to make a copy in the same directory, which our user can't do
# Note this might cause problems with overriding settings as we just load a new file
# instead of the correct config file. This may be an issue for more complicated deployments
monitoring_config="$(mktemp)"
cat /etc/mongodb-mms/monitoring-agent.config > "$monitoring_config"
backup_config="$(mktemp)"
cat /etc/mongodb-mms/backup-agent.config > "$backup_config"


set_config() {
	key="$1"
	value="$2"
	sed_escaped_value="$(echo "$value" | sed 's/[\/&]/\\&/g')"
	sed -ri "s/^($key)[ ]*=.*$/\1 = $sed_escaped_value/" "$monitoring_config"
	sed -ri "s/^($key)[ ]*=.*$/\1 = $sed_escaped_value/" "$backup_config"
}

set_config mmsApiKey "$MMS_API_KEY"
set_config mmsBaseUrl "$MMS_SERVER"
set_config enableMunin "$MMS_MUNIN"
set_config sslRequireValidServerCertificates "$MMS_CHECK_SSL_CERTS"

#copy the settings to both config file locations
cat "$monitoring_config" > monitoring-agent.config
rm "$monitoring_config"

cat "$backup_config" > backup-agent.config
cat "$backup_config" > local.config
rm "$backup_config"

exec "$@"
