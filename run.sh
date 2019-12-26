# !/bin/bash

welcome() {
    cat<<-EOF

Welcome using Gongzq's AUTO Nginx deployer for totally beginners. Don't use it 
in any official occasion. The options are all simple and cannot just be used 
in official env.
欢迎使用Gongzq的Nginx部署脚本，千万别在正式环境中使用啊 = =

EOF
}

# the expand char cannot be " " and must be one single char.
expand_to_line() {
    info="$1"
    expand_char=${2:-"="}
    info_len=${#info}
    COLUMNS=$(tput cols)
    if [ $COLUMNS -gt 120 ] ; then
        COLUMNS=120
    fi
    eq_len=$(expr $(expr $COLUMNS - $info_len) / 2)
    eqs=$(seq -s $expand_char $eq_len | sed 's/[0-9]//g')
    echo "${eqs} ${info} ${eqs}"
}

hint() {
    info="$1"
    color="$2"
    if [ "$color" == "error" ] ; then
        info="\e[31m$info \e[0m"
    elif [ "$color" == "warning" ] ; then
        info="\e[33m$info \e[0m"
    elif [ "$color" == "info" ] ; then
        info="\e[32m$info \e[0m"
    else 
        info="$info"
    fi
    echo -e "$info"
}

line_hint() {
    info="$1"
    color="$2"
    hint "$(expand_to_line "$info")" $color
}

init_vars() {
    unset port
    unset path
    NGINX_CONF_FILE=/etc/nginx/nginx.conf
    NGINX_SITE_AVAILABLE_PATH=/etc/nginx/sites-available
    NGINX_SITE_ENABLE_PATH=/etc/nginx/sites-enabled
}

install_nginx() {
    line_hint "Detecting nginx status" info
    if_nginx=$(which nginx)
    if [ -z $(which nginx) ] ; then
        hint "No nginx installed" warning
        hint "Installing nginx by apt..." info
        apt install nginx -y
    else
        hint "Nginx installed." warning
    fi
}

input_with_default() {
    unset var
    hint="$1"
    default="$2"
    
    read -e -p "$hint (default[$default]): " var
    var=${var:-$default}
    echo "$var"
}

input_domain() {
    unset domain
    domain=$(timeout 10 curl -s ipinfo.io/ip)
    domain=$(input_with_default "Domain name you will use (at least input an ip address)" "$domain")
    if [ "$domain" == "" ] ; then
        hint "Sorry, but you have to input at least one domain name or ip address." error
        exit 1
    fi
    echo "$domain"
}

rm_if_exists() {
    [ -n "$1" ] && rm "$1"
}

configure_all() {
    rm_if_exists $config_file
    rm_if_exists $NGINX_SITE_ENABLE_PATH/$domain-$port
    
    if [[ $path == /root* ]]; then
        hint "修改 nginx.conf user to root" info
        # Change the first line user to root
        sed -i '1s/user www-data;/user root;/' $NGINX_CONF_FILE
    fi
    
    hint "初始化域名配置文件 $domain-$port" info
    cp $NGINX_SITE_AVAILABLE_PATH/default $NGINX_SITE_AVAILABLE_PATH/$domain-$port
    config_file="$NGINX_SITE_AVAILABLE_PATH/$domain-$port"
    hint "修改域名特定配置" info
    # 修改port
    sed -i -e "17c\    listen ${port};" $config_file
    sed -i -e "18c\    listen [::]:${port};" $config_file
    # 修改servername
    sed -i -e "36c\    root ${path};" $config_file
    sed -i -e "41c\    server_name ${domain};" $config_file

    # 修改link，激活该文件
    hint "激活域名配置源文件" info
    ln -s $config_file $NGINX_SITE_ENABLE_PATH/$domain-$port
}

show_configs() {
cat << EOF

    port:           ${port}
    html path:      ${path}
    server name:    ${domain}
    
EOF
}

# =============================================================================
# ==================================== main ===================================
# =============================================================================

welcome

init_vars
install_nginx

# make backup
cp $NGINX_SITE_AVAILABLE_PATH/default $NGINX_SITE_AVAILABLE_PATH/default.bkp

line_hint "Starting configure nginx..." info

port=$(input_with_default "The listening port" "80")
path=$(input_with_default "The root dir" "/var/www/html")
domain=$(input_domain)

line_hint "Check your options 检查你的配置 " info
show_configs

ok=$(input_with_default "确认[Y|N]" "Y")

if [[ "$ok" == "Y" || "$ok" == "" ]]; then
    line_hint "Ok, config begin! 开始配置！" info
    configure_all
    line_hint "配置结束" info
    hint "重新加载Nginx配置" info
    nginx -s reload
    hint "您的最终配置如下" info
    show_configs
else
    hint "Some wrong... plz configure again... " error
    hint "那只好重新配置了..." error
fi


# =============================================================================
# ================================== end main =================================
# =============================================================================

