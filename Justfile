build:
    docker build -t ghcr.io/simoncoles/private-journal:latest --platform linux/amd64 .

push:
    docker push ghcr.io/simoncoles/private-journal:latest

deploy:
    ssh simonc@simon-journal.anteater-catfish.ts.net 'docker pull ghcr.io/simoncoles/private-journal:latest && docker compose up -d chat'

console:
    ssh -t simonc@simon-journal.anteater-catfish.ts.net 'docker exec -it private-journal-1 /rails/bin/rails console'

shell:
    ssh -t simonc@simon-journal.anteater-catfish.ts.net 'docker exec -it private-journal-1 /bin/bash'
