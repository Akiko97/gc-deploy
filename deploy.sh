# install dependencies
# curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install openjdk-17-jdk docker.io docker-compose git vim socat nodejs npm python3
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
mkdir database
cd database
touch mongod.log
cat > mongod.conf << EOF
storage:
  dbPath: /data/db
  journal:
    enabled: true

systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log

net:
  port: 27017
  bindIp: 0.0.0.0

processManagement:
  timeZoneInfo: /usr/share/zoneinfo
EOF
mkdir db
# cat > docker-compose.yaml << EOF
# version: "3"

# services:
#   mongodb:
#     image: mongo:latest
#     container_name: gc-mongo
#     ports:
#       - 28019:27017
#     volumes:
#       - ./mongod.conf:/etc/mongod.conf
#       - ./mongod.log:/var/log/mongodb/mongod.log
#       - ./db:/data/db
#     entrypoint: ["mongod", "--auth", "--config", "/etc/mongod.conf"]
# EOF
cat > docker-compose.yaml << EOF
version: "3"

services:
  mongodb:
    image: mongo:latest
    container_name: gc-mongo
    ports:
      - 28019:27017
    volumes:
      - ./mongod.conf:/etc/mongod.conf
      - ./mongod.log:/var/log/mongodb/mongod.log
      - ./db:/data/db
    entrypoint: ["mongod", "--config", "/etc/mongod.conf"]
EOF
sudo docker-compose up -d
# sudo docker exec -it gc-mongo mongosh
# use admin
# db.createUser({user: 'root',pwd: '62db08297241',roles:['userAdminAnyDatabase']})
# exit
# sudo docker exec -it gc-mongo mongosh -u root
# use grasscutter
# db.createUser({user: 'gc',pwd: '62db08297241',roles:['dbOwner'],authenticationRestrictions:[{clientSource:["x.x.x.x","x.x.x.x"]}]})
# exit
# uri: mongodb://gc:62db08297241@xxx.xxx.xxx.xxx:28019
cd -
# plugins
mkdir Grasscutter/plugins
cd Grasscutter/plugins
wget -c https://github.com/Akiko97/GCAuth/releases/download/v2.5.0-fix/gcauth-2.5.0-fix.jar
wget -c https://github.com/hamusuke0323/DroppedItemsKiller/releases/download/1.0.1/DroppedItemsKiller.jar
wget -c https://github.com/Penelopeep/SwitchElementTraveller/releases/download/v5/Switchelement.jar
wget -c https://github.com/jie65535/gc-opencommand-plugin/releases/download/v1.4.0/opencommand-dev-1.4.0.jar
wget -c https://github.com/ffauzan/id-look/releases/download/v1.0.3/IdLook-1.0.3.jar
    # Without testing
# wget -c https://github.com/liujiaqi7998/GrasscuttersWebDashboard/releases/download/V6.3.0/GrasscuttersWebDashboard-6.3.0.jar
    # Deprecated plugins (waiting for update)
# wget -c https://github.com/exzork/GCAuth/releases/download/v2.5.0/gcauth-2.5.0.jar
# wget -c https://github.com/Coooookies/Grasscutter-MeaNotice/releases/download/v1.0.3/MeaNotice-1.0-SNAPSHOT.jar
# wget -c https://github.com/Coooookies/Grasscutter-MeaMailPlus/releases/download/v1.0.3/MeaMailPlus-1.0-SNAPSHOT.jar
# wget -c https://github.com/gc-toolkit/GLAnnouncement/releases/download/1.0-publish/glannouncement-1.0-SNAPSHOT.jar
# wget -c https://github.com/gc-mojoconsole/gc-mojoconsole-backend/releases/download/dev-1.4.0/mojoconsole.jar
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
cp -a gcauth-web/dist/* nginx/html
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

        ssl_certificate            /etc/nginx/ssl/cert.pem;  #指定证书的位置，绝对路径
        ssl_certificate_key        /etc/nginx/ssl/key.pem;  #绝对路径，同上

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
