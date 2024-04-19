#!/bin/bash

# Update package list
sudo apt-get update

# Install Nginx
sudo apt-get install -y nginx

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
    listen 443 default_server;
    server_name _;

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