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
	docker buildx build --platform linux/amd64,linux/arm64 -t $(PROM_IMAGE) \
	--push Containers/Prometheus
	docker buildx build --platform linux/amd64,linux/arm64 -t $(ALERT_IMAGE) \
	--push Containers/Alertmanager
	docker buildx build --platform linux/amd64,linux/arm64 -t $(NODE_IMAGE) \
	--push Containers/Node-exporter
	docker buildx build --platform linux/amd64,linux/arm64 -t $(GRAF_IMAGE) \
	--push Containers/Grafana
	docker buildx build --platform linux/amd64,linux/arm64 -t $(NGINX_IMAGE) \
	--push Containers/Nginx
	docker buildx build --platform linux/amd64,linux/arm64 -t $(NODES_IMAGE) \
	--push Containers/Node-serv

deploy:
	ansible-playbook -i $(ANSIBLE_INVENTORY) $(ANSIBLE_PLAYBOOK) \
	--vault-password-file ./Ansible/group_vars/sandbox/my_passwd.txt --ask-become-pass

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