FROM parana/trusty-php

COPY docker-vhosts.conf /etc/apache2/sites-enabled/000-default.conf

# Set timezone
RUN echo 'date.timezone = Asia/Bangkok' > /etc/php5/apache2/php.ini

# Required extensions for this project
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        software-properties-common wget php5-mcrypt php-soap php5-intl php5-dev \
        libcurl3 php5-curl gettext \
        xvfb libxrender1 htop \
        && php5enmod mcrypt \
        && php5enmod soap \
        && a2enmod headers

# Install wkhtmltopdf
RUN wget https://downloads.wkhtmltopdf.org/0.12/0.12.4/wkhtmltox-0.12.4_linux-generic-amd64.tar.xz \
		&& tar xf wkhtmltox-0.12.4_linux-generic-amd64.tar.xz \
		&& cp wkhtmltox/bin/wkhtmltopdf /usr/bin \
		&& cp wkhtmltox/bin/wkhtmltoimage /usr/bin \
		&& rm wkhtmltox-0.12.4_linux-generic-amd64.tar.xz \
		&& rm -r wkhtmltox

# Install PHP CodeSniffer
RUN pear install PHP_CodeSniffer

# Setup locale & timezone
RUN locale-gen sv_SE.UTF-8
RUN locale-gen en_US.UTF-8

# Install PHPUnit 4.8 for PHP 5.5
RUN wget https://phar.phpunit.de/phpunit-old.phar
RUN chmod +x phpunit-old.phar
RUN mv phpunit-old.phar /usr/local/bin/phpunit

# Setup the Xdebug version to install
ENV XDEBUG_VERSION 2.2.7
ENV XDEBUG_MD5 71a6b75885207e79762e1e7aaf5c3993

# Install Xdebug
RUN set -x \
	&& curl -SL "http://www.xdebug.org/files/xdebug-$XDEBUG_VERSION.tgz" -o xdebug.tgz \
	&& echo $XDEBUG_MD5 xdebug.tgz | md5sum -c - \
	&& mkdir -p /usr/src/xdebug \
	&& tar -xf xdebug.tgz -C /usr/src/xdebug --strip-components=1 \
	&& rm xdebug.* \
	&& cd /usr/src/xdebug \
	&& phpize \
	&& ./configure \
	&& make -j"$(nproc)" \
	&& make install \
	&& make clean \
    && echo "zend_extension=$(find /usr/lib/php5/20121212/ -name xdebug.so)" > /etc/php5/cli/conf.d/10-xdebug.ini \
    && echo "xdebug.remote_enable=on" >> /etc/php5/cli/conf.d/10-xdebug.ini \
    && echo "xdebug.remote_handler=dbgp" >> /etc/php5/cli/conf.d/10-xdebug.ini \
    && echo "xdebug.remote_connect_back=1" >> /etc/php5/cli/conf.d/10-xdebug.ini \
    && echo "xdebug.remote_autostart=on" >> /etc/php5/cli/conf.d/10-xdebug.ini \
    && echo "xdebug.remote_port=9004" >> /etc/php5/cli/conf.d/10-xdebug.ini


# Set default volume for image
# This would be overrided by docker-compose for updatable source code between development
COPY . /data
WORKDIR /data

# Fixes user permissions for Mac OS [https://github.com/boot2docker/boot2docker/issues/581]
RUN usermod -u 1000 www-data
RUN usermod -G staff www-data

# Setup cronjob for Indatus/dispatcher
RUN crontab -l | { cat; echo "* * * * * cd /data && php artisan scheduled:run 1>> /dev/null 2>&1"; } | crontab -

# Supervisor setup for queue process
ADD supervisor-laravel-queue.conf /etc/supervisor/conf.d/supervisord-laravel-queue.conf

CMD ["/run.sh"]