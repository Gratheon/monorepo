start: start-storage start-router start-be start-fe

start-storage:
	cd ../mysql && make start
	cd ../redis && make start

start-router:
	cd ../graphql-schema-registry && make start && sleep 10
	cd ../graphql-router && make start

start-be:
	cd ../event-stream-filter &&	make start
	cd ../swarm-api &&	make start
	cd ../user-cycle &&	make start
	cd ../image-splitter &&	make start

start-fe:
	cd ../web-app &&	npm run dev
