NAME = inception

COMPOSE = docker compose -f srcs/docker-compose.yml

SECRETS_DIR = $(shell pwd)/secrets


all:
	./srcs/secrets_script.sh
	$(COMPOSE) up --build

down:
	$(COMPOSE) down

clean:
	$(COMPOSE) down -v
	rm -rf secrets

fclean:
	$(COMPOSE) down -v
	rm -rf secrets
	sudo rm -rf /home/tgomez-f/data/mariadb/*
	sudo rm -rf /home/tgomez-f/data/wordpress/*

re: fclean all