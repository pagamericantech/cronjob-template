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

O fluxo é idêntico aos outros templates:

1. **PR aberta** → `pr-checks.yml` roda `helm lint chart/` + `docker build` (sem push).
2. **Merge em `main`** → `build_and_deploy.yaml` builda + pusha imagem e bumpa `image.tag`. Pra `target_env ∈ {workspace, payments}`, bump em `chart/values-k8s-staging.yaml` (CD contínuo de staging); pros outros, bump no values primário.
3. **ArgoCD staging** sincroniza e cria/atualiza o `CronJob` no cluster `k8s-staging`.
4. **Release pra prod** → workflow `Release to production` (manual via Actions UI). Lê `image.tag` de staging, bumpa o values primário, force-pusha branch `release`.
5. **ArgoCD prod** (workspace/payments) segue `release` e atualiza o CronJob.

> ℹ️ Apps `target_env ∈ {staging, shared-services}` não têm release flow — o bootstrap deleta o `release.yml`. Rollback de prod: re-run do `Release to production` apontando pra commit anterior.

### Setup automatizado pelo bootstrap

- `.github/CODEOWNERS` com `chart/values-k8s-*.yaml @pagamericantech/infrastructure @pagamericantech/engineering` — protege os values do chart.
- Pra `target_env ∈ {workspace, payments}`: cria branch `release` (apontando pro main HEAD) e tenta criar ruleset "Protect release branch" (bloqueia `deletion` + `non_fast_forward`, bypass pro `pagamerican-gitops`). Se o ruleset falhar (token sem `Administration:Write`), emite warning — configure manualmente em **Settings → Rules → Rulesets**.

`release.yml` autentica via `pagamerican-gitops` (secrets `ORG_GITOPS_BOT_*`) — único actor com bypass.

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
