# install dependencies
sudo apt install openjdk-18-jdk docker.io git vim socat nodejs npm
sudo npm install -g npm@latest
# build
mkdir GCServer
cd GCServer
git clone https://github.com/Grasscutters/Grasscutter.git
git clone https://github.com/tamilpp25/Grasscutter_Resources.git
git clone https://github.com/Akiko97/gc-deploy.git
cd Grasscutter
ln -s ../Grasscutter_Resources/Resources resources
./gradlew jar
cp -a ../gc-deploy/* .
cd ..
# database
mkdir datebase
sudo docker run --name gc-mongo -p 27017:27017 -v $(pwd)/database:/data/db -d mongo:latest
# plugins
cd Grasscutter/plugins
sudo wget -c https://github.com/Akiko97/GCAuth/releases/download/v2.5.0-fix/gcauth-2.5.0-fix.jar
sudo wget -c https://github.com/hamusuke0323/DroppedItemsKiller/releases/download/1.0.1/DroppedItemsKiller.jar
sudo wget -c https://github.com/Penelopeep/SwitchElementTraveller/releases/download/v5/Switchelement.jar
sudo wget -c https://github.com/jie65535/gc-opencommand-plugin/releases/download/v1.4.0/opencommand-dev-1.4.0.jar
sudo wget -c https://github.com/ffauzan/id-look/releases/download/v1.0.3/IdLook-1.0.3.jar
    # Without testing
# sudo wget -c https://github.com/liujiaqi7998/GrasscuttersWebDashboard/releases/download/V6.3.0/GrasscuttersWebDashboard-6.3.0.jar
    # Deprecated plugins (waiting for update)
# sudo wget -c https://github.com/exzork/GCAuth/releases/download/v2.5.0/gcauth-2.5.0.jar
# sudo wget -c https://github.com/Coooookies/Grasscutter-MeaNotice/releases/download/v1.0.3/MeaNotice-1.0-SNAPSHOT.jar
# sudo wget -c https://github.com/Coooookies/Grasscutter-MeaMailPlus/releases/download/v1.0.3/MeaMailPlus-1.0-SNAPSHOT.jar
# sudo wget -c https://github.com/gc-toolkit/GLAnnouncement/releases/download/1.0-publish/glannouncement-1.0-SNAPSHOT.jar
# sudo wget -c https://github.com/gc-mojoconsole/gc-mojoconsole-backend/releases/download/dev-1.4.0/mojoconsole.jar
cd -
# nginx & cert
curl https://get.acme.sh | sh -s email=example@example.com
source ~/.bashrc
sudo setcap 'cap_net_bind_service=+ep' /usr/bin/socat
acme.sh --issue -d example.com --standalone
sudo docker pull nginx:latest
mkdir nginx
mkdir nginx/config
mkdir nginx/logs
mkdir nginx/html
mkdir nginx/conf.d
mkdir nginx/ssl
acme.sh --install-cert -d example.com --key-file nginx/ssl/key.pem --fullchain-file nginx/ssl/cert.pem
git clone https://github.com/Akiko97/gcauth-web.git
cd gcauth-web
npm install
npm run build
cd ..
sudo cp -a gcauth-web/dist/* nginx/html
touch nginx/config/nginx.conf
cat > nginx/config/nginx.conf << EOF
user  nginx;
worker_processes  auto;

error_log  /var/log/nginx/error.log notice;
pid        /var/run/nginx.pid;

events {
    worker_connections  1024;
}

http {
    client_max_body_size 100m;
    include mime.types;

    server {
        listen 80;
        server_name www.xxx.com;  #填写绑定证书的域名
        rewrite ^(.*) https://$server_name$1 permanent;
    }

    server {
        listen                     443 ssl;
        server_name                www.xxx.com;  #填写绑定证书的域名

        ssl_certificate            /etc/nginx/ssl/xxx.com.pem;  #指定证书的位置，绝对路径
        ssl_certificate_key        /etc/nginx/ssl/xxx.com.key;  #绝对路径，同上

        ssl_session_timeout        5m;
        ssl_protocols              TLSv1 TLSv1.1 TLSv1.2;
        ssl_ciphers                ECDHE-RSA-AES128-GCM-SHA256:HIGH:!aNULL:!MD5:!RC4:!DHE;
        ssl_prefer_server_ciphers  on;

        ssl_session_cache          shared:SSL:1m;

        fastcgi_param  HTTPS           on;
        fastcgi_param  HTTP_SCHEME     https;

        location / {
            proxy_set_header   X-Real-IP         $remote_addr;
            proxy_set_header   Host              $http_host;
            proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
            proxy_pass http://ip:port/;  #Grasscutter
        }

        location ^~ /gcauth {
            proxy_set_header   X-Real-IP         $remote_addr;
            proxy_set_header   Host              $http_host;
            proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
            alias   /usr/share/nginx/html;
            try_files $uri $uri/ /index.html;
        }
    }
    include /etc/nginx/conf.d/*.conf;
}
EOF
sudo docker run --name nginx -p 443:443 -p 80:80 -v $(pwd)/nginx/html:/usr/share/nginx/html -v $(pwd)/nginx/config/nginx.conf:/etc/nginx/nginx.conf -v $(pwd)/nginx/logs:/var/log/nginx/ -v $(pwd)/nginx/ssl:/etc/nginx/ssl/ --privileged=true -d --restart=always nginx
# run
screen sudo java -jar Grasscutter/grasscutter-1.3.2-dev.jar
