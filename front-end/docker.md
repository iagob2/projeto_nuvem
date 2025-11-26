## Como buildar:

```bash
docker build --build-arg VITE_API_URL="https://aws.com" -t dutradev/front-p2-cloud:latest .
```

- `VITE_API_URL` é o endereço da API
- `--build-arg` é usado para passar variáveis de ambiente em tempo de build

## Como rodar:

```bash
docker run -p 3000:80 dutradev/front-p2-cloud:latest
```
