# 0. 基础参数，方便以后换版本
ARG PHP_VERSION=7.4.33
ARG ALPINE_VERSION=3.16

FROM php:${PHP_VERSION}-fpm-alpine${ALPINE_VERSION}

# 设置镜像源和安装基础软件
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories \
    && apk add --no-cache \
        sudo bash shadow git nginx supervisor tzdata \
        libzip icu-libs libpng libjpeg-turbo freetype libwebp libxslt \
        imagemagick librdkafka rabbitmq-c libgomp \
    && cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && echo "Asia/Shanghai" > /etc/timezone \
    && apk del tzdata

# PHP扩展安装
RUN apk add --no-cache --virtual .php-build-deps \
        $PHPIZE_DEPS autoconf g++ make openssl-dev curl-dev libxml2-dev libzip-dev \
        freetype-dev libjpeg-turbo-dev libpng-dev libwebp-dev oniguruma-dev icu-dev \
        libxslt-dev imagemagick-dev librdkafka-dev rabbitmq-c-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-install -j$(nproc) \
        pdo_mysql mysqli bcmath gd zip intl soap xsl exif pcntl posix sockets sysvmsg sysvsem sysvshm \
    && pecl install redis amqp rdkafka-6.0.3 openswoole-4.11.1 xlswriter imagick \
    && docker-php-ext-enable redis amqp rdkafka openswoole xlswriter imagick \
    && apk del .php-build-deps

# 安装Composer
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" \
    && php composer-setup.php --install-dir=/usr/local/bin --filename=composer \
    && php -r "unlink('composer-setup.php');" \
    && composer config -g repo.packagist composer https://mirrors.aliyun.com/composer/

# 配置和用户设置
RUN cp "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini" \
    && sed -i 's/^post_max_size = 8M/post_max_size = 100M/' $PHP_INI_DIR/php.ini \
    && sed -i 's/^upload_max_filesize = 2M/upload_max_filesize = 100M/' $PHP_INI_DIR/php.ini \
    && rm -f /etc/supervisord.conf \
    && echo "alias ll='ls -ahl'" >> ~/.bashrc \
    # 已经存在 www-data id 82
    # && addgroup -g 1000 www-data \
    # && adduser -u 1000 -G www-data -D -s /bin/bash www-data \
    && mkdir -p /var/www/html \
    && chown -R www-data:www-data /var/www/html

# 健康检查
# HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
#     CMD php-fpm -t || exit 1

WORKDIR /var/www/html
ENV LANG=C.UTF-8

EXPOSE 9000
CMD ["php-fpm"]
