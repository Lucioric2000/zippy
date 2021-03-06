
# installation makefile

ZIPPYPATH=/usr/local/zippy
ZIPPYVAR=/var/local/zippy
ZIPPYWWW=/var/www/zippy
ZIPPYTMP=/tmp/zippy
SOURCE=zippy
VERSION := $(shell cat version.dat)
ROOT=/root
CONFIG_FILE="zippy/zippy.json"
#CONFIG_FILE="zippy/extra_configs/zippy_v7.6.json"
#See which distro does the host have
#distro can be centos or ubuntu
DISTRO := $(shell bash -c "yum --help&>/dev/null && echo centos || echo ubuntu")

genome=human_g1k_v37
ucsc_build=hg19
refgene_filename=refGene
server=nginx#Can be nginx or apache
server_suffix=_privateserver
env_suffix=#Can be an empty string, _dev or _docker

ifneq (,$(findstring ubuntu,$(DISTRO)))
	#distro=ubuntu2
	WWWGROUP=www-data
	WWWUSER=flask
	PKGINSTALL=apt-get
	distro_suffix=
	ifeq ($(server),nginx)
		serving_packages=nginx
	else
		serving_packages=apache2 apache2.2-common apache2-mpm-prefork apache2-utils libexpat1 ssl-cert libapache2-mod-wsgi
		apachedirtitle=apache2
	endif
else
	#distro=centos2
	WWWGROUP=$(server)
	WWWUSER=$(server)
	PKGINSTALL=yum
	distro_suffix=_centos
	ifeq ($(server),nginx)
		serving_packages=nginx
	else
		serving_packages=mod_wsgi httpd
		apachedirtitle=httpd
	endif
endif

ifeq ($(env_suffix),_dev)
	environment=_dev
else
	environment=
endif

ifeq ($(server),apache)
	theotherserver=nginx
else
	theotherserver=apache
endif

# development installs (with mounted volume)
all: install resources webservice

essential: essential_${DISTRO}
very_essential: very_essential_${DISTRO}
install: essential bowtie zippy-install
webservice: webservice_${DISTRO}
stop: stop_${server}_service
#webservice-docker: webservice-docker_${DISTRO}
webservice-dev: webservice-dev_${DISTRO}

deploy: cleansoftware cleandb zippy-install webservice
deploy-dev: cleansoftware cleandb zippy-install webservice-dev



# requirements
essential_ubuntu:
	echo Distro: ${DISTRO}
	echo Zippy version: ${VERSION}
	sudo apt-get -y update && sudo apt-get -y upgrade
	sudo apt-get install -y sudo less make wget curl vim apt-utils firewalld
	sudo apt-get install -y sqlite3 unzip htop libcurl3-dev libbz2-dev liblzma-dev #git
	#sudo apt-get install -y python-pip python2.7-dev python-virtualenv
	sudo apt-get install -y python3-pip python3-dev python3-virtualenv mysql-server
	sudo apt-get install -y libxslt-dev libxml2-dev libffi-dev redis-server mysql-client ncurses-dev
	sudo apt-get install -y postgresql postgresql-client postgresql libpq-dev #postgresql-server-dev-9.4
	# add apache user
	sudo useradd -M $(WWWUSER) || echo User $(WWWUSER) already existed
	sudo usermod -s /bin/false $(WWWUSER)
	sudo usermod -L $(WWWUSER)
	sudo adduser $(WWWUSER) $(WWWGROUP)
	# install apache/wsgi
	sudo apt-get install -y $(serving_packages)

essential_centos:
	echo Distro: ${DISTRO}
	echo Zippy version: ${VERSION}
	sudo yum -y install epel-release
	sudo yum repolist
	sudo yum -y update --skip-broken
	sudo yum install -y sudo wget less make curl vim sqlite unzip htop python3-pip python3-devel ncurses-devel gzip #git
	#apachectl restart graceful
	#kill -USR1 `cat /usr/local/httpd/logs/httpd.pid`
	#kill -USR1 `cat /usr/local/apache2/logs/httpd.pid`
	sudo yum install -y libxslt-devel libxml2-devel libffi-devel redis #python3-virtualenv
	sudo yum install -y $(serving_packages)
	echo y|sudo yum groupinstall 'Development Tools'
	sudo yum install -y libjpeg-devel freetype-devel python3-imaging mysql postgresql postgresql-devel #-client llibcurl3-devel
	sudo groupadd -f $(WWWGROUP)
	getent passwd $(WWWUSER)>/dev/null||sudo adduser $(WWWUSER) -g $(WWWGROUP)
	#If the user does exists, does not execute the part of the command. This behavior is
	#achieved because this instruction is taken as a boolean construct (as all in shell finally, that lines have a return code), with || as the operator (OR).
	#If the first command (before the ||) gives a zero return value (if the user exists) there is no need to execute the second part of the statement to 
	#calculate the return value of the line
	sudo usermod -s /bin/false $(WWWUSER)
	sudo usermod -L $(WWWUSER)
	# disable default site
	#a2dissite 000-default

print_flags:
	@echo "Installing Zippy ${VERSION} for distro $(DISTRO)"
	@echo "Installing for server $(server), location ${server_suffix} and enviromnent ${env_suffix}"

very_essential_ubuntu:
	apt-get -y update
	apt-get -y upgrade
	apt-get install -y sudo
	sudo apt-get install -y sudo less make wget curl vim apt-utils rsync

very_essential_centos:
	yum -y update --skip-broken
	yum -y upgrade --skip-broken
	yum install -y sudo
	sudo yum install -y sudo wget less make curl vim rsync

bowtie:
	wget -c http://netix.dl.sourceforge.net/project/bowtie-bio/bowtie2/2.2.6/bowtie2-2.2.6-linux-x86_64.zip && \
	unzip bowtie2-2.2.6-linux-x86_64.zip && \
	cd bowtie2-2.2.6 && sudo mv bowtie2* /usr/local/bin
	rm -rf bowtie2-2.2.6 bowtie2-2.2.6-linux-x86_64.zip

# zippy setup (will move to distutils in future release)
update-zippy-package:
	sudo rsync -a . $(ZIPPYPATH)
	sudo chown -R $(WWWUSER):$(WWWGROUP) $(ZIPPYPATH)
zippy-install:
	# virtualenv
	sudo mkdir -p $(ZIPPYPATH)
	cd $(ZIPPYPATH) && sudo python3 -mvenv venv
	sudo $(ZIPPYPATH)/venv/bin/pip install --upgrade pip
	sudo $(ZIPPYPATH)/venv/bin/pip install wheel
	sudo $(ZIPPYPATH)/venv/bin/pip install Cython #==0.24
	sudo $(ZIPPYPATH)/venv/bin/pip install -r requirements.txt
	#sudo rsync -a --exclude-from=.gitignore . $(ZIPPYPATH)
	sudo rsync -a . $(ZIPPYPATH)
	sudo chown -R $(WWWUSER):$(WWWGROUP) $(ZIPPYPATH)
	cd $(ZIPPYPATH)/download && sudo $(ZIPPYPATH)/venv/bin/python setup.py install
	#cd $(ZIPPYPATH) && sudo $(ZIPPYPATH)/venv/bin/python setup.py install
	#sudo chown -R $(WWWUSER):$(WWWGROUP) $(ZIPPYPATH)
	# create empty database
	sudo mkdir -p $(ZIPPYVAR)
	sudo mkdir -p $(ZIPPYVAR)/logs
	sudo mkdir -p $(ZIPPYVAR)/uploads
	sudo mkdir -p $(ZIPPYVAR)/results
	sudo mkdir -p $(ZIPPYVAR)/resources
	sudo touch $(ZIPPYVAR)/zippy.sqlite
	sudo touch $(ZIPPYVAR)/zippy.log
	sudo touch $(ZIPPYVAR)/logs/gunicorn_access.log
	sudo touch $(ZIPPYVAR)/logs/gunicorn_error.log
	sudo touch $(ZIPPYVAR)/zippy.log
	sudo touch $(ZIPPYVAR)/logs
	#Creates a pickle dump of an empty list for the blacklist cache
	sudo $(ZIPPYPATH)/venv/bin/python -c "import pickle; pickle.dump([],open('$(ZIPPYVAR)/.blacklist.cache','wb'))"
	#sudo touch $(ZIPPYVAR)/.blacklist.cache
	sudo touch $(ZIPPYVAR)/zippy.bed
	#sudo chmod 666 $(ZIPPYVAR)/zippy.sqlite $(ZIPPYVAR)/zippy.log $(ZIPPYVAR)/logs $(ZIPPYVAR)/.blacklist.cache $(ZIPPYVAR)/zippy.bed
	sudo rsync -avPp resources $(ZIPPYVAR)
	sudo chown -R $(WWWUSER):$(WWWGROUP) $(ZIPPYVAR)
	sudo chmod -R 777 $(ZIPPYVAR)


#Cleans
cleanall: cleansoftware cleandata cleandb #Deep clean, rarely needed
clean: cleandb cleansoftware
cleansoftware:
	sudo rm -rf $(ZIPPYPATH)
	sudo rm -rf $(ZIPPYWWW)
	sudo rm -f /etc/httpd/conf.d/zippy.conf
	sudo rm -f /etc/apache2/conf.d/zippy.conf
	sudo rm -f /etc/nginx/sites-enabled/zippy
	sudo rm -f /etc/nginx/sites-available/zippy
cleandata:
	sudo rm -rf $(ZIPPYTMP)
	sudo rm -rf $(ZIPPYVAR)
cleandb:
	sudo rm -f $(ZIPPYVAR)/zippy.sqlite
	sudo rm -f $(ZIPPYVAR)/zippy.log
	sudo rm -f $(ZIPPYVAR)/.blacklist.cache
	sudo rm -rf $(ZIPPYVAR)/uploads
	sudo rm -rf $(ZIPPYVAR)/results

clean_blacklist_cache:
	sudo $(ZIPPYPATH)/venv/bin/python -c "import pickle; pickle.dump([],open('$(ZIPPYVAR)/.blacklist.cache','wb'))"

# webservice install (production)
webservice_ubuntu:
	# make WWW directories
	sudo mkdir -p $(ZIPPYWWW)
	sudo cp install/zippy$(environment).wsgi $(ZIPPYWWW)/zippy$(environment).wsgi
	sudo chown -R $(WWWUSER):$(WWWGROUP) $(ZIPPYWWW)

	# disable the apache server software (that can conflict with nginx port listening)
	make stop_$(theotherserver)_service$(env_suffix) &>/dev/null || echo "The apache service was not running"
	make disable_$(theotherserver)_service$(env_suffix) &>/dev/null || echo "The apache service was not enabled"

	# enable site and restart
	make start_$(server)_service$(env_suffix)
	make enable_$(server)_service$(env_suffix)
	make start_zippy_service$(env_suffix)
	make enable_zippy_service$(env_suffix)

# webservice install (production)
webservice_centos:
	# make WWW directories
	sudo mkdir -p $(ZIPPYWWW)
	sudo cp install/zippy$(environment).wsgi $(ZIPPYWWW)/zippy$(environment).wsgi
	sudo chown -R $(WWWUSER):$(WWWGROUP) $(ZIPPYWWW)

	# disable the apache server software (that can conflict with nginx port listening)
	make stop_$(theotherserver)_service$(env_suffix) &>/dev/null || echo "The apache service was not running"
	make disable_$(theotherserver)_service$(env_suffix) &>/dev/null || echo "The apache service was not enabled"

	# enable site and restart
	make start_$(server)_service$(env_suffix)
	make enable_$(server)_service$(env_suffix)
	make start_zippy_service$(env_suffix)
	make enable_zippy_service$(env_suffix)

start_apache_service:
	# enable site and restart
	#a2ensite zippy
	# apache WSGI config
	ls -lRt /etc/$(apachedirtitle)
	sudo cp install/zippy$(environment).hostconfig$(distro_suffix)$(server_suffix) /etc/$(apachedirtitle)/conf.d/zippy.conf
	#sudo ln -sf /etc/httpd/sites-available/zippy.conf /etc/httpd/sites-enabled/zippy.conf
	# disable default site
	sudo a2dissite 000-default
	#sudo echo "ServerName localhost" > /etc/httpd/conf.d/zippy_servernameconf.conf
	#/etc/init.d/apache2 start
	#/etc/init.d/apache2 restart
	sudo systemctl start nginx
	#Opens the port 80 in the firewall in the system, for public access
	#Disable SELINUX, this disabling is full while we don't know how to open only the sippy directories to SELINUX.
	sudo firewall-cmd --zone=public --add-service=http --permanent&&sudo firewall-cmd --reload||echo "You don't have a firewall running"
	sudo firewall-cmd --zone=public --add-port=5000/tcp --permanent&&sudo firewall-cmd --reload||echo "You don't have a firewall running"
	sudo setenforce 0||echo "Could not activate SELINUX properly"

start_apache_service_docker:
	# apache WSGI config
	ls -lt /etc
	echo adt $(apachedirtitle)
	ls -lt /etc/$(apachedirtitle)
	sudo cp install/zippy$(environment).hostconfig$(distro_suffix)$(server_suffix) /etc/$(apachedirtitle)/conf.d/zippy.conf
	#sudo ln -sf /etc/httpd/sites-available/zippy.conf /etc/httpd/sites-enabled/zippy.conf

enable_nginx_service:
	sudo systemctl enable nginx

disable_nginx_service:
	sudo systemctl disable nginx

enable_apache_service:
	sudo systemctl enable apache2

disable_apache_service:
	sudo systemctl disable apache2

enable_zippy_service:
	sudo systemctl enable zippy
	sudo systemctl enable zippy.socket

disable_zippy_service:
	sudo systemctl disable zippy
	sudo systemctl disable zippy.socket

start_nginx_service:
	# enable site and restart
	ls -lRt /etc/nginx
	sudo mkdir -p /etc/nginx/sites-available
	sudo mkdir -p /etc/nginx/sites-enabled
	sudo cp install/zippy /etc/nginx/sites-available/zippy
	sudo ln -sf /etc/nginx/sites-available/zippy /etc/nginx/sites-enabled/zippy
	#sudo cp install/zippy /etc/nginx/conf.d/zippy
	sudo systemctl restart nginx

start_zippy_service:
	sudo cp install/zippy.service /etc/systemd/system/zippy.service
	sudo cp install/zippy.socket /etc/systemd/system/zippy.socket
	sudo systemctl daemon-reload
	sudo systemctl restart zippy
	sudo systemctl restart zippy.socket
	#Opens the port 80 in the firewall in the system, for public access
	#Disable SELINUX, this disabling is full while we don't know how to open only the sippy directories to SELINUX.
	sudo firewall-cmd --zone=public --add-service=http --permanent&&sudo firewall-cmd --reload||echo "You don't have a firewall running"
	sudo firewall-cmd --zone=public --add-port=5000/tcp --permanent&&sudo firewall-cmd --reload||echo "You don't have a firewall running"
	sudo setenforce 0||echo "Could not activate SELINUX properly"

start_nginx_service_docker:
	# enable site and restart
	#sudo cp install/zippy /etc/nginx/sites-available/zippy
	#sudo ln -sf /etc/nginx/sites-available/zippy /etc/nginx/sites-enabled/zippy
	ls -lRt /etc/nginx
	sudo cp install/zippy /etc/nginx/conf.d/zippy
	sudo cp install/zippy.service /etc/systemd/system/zippy.service
	sudo cp install/zippy.socket /etc/systemd/system/zippy.socket

stop_apache_service:
	#/etc/init.d/apache2 stop
	sudo systemctl stop apache2

stop_nginx_service:
	sudo systemctl stop nginx

stop_zippy_service:
	sudo systemctl stop zippy
	sudo systemctl stop zippy.socket

# Webservers
gunicorn:
	bash -c "source $(ZIPPYPATH)/venv/bin/activate && gunicorn --bind 0.0.0.0:8000 wsgi:app"
run:
	bash -c "source $(ZIPPYPATH)/venv/bin/activate && FLASK_DEBUG=1 FLASK_ENV=development FLASK_APP=zippy CONFIG_FILE=$(CONFIG_FILE) $(ZIPPYPATH)/venv/bin/python run.py"
activate:
	bash -c "source $(ZIPPYPATH)/venv/bin/activate"
runp:
	bash -c "source $(ZIPPYPATH)/venv/bin/activate && CONFIG_FILE=$(CONFIG_FILE) python run.py"
test:
	bash -c "source $(ZIPPYPATH)/venv/bin/activate && CONFIG_FILE=$(CONFIG_FILE) python -m pytest zippy/unittest"
exons:
	#Example: make exons LOC=12:32895523-32895682 GENE=DNM1L
	bash -c "source $(ZIPPYPATH)/venv/bin/activate && CONFIG_FILE=$(CONFIG_FILE) python -m zippy.unittest.find_exons $(LOC) $(GENE)"
zippy:
	bash -c "source $(ZIPPYPATH)/venv/bin/activate && cd $(ZIPPYPATH)/zippy && python -m zippy.zippy -c $(CONFIG_FILE) ${@:2}"
pzippy:
	bash -c "source $(ZIPPYPATH)/venv/bin/activate && cd $(ZIPPYPATH)/zippy && python -m zippy.zippy -c $(CONFIG_FILE) ${@:2}"
dzippy:
	bash -c "source $(ZIPPYPATH)/venv/bin/activate && python -m zippy.zippy -c $(CONFIG_FILE) ${@:2}"

requirements:
	bash -c "source $(ZIPPYPATH)/venv/bin/activate && pip install -U pip"
	bash -c "source $(ZIPPYPATH)/venv/bin/activate && pip install -r requirements.txt"


#### genome resources
import-shipped-resources:
	# Copy resource files
	#sudo mkdir -p $(ZIPPYVAR)/resources
	rsync -avPp resources $(ZIPPYVAR)
	sudo chown -R $(WWWUSER):$(WWWGROUP) $(ZIPPYVAR)
import-shipped-refgene:
	# Copy resource files
	#sudo mkdir -p $(ZIPPYVAR)/resources
	rsync -avPp resources/refGene $(ZIPPYVAR)/resources/refGene
	sudo chown -R $(WWWUSER):$(WWWGROUP) $(ZIPPYVAR)
stash-resources:
	# Copy resource files
	echo Stashing resources
	sudo mkdir -p /srv/zippy_resources
	sudo cp -i $(ZIPPYVAR)/resources/* /srv/zippy_resources/
	sudo chown -R $(WWWUSER):$(WWWGROUP) /srv/zippy_resources
recover-resources:
	# Copy resource files
	echo Unstashing resources
	#sudo ln -s /srv/zippy_resources $(ZIPPYVAR)/resources
	sudo mkdir -p $(ZIPPYVAR)/resources
	sudo cp -i /srv/zippy_resources/* $(ZIPPYVAR)/resources/
	#for file in $(ls /srv/zippy_resources);
	#do
	#	sudo rm $(ZIPPYVAR)/$file
	#	sudo ln -s /srv/zippy_resources/$file $(ZIPPYVAR)/$file
	#done
	#sudo mv /srv/zippy_resources/* $(ZIPPYVAR)/resources/
	sudo chown -R $(WWWUSER):$(WWWGROUP) $(ZIPPYVAR)/resources

resources: genome annotation gnomad

genome: genome-download genome-index

genome-download:
	cd $(ZIPPYPATH) && sudo -u $(WWWUSER) $(ZIPPYPATH)/venv/bin/python download_resources.py $(ZIPPYVAR)/resources/${genome}.fasta http://ftp.1000genomes.ebi.ac.uk/vol1/ftp/technical/reference/${genome}.fasta.gz
	cd $(ZIPPYPATH) && sudo -u $(WWWUSER) $(ZIPPYPATH)/venv/bin/python download_resources.py $(ZIPPYVAR)/resources/${genome}.fasta.fai http://ftp.1000genomes.ebi.ac.uk/vol1/ftp/technical/reference/${genome}.fasta.fai
	sudo chmod 644 $(ZIPPYVAR)/resources/*
	sudo chmod 755 $(ZIPPYVAR)/resources
	sudo chown -R $(WWWUSER):$(WWWGROUP) $(ZIPPYVAR)/resources

genome-index:
	bash -c "ls $(ZIPPYVAR)/resources/${genome}.bowtie.rev.2.bt2 &>/dev/null && ( echo bowtie file $(ZIPPYVAR)/resources/${genome}.bowtie exists, thus not running bowtie command ) || ( cd $(ZIPPYVAR)/resources; echo running bowtie; source $(ZIPPYPATH)/venv/bin/activate; sudo -u $(WWWUSER) /usr/local/zippy/venv/bin/python /usr/local/bin/bowtie2-build $(ZIPPYVAR)/resources/${genome}.fasta $(ZIPPYVAR)/resources/${genome}.bowtie )"
	sudo chmod 644 $(ZIPPYVAR)/resources/*
	sudo chmod 755 $(ZIPPYVAR)/resources
	sudo chown -R $(WWWUSER):$(WWWGROUP) $(ZIPPYVAR)/resources

annotation: variation-download refgene-download

variation-download:
	#The files specified by the following commands did not exist as of 30 th, July, 2018, so that were updated by the later version present: b151_GRCh37p13
	sudo mkdir -p $(ZIPPYVAR)/resources

	#00-common_all.vcf.gz
	cd $(ZIPPYVAR)/resources && bash -c "ls 00-common_all.vcf.gz &>/dev/null && echo $(ZIPPYVAR)/resources/00-common_all.vcf.gz already found || sudo -u $(WWWUSER) wget -c ftp.ncbi.nlm.nih.gov/snp/organisms/human_9606_b151_GRCh37p13/VCF/00-common_all.vcf.gz"
	cd $(ZIPPYVAR)/resources && sudo -u $(WWWUSER) wget -c ftp.ncbi.nlm.nih.gov/snp/organisms/human_9606_b151_GRCh37p13/VCF/00-common_all.vcf.gz.tbi

	#00-All.vcf.gz
	cd $(ZIPPYVAR)/resources && bash -c "ls 00-All.vcf.gz &>/dev/null && echo $(ZIPPYVAR)/resources/00-All.vcf.gz already found || sudo -u $(WWWUSER) wget -c ftp.ncbi.nlm.nih.gov/snp/organisms/human_9606_b151_GRCh37p13/VCF/00-All.vcf.gz"
	cd $(ZIPPYVAR)/resources && sudo -u $(WWWUSER) wget -c ftp.ncbi.nlm.nih.gov/snp/organisms/human_9606_b151_GRCh37p13/VCF/00-All.vcf.gz.tbi
	

refgene-download:
	sudo firewall-cmd --zone=public --add-port=3306/tcp && sudo firewall-cmd --reload||echo "You didn't have the port 3306 blocked"
	bash -c "ls $(ZIPPYVAR)/resources/refGene &>/dev/null && echo $(ZIPPYVAR)/resources/refGene file exists || make refgene"

refgene:
	mysql --user=genome --host=genome-mysql.cse.ucsc.educ -A -N -D ${ucsc_build} -P 3306 -e "SELECT DISTINCT r.bin,CONCAT(r.name,'.',i.version),c.ensembl,r.strand, r.txStart,r.txEnd,r.cdsStart,r.cdsEnd,r.exonCount,r.exonStarts,r.exonEnds,r.score,r.name2,r.cdsStartStat,r.cdsEndStat,r.exonFrames FROM refGene as r, hgFixed.gbCdnaInfo as i, ucscToEnsembl as c WHERE r.name=i.acc AND c.ucsc = r.chrom ORDER BY r.bin;" | sudo -u $(WWWUSER) dd of=$(ZIPPYVAR)/resources/${refgene_filename}
	#sudo -u $(WWWUSER) bash -c "if [ -s $(ZIPPYVAR)/resources/${refgene_filename} ]; then echo file $(ZIPPYVAR)/resources/${refgene_filename}/${refgene_filename} is not empty; else cp $(ZIPPYPATH)/resources/${refgene_filename} $(ZIPPYVAR)/resources/${refgene_filename}; echo File $(ZIPPYVAR)/resources/${refgene_filename} got from bundle; fi"
	sudo -u $(WWWUSER) bash -c "if [ -s $(ZIPPYVAR)/resources/${refgene_filename} ]; then echo file $(ZIPPYVAR)/resources/${refgene_filename} is not empty; else cp ./resources/${refgene_filename} $(ZIPPYVAR)/resources/${refgene_filename}; echo File $(ZIPPYVAR)/resources/${refgene_filename} got from bundle; fi"

refgene_under_this_dir:
	mysql --user=genome --host=genome-mysql.cse.ucsc.edu -A -N -D ${ucsc_build} -P 3306 -e "SELECT DISTINCT r.bin,CONCAT(r.name,'.',i.version),c.ensembl,r.strand, r.txStart,r.txEnd,r.cdsStart,r.cdsEnd,r.exonCount,r.exonStarts,r.exonEnds,r.score,r.name2,r.cdsStartStat,r.cdsEndStat,r.exonFrames FROM refGene as r, hgFixed.gbCdnaInfo as i, ucscToEnsembl as c WHERE r.name=i.acc AND c.ucsc = r.chrom ORDER BY r.bin;" | sudo -u $(WWWUSER) dd of=resources/${refgene_filename}

gnomad:
	echo "Downloading chromosome files for GNOMAD..."
	mkdir -p $(ZIPPYTMP)
	sudo chown -R $(WWWUSER):$(WWWGROUP) $(ZIPPYTMP)
	bash -c "source $(ZIPPYPATH)/venv/bin/activate && sudo $(ZIPPYPATH)/venv/bin/python -m zippy.zippylib.gnomad -r $(ZIPPYVAR)/resources -u $(WWWUSER):$(WWWGROUP) -z $(ZIPPYPATH) -t $(ZIPPYTMP)"
	sudo chown -R $(WWWUSER):$(WWWGROUP) $(ZIPPYVAR)/resources

archive:
	rm -f $(SOURCE)_install_v*.bash
	rm -f $(SOURCE)-*.tar.gz
	echo $(VERSION)>version.dat
	p=`pwd` && rm -f $$p/$(SOURCE)-$(VERSION).tar.gz && tar --transform="s@^@$(SOURCE)-$(VERSION)/@" -cvzf $$p/$(SOURCE)-$(VERSION).tar.gz *
	cp -f $(SOURCE)_install.bash $(SOURCE)_install_v$(VERSION).bash
	chmod +x $(SOURCE)_install_v$(VERSION).bash

gitarchive:
	@echo Running git archive...
	@use HEAD if tag doesn't exist yet, so that development is easier...
	@rm -f $$p/$(SOURCE)-$(VERSION).tar.gz
	@git archive  --prefix=$(SOURCE)-$(VERSION)/ -o $(SOURCE)-$(VERSION).tar $(VERSION) 2> /dev/null || (echo 'Warning: $(VERSION) does not exist.' && git archive --prefix=$(SOURCE)-$(VERSION)/ -o $(SOURCE).tar HEAD)
	@#TODO: if git archive had a --submodules flag this would easier!
	@echo Running git archive submodules...
	@#I thought i would need --ignore-zeros, but it doesn't seem necessary!
	p=`pwd` && (echo .; git submodule foreach) | while read entering path; do \
		temp="$${path%\'}"; \
		temp="$${temp#\'}"; \
		path=$$temp; \
		[ "$$path" = "" ] && continue; \
		(cd $$path && git archive --prefix=$(SOURCE)-$(VERSION)/ HEAD > $$p/tmp.tar && tar --concatenate --file=$$p/$(SOURCE)-$(VERSION).tar $$p/tmp.tar && rm $$p/tmp.tar); \
	done && gzip -f $$p/$(SOURCE)-$(VERSION).tar

toroot: archive cleanrootinstallers
	sudo cp -f $(SOURCE)-$(VERSION).tar.gz $(ROOT)/$(SOURCE)-$(VERSION).tar.gz
	sudo cp -f $(SOURCE)_install.bash $(ROOT)/$(SOURCE)_install_v$(VERSION).bash
	sudo chmod +x $(ROOT)/$(SOURCE)_install_v$(VERSION).bash

cleanrootinstallers:
	sudo rm -rf $(ROOT)/zippy*

bump:
	echo ${VERSION}>version.dat

version:
	@echo ${VERSION}
#sudo firewall-cmd --zone=public --list-all
#sudo firewall-cmd --zone=public --add-port=5000/tcp
#sudo firewall-cmd --zone=public --add-service=http
#sudo firewall-cmd --reload
