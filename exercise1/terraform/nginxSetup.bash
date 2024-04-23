#!/bin/bash

# Update package list
sudo apt-get update

# Install Nginx
sudo apt-get install -y nginx

sudo mkdir /etc/nginx/ssl

sudo cp /var/lib/waagent/${CERTTHUMB}.crt /etc/nginx/ssl/crt.crt
sudo cp /var/lib/waagent/${CERTTHUMB}.prv /etc/nginx/ssl/key.key

# Create HTML file
sudo tee /var/www/html/index.html <<EOF
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
sudo tee /etc/nginx/sites-available/default <<EOF
server {
    listen 443 ssl default_server;
    server_name _;

    ssl_certificate /etc/nginx/ssl/crt.crt;
    ssl_certificate_key /etc/nginx/ssl/key.key; 

    root /var/www/html;
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

# Start Nginx
sudo systemctl start nginx

# Test Nginx configuration
sudo nginx -t

# Reload Nginx to apply changes
sudo systemctl reload nginx

echo "Nginx installed and configured to respond to port 443."