COMPOSE	= docker compose -f srcs/docker-compose.yml
DATA	= /home/alubrano/data

all:
	mkdir -p $(DATA)/mariadb $(DATA)/wordpress
	$(COMPOSE) up -d --build

down:
	$(COMPOSE) down

clean:
	$(COMPOSE) down --rmi all

fclean:
	$(COMPOSE) down --rmi all -v
	sudo rm -rf $(DATA)

re: fclean all

.PHONY: all down clean fclean re
