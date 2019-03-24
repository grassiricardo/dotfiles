#!/bin/sh

echo "stop all rails consoles..."
docker ps -a | grep '/exec rails c' | cut -d ' ' -f 1 | xargs docker stop

echo "stop all but tagged containers"
docker ps -a | grep -v ':' | grep -v 'CONTAINER' | grep -v 'Up ' | cut -d ' ' -f 1|xargs docker stop

echo "remove all stopped containers"
docker rm -v $(docker ps -a -q -f status=exited)

echo "remove all created - but never used - containers"
docker rm -v $(docker ps -a -q -f status=created)

echo "removed all unused images"
docker rmi $(docker images -f "dangling=true" -q)

echo "remove all unused volumes"
docker run -v /var/run/docker.sock:/var/run/docker.sock -v /var/lib/docker:/var/lib/docker --rm scripts/docker-cleanup-volumes

echo "send confirmation to slack"
curl -X POST --data-urlencode 'payload={"channel": "#general", "text": "Run Clear Docker To EC2 production-api", "icon_emoji": ":white_check_mark:"}' https://hooks.slack.com/services/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

sudo chmod 777 scripts/docker-cleanup.sh

* 2 * * * ./scripts/docker-cleanup.sh