# Usa la imagen oficial de WordPress
FROM wordpress:latest

# Instala herramientas útiles
RUN apt-get update && \
    apt-get install -y \
        curl \
        vim \
        less \
        unzip \
        zip \
    && apt-get clean

# Activa el modo de depuración
ENV WORDPRESS_DEBUG=1

# Instala plugin WP Super Cache automáticamente
RUN curl -L -o /tmp/wp-super-cache.zip https://downloads.wordpress.org/plugin/wp-super-cache.latest-stable.zip && \
    unzip /tmp/wp-super-cache.zip -d /usr/src/wordpress/wp-content/plugins/ && \
    rm /tmp/wp-super-cache.zip

# Establece permisos correctos
RUN chown -R www-data:www-data /var/www/html

EXPOSE 80
