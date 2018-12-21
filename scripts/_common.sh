ynh_add_nginx5_config () {
	PHP5=$(echo "php 5.6" | tr -d ' ')
	finalnginxconf="/etc/nginx/conf.d/$domain.d/$app.conf"
	local others_var=${1:-}
	ynh_backup_if_checksum_is_different "$finalnginxconf"
	sudo cp ../conf/nginx.conf "$finalnginxconf"

	# To avoid a break by set -u, use a void substitution ${var:-}. If the variable is not set, it's simply set with an empty variable.
	# Substitute in a nginx config file only if the variable is not empty
	if test -n "${path_url:-}"; then
		# path_url_slash_less is path_url, or a blank value if path_url is only '/'
		local path_url_slash_less=${path_url%/}
		ynh_replace_string "__PATH__/" "$path_url_slash_less/" "$finalnginxconf"
		ynh_replace_string "__PATH__" "$path_url" "$finalnginxconf"
	fi
	if test -n "${domain:-}"; then
		ynh_replace_string "__DOMAIN__" "$domain" "$finalnginxconf"
	fi
	if test -n "${port:-}"; then
		ynh_replace_string "__PORT__" "$port" "$finalnginxconf"
	fi
	if test -n "${app:-}"; then
		ynh_replace_string "__NAME__" "${PHP5}-fpm-$app" "$finalnginxconf"
	fi
	if test -n "${final_path:-}"; then
		ynh_replace_string "__FINALPATH__" "$final_path" "$finalnginxconf"
	fi

		
	# Replace all other variable given as arguments
	for var_to_replace in $others_var
	do
		# ${var_to_replace^^} make the content of the variable on upper-cases
		# ${!var_to_replace} get the content of the variable named $var_to_replace 
		ynh_replace_string "__${var_to_replace^^}__" "${!var_to_replace}" "$finalnginxconf"
	done
	
	if [ "${path_url:-}" != "/" ]
	then
		ynh_replace_string "^#sub_path_only" "" "$finalnginxconf"
	else
		ynh_replace_string "^#root_path_only" "" "$finalnginxconf"
	fi

	ynh_store_file_checksum "$finalnginxconf"

	sudo systemctl reload nginx
}

ynh_add_fpm5_config () {
	
	PHP5=$(echo "php 5.6" | tr -d ' ')
	local fpm_config_dir="/etc/php/5.6/fpm"
	local fpm_service="${PHP5}-fpm"
	
	ynh_app_setting_set $app fpm_config_dir "/etc/php/5.6/fpm"
	ynh_app_setting_set $app fpm_service "${PHP5}-fpm"
	finalphpconf="/etc/php/5.6/fpm/pool.d/$app.conf"
	sudo cp ../conf/php-fpm.conf "$finalphpconf"
	ynh_replace_string "__NAMETOCHANGE__" "$app" "$finalphpconf"
	ynh_replace_string "__PHPNAMETOCHANGE__" "${PHP5}-fpm-$app" "$finalphpconf"
	ynh_replace_string "__FINALPATH__" "$final_path" "$finalphpconf"
	ynh_replace_string "__USER__" "$app" "$finalphpconf"
	sudo chown root: "$finalphpconf"
	ynh_store_file_checksum "$finalphpconf"

	echo $fpm_service
	
	if [ -e "../conf/php-fpm.ini" ]
	then
		echo "Please do not use a separate ini file, merge you directives in the pool file instead." &>2
	fi
	sudo systemctl reload ${PHP5}-fpm
}

ynh_add_fpm5original_config () {
	
	local fpm_config_dir="/etc/php/5.6/fpm"
	local fpm_service="php5.6-fpm"
	# Configure PHP-FPM 5 on Debian Jessie
	if [ "$(ynh_get_debian_release)" == "jessie" ]; then
		fpm_config_dir="/etc/php5/fpm"
		fpm_service="php5-fpm"
	fi
	ynh_app_setting_set $app fpm_config_dir "$fpm_config_dir"
	ynh_app_setting_set $app fpm_service "$fpm_service"
	finalphpconf="$fpm_config_dir/pool.d/$app.conf"
	ynh_backup_if_checksum_is_different "$finalphpconf"
	sudo cp ../conf/php-fpm.conf "$finalphpconf"
	ynh_replace_string "__NAMETOCHANGE__" "$app" "$finalphpconf"
	ynh_replace_string "__FINALPATH__" "$final_path" "$finalphpconf"
	ynh_replace_string "__USER__" "$app" "$finalphpconf"
	sudo chown root: "$finalphpconf"
	ynh_store_file_checksum "$finalphpconf"

	if [ -e "../conf/php-fpm.ini" ]
	then
		echo "Please do not use a separate ini file, merge you directives in the pool file instead." &>2
	fi
	sudo systemctl reload $fpm_service
}

# Remove the dedicated php-fpm config
#
# usage: ynh_remove_fpm5_config
ynh_remove_fpm_config () {
	local fpm_config_dir=$(ynh_app_setting_get $app fpm_config_dir)
	local fpm_service=$(ynh_app_setting_get $app fpm_service)
	
	ynh_secure_remove "$fpm_config_dir/pool.d/$app.conf"
	ynh_secure_remove "$fpm_config_dir/conf.d/20-$app.ini" 2>&1
	sudo systemctl reload $fpm_service
}
