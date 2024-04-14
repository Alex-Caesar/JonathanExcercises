#!/bin/bash

# Update package list
apt update

# Install Nginx
apt install -y nginx

# Configure Nginx to respond to port 443
tee /etc/nginx/sites-available/default <<EOF
server {
    listen 443 default_server;
    server_name _;

    location / {
        proxy_pass http://localhost:80;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Test Nginx configuration
nginx -t

# Reload Nginx to apply changes
systemctl reload nginx

echo "Nginx installed and configured to respond to port 443."