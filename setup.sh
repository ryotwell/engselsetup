# OS: Debian 11

DOMAIN="sg2.engsel.qzz.io"

# install nginx
apt update
apt install nginx -y

rm -rf /etc/nginx/nginx.conf
mv nginx.conf /etc/nginx/nginx.conf

sed -i "s/xxxxxx/${DOMAIN}/g" engsel.conf

rm -rf /etc/nginx/conf.d/engsel.conf
mv engsel.conf /etc/nginx/conf.d/engsel.conf

# test nginx
nginx -t

# reload nginx
systemctl reload nginx