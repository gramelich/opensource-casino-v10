# Dockerfile para OpenSource Casino v10 (Laravel + PHP + Node.js)
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

# Define diretório de trabalho
WORKDIR /var/www/html

# Copia o código do projeto
COPY . .

# Instala dependências PHP (Composer)
RUN composer install --optimize-autoloader --no-dev --no-scripts

# Instala dependências Node.js (se houver package.json)
RUN if [ -f package.json ]; then npm install && npm run build; fi

# Permissões para Laravel
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html/storage

# Configura Apache para Laravel
RUN a2enmod rewrite \
    && echo "<VirtualHost *:80>\n\
DocumentRoot /var/www/html/public\n\
<Directory /var/www/html/public>\n\
AllowOverride All\n\
</Directory>\n\
</VirtualHost>" > /etc/apache2/sites-available/000-default.conf

# Gera chave de app Laravel e roda migrations (assumindo .env pronto)
RUN if [ -f .env ]; then cp .env .env.example; fi \
    && php artisan key:generate \
    && php artisan migrate --force

# Expõe porta 80
EXPOSE 80

# Script de inicialização (inicia Apache e PM2)
RUN echo '#!/bin/bash\n\
pm2 start ecosystem.config.js --env production || true\n\
apache2-foreground' > /start.sh \
    && chmod +x /start.sh

CMD ["/start.sh"]Dockerfile
