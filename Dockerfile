# Dockerfile para OpenSource Casino v10 (Laravel dentro de /casino)
FROM php:8.2-apache

# Instala dependências do sistema
RUN apt-get update && apt-get install -y \
    git \
    curl \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    zip \
    unzip \
    libzip-dev \
    nodejs \
    npm \
    && docker-php-ext-install pdo_mysql mbstring exif pcntl bcmath gd zip \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Instala Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Instala PM2 globalmente
RUN npm install -g pm2

# Define diretório de trabalho: pasta do Laravel
WORKDIR /var/www/html/casino

# Copia APENAS o conteúdo da pasta 'casino/' do repositório
COPY casino/. .

# Instala dependências PHP (agora composer.json existe aqui)
RUN composer install --optimize-autoloader --no-dev --no-scripts

# Instala dependências Node.js (se houver package.json na pasta casino/)
RUN if [ -f package.json ]; then npm install && npm run build; fi

# Permissões para Laravel
RUN chown -R www-data:www-data /var/www/html/casino \
    && chmod -R 755 /var/www/html/casino/storage \
    && chmod -R 755 /var/www/html/casino/bootstrap/cache

# Configura Apache para apontar para /casino/public
RUN a2enmod rewrite \
    && sed -i 's|DocumentRoot /var/www/html|DocumentRoot /var/www/html/casino/public|g' /etc/apache2/sites-available/000-default.conf \
    && echo "<Directory /var/www/html/casino/public>\n\
    AllowOverride All\n\
    Require all granted\n\
    </Directory>" >> /etc/apache2/sites-available/000-default.conf

# Gera chave e roda migrations (se .env existir)
RUN cp .env.example .env 2>/dev/null || true \
    && php artisan key:generate --force \
    && php artisan migrate --force --no-interaction || true \
    && php artisan storage:link || true

# Expõe porta 80
EXPOSE 80

# Script de inicialização: PM2 + Apache
RUN echo '#!/bin/bash\n\
set -e\n\
# Inicia PM2 (se ecosystem.config.js existir)\n\
if [ -f ecosystem.config.js ]; then\n\
  pm2 start ecosystem.config.js --env production || true\n\
fi\n\
# Inicia Apache\n\
apache2-foreground' > /start.sh \
    && chmod +x /start.sh

CMD ["/start.sh"]
