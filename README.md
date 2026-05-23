# Trainee DevOps API — Desafio Técnico

> **Programa Trainee Cloud & IA — IN8 Holding / Devnology**  
> Candidato: Gerge Abreu | Trilha: Cloud & IA

---

## Índice

1. [Sobre o Projeto](#sobre-o-projeto)
2. [Como Rodar Localmente](#como-rodar-localmente)
3. [Como o Pipeline Funciona](#como-o-pipeline-funciona)
4. [Decisões Técnicas](#decisões-técnicas)
5. [O que Faria com Mais Tempo](#o-que-faria-com-mais-tempo)
6. [Como Usei IA no Desafio](#como-usei-ia-no-desafio)

---

## Sobre o Projeto

API simples em Python/Flask com dois endpoints:

| Endpoint  | Resposta                                      |
|-----------|-----------------------------------------------|
| `GET /`   | `{"message": "Trainee DevOps API"}`           |
| `GET /health` | `{"status": "healthy", "timestamp": "...", "version": "1.0.0"}` |

### Estrutura de arquivos

```
trainee-devops/
├── app.py                  # Aplicação Flask
├── test_app.py             # Testes automatizados (pytest)
├── requirements.txt        # Dependências Python
├── Dockerfile              # Receita do container (multi-stage)
├── docker-compose.yml      # Orquestração local
├── healthcheck.sh          # Script de verificação de saúde
├── .gitlab-ci.yml          # Pipeline CI/CD completo
├── .gitignore              # Arquivos ignorados pelo Git
└── terraform/
    ├── main.tf             # Recursos AWS ECS
    ├── variables.tf        # Variáveis configuráveis
    └── outputs.tf          # Saídas após terraform apply
```

---

## Como Rodar Localmente

### Pré-requisitos

- [Docker](https://docs.docker.com/engine/install/) instalado
- [Docker Compose](https://docs.docker.com/compose/install/) instalado
- Python 3.11+ (para rodar fora do Docker)

### Opção 1 — Com Docker Compose (recomendado)

```bash
# Clonar o repositório
git clone <url-do-repositorio>
cd trainee-devops

# Subir a aplicação
docker-compose up --build

# Acessar no navegador ou terminal
curl http://localhost:5000/
curl http://localhost:5000/health

# Parar
docker-compose down
```

### Opção 2 — Com Docker puro

```bash
# Construir a imagem
docker build -t trainee-api .

# Rodar o container
docker run -p 5000:5000 trainee-api

# Testar
curl http://localhost:5000/health
```

### Opção 3 — Direto com Python (sem Docker)

```bash
# Criar ambiente virtual
python3 -m venv .venv
source .venv/bin/activate

# Instalar dependências
pip install -r requirements.txt

# Rodar a aplicação
flask run --host=0.0.0.0 --port=5000
```

### Rodando os testes

```bash
# Com ambiente virtual ativo
pytest test_app.py -v
```

### Rodando o healthcheck

```bash
# Com a aplicação rodando em outro terminal
chmod +x healthcheck.sh
./healthcheck.sh
# Saída esperada: API saudavel - status HTTP: 200
```

---

## Como o Pipeline Funciona

O pipeline é definido no arquivo `.gitlab-ci.yml` e é acionado automaticamente a cada `git push`. Ele executa 5 stages em sequência — se qualquer stage falhar, os seguintes não são executados.

```
git push
    ↓
lint → test → sast → build → deploy
```

### Stage 1 — `lint`

**Ferramenta:** flake8  
**O que faz:** Analisa o código Python em busca de erros de estilo e formatação, sem executá-lo. Garante que o código segue as convenções PEP 8 (padrão da comunidade Python).  
**Critério de falha:** Qualquer erro de lint faz o job falhar, bloqueando os stages seguintes.

```yaml
- flake8 app.py --max-line-length=88 --exclude=.venv,__pycache__
```

### Stage 2 — `test`

**Ferramenta:** pytest  
**O que faz:** Executa os testes automatizados do arquivo `test_app.py`. Verifica se os endpoints `/` e `/health` respondem com os status e conteúdos esperados.  
**Critério de falha:** Qualquer teste com falha interrompe o pipeline.

```yaml
- pip install -r requirements.txt --quiet
- pytest test_app.py -v
```

### Stage 3 — `sast`

**Ferramenta:** Bandit  
**O que faz:** Realiza uma varredura de segurança estática (SAST — Static Application Security Testing) no código Python. Procura vulnerabilidades conhecidas como senhas hardcoded, uso inseguro de funções, SQL injection, entre outros. Gera um relatório salvo como artefato por 7 dias.  
**Critério de falha:** Problemas de severidade MEDIUM ou HIGH causam falha no job.

```yaml
- bandit -r . -ll --exclude .venv,__pycache__ -o bandit-report.txt || true
```

### Stage 4 — `build`

**Ferramenta:** Docker + GitLab Container Registry  
**O que faz:** Constrói a imagem Docker usando o Dockerfile do projeto e faz push para o GitLab Container Registry com duas tags:
- Tag com o hash do commit (ex: `a1b2c3d`) — imutável e rastreável
- Tag `latest` — sempre aponta para o build mais recente

Utiliza Docker-in-Docker (`docker:24-dind`) para rodar Docker dentro do ambiente CI.

```yaml
- docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
- docker build -t $IMAGE_TAG -t $IMAGE_LATEST .
- docker push $IMAGE_TAG && docker push $IMAGE_LATEST
```

### Stage 5 — `deploy`

**O que faz:** Simula o deploy no AWS ECS imprimindo os comandos que seriam executados em produção. Inclui autenticação na AWS, atualização do serviço ECS e espera pela estabilização.  
**Restrição:** Roda **apenas na branch `main`**, usando a sintaxe moderna `rules:` do GitLab CI.

```yaml
rules:
  - if: $CI_COMMIT_BRANCH == "main"
```

### Cache de dependências

O pipeline utiliza cache do pip (`.cache/pip`) para reutilizar pacotes entre execuções, reduzindo significativamente o tempo de build a partir do segundo pipeline.

---

## Decisões Técnicas

### Dockerfile com Multi-stage Build

**Decisão:** Usar dois stages no Dockerfile (builder + final).  
**Motivo:** O stage de build precisa do pip e ferramentas de instalação. O stage final não precisa de nada disso — apenas das dependências já instaladas. Isso resultou em uma imagem final significativamente menor e com menor superfície de ataque de segurança.

### Usuário não-root no Container

**Decisão:** Criar um usuário `appuser` sem privilégios e executar a aplicação com ele.  
**Motivo:** Por padrão, processos em containers rodam como `root`. Se um atacante explorar uma vulnerabilidade na aplicação, ele teria acesso root ao container. Com um usuário sem privilégios, o impacto potencial é muito menor. Esta é uma prática fundamental de segurança em containers.

### Imagem base `python:3.11-slim`

**Decisão:** Usar a versão `slim` em vez da versão padrão ou `alpine`.  
**Motivo:** A versão `slim` remove pacotes desnecessários mantendo compatibilidade. A versão `alpine` é ainda menor, mas pode causar problemas de compatibilidade com algumas bibliotecas Python que dependem de bibliotecas C do sistema.

### SAST com Bandit

**Decisão:** Adicionar um stage dedicado de segurança no pipeline.  
**Motivo:** Segurança deve ser parte do processo de desenvolvimento desde o início (conceito de DevSecOps), não uma etapa posterior. O Bandit foi escolhido por ser a ferramenta de análise estática de segurança mais consolidada para Python.

### `rules:` em vez de `only:` no deploy

**Decisão:** Usar a sintaxe `rules: - if:` em vez de `only: - main`.  
**Motivo:** `only` é a sintaxe legada do GitLab CI. A sintaxe `rules` é mais expressiva, suporta condições complexas e é a abordagem recomendada nas versões atuais do GitLab.

### Terraform com Fargate

**Decisão:** Usar AWS Fargate como launch type no ECS.  
**Motivo:** Fargate é o modo serverless do ECS — a AWS gerencia os servidores subjacentes. Para uma aplicação de porte pequeno/médio, isso elimina a necessidade de gerenciar instâncias EC2, reduzindo a complexidade operacional.

### Docker Compose para desenvolvimento local

**Decisão:** Incluir um `docker-compose.yml` mesmo para um projeto com um único serviço.  
**Motivo:** O Compose simplifica o comando de execução de `docker run -p 5000:5000 --name trainee-api trainee-api` para simplesmente `docker-compose up`. À medida que o projeto cresce (banco de dados, cache, etc.), o Compose se torna indispensável.

---

## O que Faria com Mais Tempo

- **Configurar secrets reais no GitLab** para as credenciais AWS no stage de deploy, em vez de placeholders
- **Implementar o deploy real no ECS** utilizando a AWS CLI no stage de deploy, conectando com o Terraform
- **Adicionar o stage de Terraform no pipeline** (`terraform plan` em PRs e `terraform apply` no merge para main)
- **Configurar um backend remoto para o Terraform** (S3 + DynamoDB) para que o estado da infraestrutura seja compartilhado entre a equipe
- **Adicionar métricas e alertas** no CloudWatch para monitorar a saúde da aplicação em produção
- **Implementar versionamento semântico** nas tags das imagens Docker (ex: `v1.2.3`) em vez de usar apenas o hash do commit
- **Configurar ambientes separados** (staging e production) com pipelines distintos
- **Adicionar relatório de cobertura de testes** ao pipeline para acompanhar a porcentagem de código testado

---

## Como Usei IA no Desafio

### Contexto

Este desafio foi desenvolvido sem conhecimento técnico ou prático prévio nas tecnologias envolvidas (Docker, GitLab CI, AWS ECS, Terraform). O processo de aprendizado foi combinado entre pesquisas próprias e uso do Claude como ferramenta pedagógica.

### Processo de estudo antes de usar IA

Antes de começar o desenvolvimento, foi realizado um estudo inicial para entender os conceitos fundamentais:

- **Fortinet (fortinet.com):** Leitura de artigos sobre conceitos de DevSecOps, o que é CI/CD e como pipelines de segurança funcionam em ambientes corporativos
- **YouTube:** Pesquisa sobre CI/CD na prática — como pipelines funcionam, exemplos visuais de fluxos de lint/test/build/deploy e demonstrações de Docker em projetos reais

Esse estudo inicial foi essencial para que as explicações do Claude fizessem sentido — sem a base conceitual, os termos técnicos seriam apenas palavras.

### Como o Claude foi utilizado

O Claude foi utilizado como **professor e parceiro de desenvolvimento**, não como gerador automático de código. O fluxo de trabalho foi:

1. **Explicação do conceito do zero** antes de qualquer código — ex: "O que é Docker e por que existe?"
2. **Construção linha a linha** de cada arquivo, com cada instrução explicada antes de ser escrita
3. **Revisão do código criado** — os arquivos eram enviados ao Claude para análise de erros e melhorias
4. **Resolução de erros práticos** — quando algo não funcionava (ex: `permission denied` no Docker, erro de indentação, variável sem `$`), o Claude explicava a causa raiz antes de dar a solução
5. **Pedidos de reexplicação** — quando um conceito não ficava claro, era solicitada uma nova explicação com abordagem diferente ou exemplo prático

### Exemplos de interações

| Situação | Abordagem |
|----------|-----------|
| Nunca havia usado Docker | Claude explicou o conceito de "caixinha isolada" e camadas antes de escrever o Dockerfile |
| Erro `permission denied` no Docker | Claude explicou o sistema de grupos do Linux antes de dar o comando de solução |
| Dúvida sobre `$HTTP_STATUS` vs `HTTP_STATUS` | Claude gerou comparação visual lado a lado mostrando o erro e a correção |
| Não entendia `only:` vs `rules:` | Claude explicou a evolução da sintaxe do GitLab CI e o motivo da mudança |
| Arquivo com aspas "inteligentes" | Claude identificou o problema de encoding e ensinou a recriar pelo terminal |

### O que funcionou bem

- Pedir explicações conceituais **antes** do código — entender o "por quê" antes do "como"
- Enviar os arquivos criados para revisão — o Claude identificou erros que passariam despercebidos
- Testar cada etapa localmente antes de avançar — erros foram detectados cedo

### O que aprenderia diferente

- Instalar e configurar o ambiente (Docker, venv) antes de começar a escrever código
- Ler a documentação oficial do GitLab CI sobre `rules:` antes de usar `only:`
- Criar o `.gitignore` como primeiro arquivo do projeto, não depois

---

*Desenvolvido como parte do processo seletivo do Programa Trainee Cloud & IA — IN8 Holding / Devnology*