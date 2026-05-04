# cronjob-template

Template repository para **jobs agendados** — tarefas que rodam em horários fixos
(via expressão cron) e terminam. Deploy via
[`platform-k8s-cronjob-chart`](https://github.com/pagamericantech/platform-charts/tree/main/platform-k8s-cronjob-chart).

Para outros tipos de workload, use o template correspondente:

- [`web-template`](https://github.com/pagamericantech/web-template) — apps HTTP (Deployment + HTTPRoute + Argo Rollouts canary).
- [`worker-template`](https://github.com/pagamericantech/worker-template) — consumers/workers sem entrada HTTP.
- **`cronjob-template`** (este) — jobs agendados.

## Estrutura

```
.
├── .github/workflows/build_and_deploy.yaml   # chama _reusable-docker-build-push.yml
├── chart/
│   └── values-k8s-shared-services.yaml       # override do platform-k8s-cronjob-chart
├── Dockerfile                                # build do app (placeholder)
├── .dockerignore
└── .gitignore
```

O fluxo é idêntico aos outros templates: push em `main` → build/push pra ECR →
bump da `image.tag` no values → reconcile do ArgoCD → deploy via chart
compartilhado, que cria um `CronJob` (não Deployment).

## Como criar um novo cronjob a partir desse template

```bash
gh repo create pagamericantech/<job-name> \
  --template pagamericantech/cronjob-template \
  --private \
  --clone

cd <job-name>

APP=meu-job
IMAGE=pga-meu-job
OWNER=meu-time
LANG=go

find . -type f \( -name '*.yaml' -o -name '*.yml' \) -not -path './.git/*' -print0 | \
  xargs -0 sed -i '' \
    -e "s/__APP_NAME__/${APP}/g" \
    -e "s/__IMAGE_NAME__/${IMAGE}/g" \
    -e "s/__OWNER__/${OWNER}/g" \
    -e "s/__LANGUAGE__/${LANG}/g"
```

## Configuração específica de cronjob

Após substituir os placeholders, edite `chart/values-k8s-shared-services.yaml`:

- **`cronjob.schedule`** — expressão cron Quartz-like (minute hour day-of-month month day-of-week).
  Default `"0 * * * *"` = de hora em hora. Ferramenta útil pra montar/validar:
  [crontab.guru](https://crontab.guru/).
- **`cronjob.timeZone`** — IANA, ex: `"America/Sao_Paulo"`. Vazio = UTC.
- **`cronjob.concurrencyPolicy`** — `Forbid` (default) pula a próxima execução se
  a anterior ainda roda. `Allow` permite paralelas. `Replace` mata a anterior.
- **`cronjob.backoffLimit`** — quantas tentativas antes de marcar o Job como falho
  (`0` = falha na primeira tentativa, sem retry).
- **`cronjob.ttlSecondsAfterFinished`** — auto-cleanup do Job após N segundos.
  Default 1 dia (`86400`); aumentar se precisar inspecionar logs por mais tempo.
- **`resources`** — limites de CPU/memory do Job. Se o job for I/O-bound ou puxa
  dados grandes, ajustar.

## Comportamento esperado (vs web/worker)

- **Sem `replicaCount`** — k8s CronJob controller spawna 1 `Job` por execução
  agendada; cada Job cria 1 pod.
- **Sem `autoscaling`** — KEDA não escala CronJobs (escala Deployments/Rollouts).
  Pra paralelismo dentro de uma execução, configurar `parallelism`/`completions`
  na spec do Job (não exposto no chart por default — abrir issue se precisar).
- **Sem `httpRoute`** — jobs não recebem tráfego.

## Marcar como template no GitHub

```bash
gh repo edit pagamericantech/cronjob-template --template
```
