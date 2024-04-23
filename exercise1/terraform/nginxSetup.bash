#!/bin/bash

# run as root
sudo su

# Update package list
apt update

# Install Nginx
apt install -y nginx

# Grabbing key vault cert
mkdir /etc/nginx/ssl
cp /tmp/${AKV_NAME}.${CERT_NAME} /etc/nginx/ssl

# exporting private key and cert
cd /etc/nginx/ssl
awk '/BEGIN PRIVATE KEY/,/END PRIVATE KEY/' ${AKV_NAME}.${CERT_NAME} > key.pem
awk '/BEGIN CERTIFICATE/,/END CERTIFICATE/' ${AKV_NAME}.${CERT_NAME} > crt.crt

# Create HTML file
tee /var/www/html/index.html <<EOF
<!DOCTYPE html>
<html>
<head>
<title>Hello, World!</title>
</head>
<body>
<h1>Hello, World!</h1>
</body>
</html>
EOF

# Configure Nginx to respond to port 443
tee /etc/nginx/sites-available/default <<EOF
server {
    listen 443 ssl default_server;
    server_name _;

    ssl_certificate /etc/nginx/ssl/crt.crt;
    ssl_certificate_key /etc/nginx/ssl/key.pem; 

    root /var/www/html;
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

# Start Nginx
systemctl start nginx

# Test Nginx configuration
nginx -t

# Reload Nginx to apply changes
systemctl reload nginx

echo "Nginx installed and configured to respond to port 443."