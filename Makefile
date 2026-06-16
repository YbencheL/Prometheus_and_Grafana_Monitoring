USER ?= ociadmin
DOCKER_USER ?= yass555
# If you update the images update the tag too
TAG ?= 1.0

PROM_IMAGE ?= $(DOCKER_USER)/prometheus:$(TAG)
ALERT_IMAGE ?= $(DOCKER_USER)/alertmanager:$(TAG)
NODE_IMAGE ?= $(DOCKER_USER)/node-exporter:$(TAG)
GRAF_IMAGE ?= $(DOCKER_USER)/grafana:$(TAG)
NGINX_IMAGE ?= $(DOCKER_USER)/nginx:$(TAG)
NODES_IMAGE ?= $(DOCKER_USER)/node-serv:$(TAG)

ANSIBLE_PLAYBOOK ?= Ansible/setup.yml
ANSIBLE_INVENTORY ?= Ansible/inventory.ini

.PHONY: build build-images push deploy up down logs create-volumes start stop remote-stop

build: build-images push deploy

build-images:
	docker build -t $(PROM_IMAGE) Containers/Prometheus
	docker build -t $(ALERT_IMAGE) Containers/Alertmanager
	docker build -t $(NODE_IMAGE) Containers/Node-exporter
	docker build -t $(GRAF_IMAGE) Containers/Grafana
	docker build -t $(NGINX_IMAGE) Containers/Nginx
	docker build -t $(NODES_IMAGE) Containers/Node-serv

push:
	docker push $(PROM_IMAGE)
	docker push $(ALERT_IMAGE)
	docker push $(NODE_IMAGE)
	docker push $(GRAF_IMAGE)
	docker push $(NGINX_IMAGE)
	docker push $(NODES_IMAGE)

deploy:
	ansible-playbook -i $(ANSIBLE_INVENTORY) $(ANSIBLE_PLAYBOOK) \
	--vault-password-file ./Ansible/group_vars/sandbox/my_passwd.txt

remote-stop:
	ansible-playbook -i $(ANSIBLE_INVENTORY) $(ANSIBLE_PLAYBOOK) --ask-vault-pass --tags stop

remote-up:
	ansible-playbook -i $(ANSIBLE_INVENTORY) $(ANSIBLE_PLAYBOOK) --ask-vault-pass --tags up

remote-down:
	ansible-playbook -i $(ANSIBLE_INVENTORY) $(ANSIBLE_PLAYBOOK) --ask-vault-pass --tags down

up:
	docker compose -f ./Containers/docker-compose.yml up -d --build

down:
	docker compose -f ./Containers/docker-compose.yml down -v

start:
	docker compose -f ./Containers/docker-compose.yml start

stop:
	docker compose -f ./Containers/docker-compose.yml stop

logs:
	docker compose -f ./Containers/docker-compose.yml logs --tail=100