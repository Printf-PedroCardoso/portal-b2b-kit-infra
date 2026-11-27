# 03. GUIA DO INICIANTE — AWS E TERRAFORM DO ZERO AO DEPLOY
**Projeto:** Portal B2B Distribuído  
**Autor:** Especialista em Nuvem e Professor(a) de Sistemas Distribuídos  
**Público-alvo:** Estudantes, desenvolvedores e engenheiros que nunca usaram AWS ou Terraform  

---

## Bem-vindo(a) ao Mundo da Infraestrutura como Código!

Se esta é a sua primeira vez configurando serviços na nuvem da AWS ou utilizando o Terraform, **não se preocupe**. Este guia foi elaborado passo a passo, em linguagem acessível e didática, explicando o **porquê** de cada comando e como navegar com segurança para evitar cobranças indevidas no cartão de crédito.

Ao final deste guia, você compreenderá com clareza como uma arquitetura moderna para 9 microsserviços, mensageria distribuída e banco de dados Multi-AZ pode ser criada e destruída em poucos minutos com comandos automatizados.

---

## 1. Criando e Protegendo sua Conta na AWS

A AWS (Amazon Web Services) é o maior provedor de computação em nuvem do mundo. Quando você cria uma conta, você se torna o "Root User" (Usuário Raiz), com poder irrestrito sobre qualquer recurso ou cobrança.

### 1.1 Criação da Conta
1. Acesse o portal oficial: [https://aws.amazon.com](https://aws.amazon.com) e clique em **"Create an AWS Account"** (Criar uma conta da AWS).
2. Forneça seu endereço de e-mail e escolha um nome para a conta (ex: `aluno-sistemas-distribuidos`).
3. Forneça os dados de cobrança (é necessário um cartão de crédito internacional válido; a AWS fará uma cobrança temporária de US$ 1,00 para verificação e estornará em seguida).
4. Selecione o plano de suporte **Básico (Gratuito)**.

### 1.2 Ativando MFA Obrigatório no Usuário Root
> [!CAUTION]
> Nunca utilize a conta raiz no dia a dia e **nunca** gere chaves de acesso (`Access Keys`) para ela. Qualquer vazamento da conta raiz permite a invasores alugar servidores de mineração de criptomoedas, gerando faturas astronômicas.

1. Faça login na conta como usuário raiz.
2. Na barra de pesquisa superior, digite **IAM** (Identity and Access Management) e clique no serviço.
3. No painel inicial, localize o alerta **"Add MFA for root user"** (Adicionar MFA para usuário raiz).
4. Clique em **"Assign MFA"** (Atribuir MFA).
5. Escolha **"Authenticator app"** (Aplicativo autenticador, como Google Authenticator, Microsoft Authenticator ou Authy no seu smartphone).
6. Escaneie o QR Code exibido na tela e insira dois códigos consecutivos gerados pelo aplicativo. Clique em **Salvar**.

---

## 2. Criando um Usuário de Trabalho no IAM (Privilégio Mínimo)

Agora que sua conta raiz está segura com MFA, criaremos um usuário administrativo comum para trabalhar via linha de comando (AWS CLI) e Terraform.

1. No console do IAM, no menu lateral esquerdo, clique em **Users** (Usuários) $\rightarrow$ **Create user** (Criar usuário).
2. **Nome do usuário:** `dev-infra` (ou seu primeiro nome).
3. Marque a opção **"Provide user access to the AWS Management Console"** (se desejar login visual) e defina uma senha forte.
4. Na tela de permissões (**Permissions**), selecione **"Attach policies directly"** (Anexar políticas diretamente).
5. Selecione a política:
   - `AdministratorAccess` (para ambiente acadêmico de laboratório onde você provisionará rede, RDS, ALB e EC2).
6. Avance até o final e clique em **Create user**.
7. Clique sobre o usuário recém-criado (`dev-infra`), acesse a aba **Security credentials** (Credenciais de segurança).
8. Role até **Access keys** $\rightarrow$ **Create access key**.
9. Selecione a opção **"Command Line Interface (CLI)"**, confirme o termo de ciência e clique em **Next** $\rightarrow$ **Create access key**.
10. **Atenção:** Copie e guarde em local seguro:
    - **Access Key ID:** Uma sequência de letras maiúsculas (ex: `AKIAIOSFODNN7EXAMPLE`)
    - **Secret Access Key:** Uma sequência longa de caracteres (ex: `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY`)
    *(Você nunca mais poderá visualizar essa chave secreta após fechar a janela).*

---

## 3. Instalando a AWS CLI v2

A AWS CLI (Command Line Interface) é a ferramenta de terminal oficial da Amazon que permite ao seu computador conversar com a AWS.

### No Linux (Ubuntu/Debian)
```bash
sudo apt update && sudo apt install -y curl unzip
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
rm -rf aws awscliv2.zip
aws --version
```

### No macOS
Utilizando o Homebrew:
```bash
brew install awscli
aws --version
```
Ou baixe o instalador `.pkg` oficial da AWS.

### No Windows
1. Baixe o instalador oficial de 64 bits: [AWSCLIV2.msi](https://awscli.amazonaws.com/AWSCLIV2.msi).
2. Execute o instalador e avance até o final.
3. Abra o **PowerShell** ou **Prompt de Comando (CMD)** e teste:
```powershell
aws --version
```

### Configurando suas Credenciais
No terminal do seu computador, execute:
```bash
aws configure
```
O prompt fará quatro perguntas:
1. `AWS Access Key ID [None]:` Cole o seu Access Key ID criado no passo 2.
2. `AWS Secret Access Key [None]:` Cole a sua Secret Access Key.
3. `Default region name [None]:` Digite `us-east-2` (Região Ohio — permitida pela SCP da conta AWS, com a mesma tabela de preços de `us-east-1`).
4. `Default output format [None]:` Digite `json`.

**Como testar se funcionou:**
Execute o comando de consulta de identidade:
```bash
aws sts get-caller-identity
```
Se o terminal retornar um JSON contendo sua conta (`Account`) e o ARN do seu usuário (`arn:aws:iam::...:user/dev-infra`), sua conexão está **100% pronta e autenticada!**

---

## 4. Instalando o Terraform

O Terraform é uma ferramenta de **Infraestrutura como Código (IaC)** criada pela HashiCorp. Em vez de você clicar 150 vezes no console web da AWS para criar redes, discos e servidores, você escreve arquivos declarativos em formato `.tf` e o Terraform cria tudo automaticamente na nuvem.

### No Linux (Ubuntu/Debian)
```bash
sudo apt-get update && sudo apt-get install -y gnupg software-properties-common curl
wget -O- https://apt.releases.hashicorp.com/gpg | \
gpg --dearmor | \
sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null

echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
sudo tee /etc/apt/sources.list.d/hashicorp.list

sudo apt update && sudo apt install -y terraform
terraform version
```

### No macOS
Utilizando o Homebrew:
```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
terraform version
```

### No Windows
Utilizando o Chocolatey:
```powershell
choco install terraform
```
Ou utilizando o Winget:
```powershell
winget install HashiCorp.Terraform
```
Reinicie o terminal e execute `terraform version` para validar.

---

## 5. O Ciclo de Vida do Terraform Explicado Didaticamente

O Terraform opera baseado em **declaração de estado desejado**: você descreve como quer que a infraestrutura esteja, e o motor do Terraform calcula as ações necessárias (adicionar, alterar ou destruir) para alcançar esse estado.

```mermaid
flowchart LR
  Init["1. terraform init\n(Baixa provedores e módulos)"] --> Fmt["2. terraform fmt\n(Padroniza indentação)"]
  Fmt --> Validate["3. terraform validate\n(Verifica sintaxe e tipos)"]
  Validate --> Plan["4. terraform plan\n(Calcula diferenças sem aplicar)"]
  Plan --> Apply["5. terraform apply\n(Cria os recursos reais na nuvem)"]
  Apply -.-> Destroy["6. terraform destroy\n(Apaga tudo para não gastar)"]
```

### 1. `terraform init` (Inicialização)
- **O que faz:** Lê seus arquivos `.tf`, descobre de quais provedores você precisa (ex: `hashicorp/aws`, `hashicorp/random`), cria o diretório oculto `.terraform/` e baixa os plugins necessários.
- **Quando rodar:** Sempre que você clonar o projeto pela primeira vez ou adicionar um novo módulo/provedor.

### 2. `terraform fmt` (Formatação)
- **O que faz:** Ajusta automaticamente o alinhamento, espaçamento e identação de todos os arquivos `.tf` conforme o padrão da comunidade.
- **Comando recomendado:** `terraform fmt -recursive`

### 3. `terraform validate` (Validação Estática)
- **O que faz:** Verifica se você escreveu nomes de atributos errados, se esqueceu chaves `{}` ou se passou um texto onde era esperado um número. Ele **não** conecta na AWS, apenas valida a lógica dos arquivos.

### 4. `terraform plan` (Planejamento)
- **O que faz:** Conecta na AWS, consulta o que já existe de verdade na nuvem, compara com o seu código local e gera um relatório dizendo:
  - `+ create`: Recursos que serão criados (em verde).
  - `~ update in-place`: Recursos que serão alterados (em amarelo).
  - `- destroy`: Recursos que serão deletados (em vermelho).
- **Importante:** O `plan` é 100% seguro! Ele **não** cria e nem apaga nada na nuvem; é apenas uma simulação detalhada.

### 5. `terraform apply` (Aplicação)
- **O que faz:** Executa de fato as ações planejadas contra a API da AWS. Ele solicita uma confirmação digitando `yes`. Ao término, grava o arquivo `terraform.tfstate`, que é a memória do Terraform com os IDs de tudo o que foi gerado.

### 6. `terraform destroy` (Destruição)
- **O que faz:** Lê o arquivo de estado e remove **todos** os recursos gerenciados pelo projeto na AWS, garantindo que nada fique ligado consumindo créditos do seu cartão de crédito.

---

## 6. Passo a Passo: Provisionando o Ambiente `integracao`

Vamos rodar a infraestrutura do Portal B2B no ambiente de integração:

### Passo 1: Entrar no diretório do ambiente
```bash
cd terraform/envs/integracao
```

### Passo 2: Configurar o arquivo de variáveis
Copie o arquivo de exemplo:
```bash
cp terraform.tfvars.example terraform.tfvars
```
Abra o arquivo `terraform.tfvars` em seu editor favorito (VS Code, Nano ou Vim) e defina senhas seguras para o banco de dados e JWT:
```hcl
aws_region        = "us-east-2"
project_name      = "portal-b2b"
domain_name       = "integracao.b2b.local"
db_admin_password = "MinhaSenhaSuperForteDB123!#"
db_ddl_password   = "MinhaSenhaDDLMigrations123!#"
jwt_secret_key    = "chave-secreta-jwt-super-segura-de-32-bytes"
alert_email       = "seu-email@gmail.com"
```

### Passo 3: Inicializar o Terraform
```bash
terraform init
```
*Saída esperada:* `Terraform has been successfully initialized!`

### Passo 4: Validar os arquivos
```bash
terraform validate
```
*Saída esperada:* `Success! The configuration is valid.`

### Passo 5: Gerar e revisar o plano
```bash
terraform plan
```
O Terraform informará algo como:
`Plan: 35 to add, 0 to change, 0 to destroy.`

### Passo 6: Aplicar a criação na AWS
```bash
terraform apply
```
O terminal solicitará:
`Do you want to perform these actions?`  
Digite: `yes` e pressione Enter.

O processo levará entre 5 e 10 minutos (o RDS PostgreSQL Multi-AZ é o componente que mais demora, pois provisiona duas instâncias de banco em zonas físicas distintas com replicação síncrona).

Ao concluir, você verá a mensagem verde:
`Apply complete! Resources: 35 added, 0 changed, 0 destroyed.`
E os outputs com o endereço do ALB e os IPs privados serão impressos na tela!

---

## 7. Como Conferir se a Infraestrutura Deu Certo

Após o `terraform apply`, execute as seguintes checagens:

### 1. Testar o Endereço do Application Load Balancer
Copie o valor impresso no output `alb_dns_name`:
```bash
curl -ik http://<ALB_DNS_NAME>
```
*Resultado esperado:* O ALB responderá com código HTTP 301 (Moved Permanently) redirecionando para `https://<ALB_DNS_NAME>/`, comprovando que o redirecionamento seguro (RNF-16) está funcionando.

### 2. Acessar via AWS SSM (Sem Chave SSH)
Para listar os containers Docker em execução no servidor de aplicação `app1`:
```bash
# Obter o ID da instância EC2
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=portal-b2b-integracao-app1" "Name=instance-state-name,Values=running" \
  --query "Reservations[0].Instances[0].InstanceId" --output text)

# Conectar via SSM Session Manager
aws ssm start-session --target "$INSTANCE_ID"
```
Ao entrar no shell da máquina virtual:
```bash
docker --version
docker compose version
exit
```

### 3. Verificar o RDS Multi-AZ no Console
No Console da AWS, acesse o serviço **RDS** $\rightarrow$ **Databases** $\rightarrow$ selecione `portal-b2b-integracao-rds`.  
Verifique:
- **Multi-AZ:** Yes (Sim)
- **Publicly Accessible:** No (Não)
- **Status:** Available (Disponível)

---

## 8. Gestão de Custos e Como Evitar Cobranças Indevidas

O projeto foi rigorosamente desenhado para custar menos de US$ 500 por mês (RES-03) rodando ininterruptamente. No entanto, para laboratórios e estudos acadêmicos, **você não precisa deixar as máquinas ligadas 24 horas por dia!**

### 8.1 Alertas Automáticos com o AWS Budgets (INF-10)
O módulo `budgets` provisionado automaticamente pelo Terraform configura um teto de US$ 500/mês. Se os gastos projetados ou reais atingirem 80% (US$ 400), a AWS enviará um e-mail de alerta para o endereço configurado na variável `alert_email`.

### 8.2 A Rotina de "Fim de Expediente" (Como Gastar Praticamente Zero)
Ao terminar seus testes ou estudos do dia:
1. Navegue até o ambiente em que estava trabalhando:
   ```bash
   cd terraform/envs/integracao
   ```
2. Execute o comando de destruição:
   ```bash
   terraform destroy -auto-approve
   ```
3. Aguarde o Terraform remover todas as instâncias EC2, discos EBS, o banco RDS e o Load Balancer.  
*Resultado:* Se você usar os recursos por apenas 2 horas para fazer testes e depois der `terraform destroy`, o custo total será de meros centavos de dólar!

### 8.3 O que Checar para Garantir que Nada Ficou "Esquecido"
Se por algum motivo o `destroy` for interrompido, consulte no terminal:
- **Instâncias EC2:** `aws ec2 describe-instances --query "Reservations[*].Instances[?State.Name=='running'].[InstanceId,Tags[?Key=='Name'].Value|[0]]" --output table`
- **Bancos RDS:** `aws rds describe-db-instances --query "DBInstances[*].[DBInstanceIdentifier,DBInstanceStatus]" --output table`
- **NAT Gateways:** `aws ec2 describe-nat-gateways --filter "Name=state,Values=available" --output table`
- **Load Balancers:** `aws elbv2 describe-load-balancers --query "LoadBalancers[*].[LoadBalancerName,DNSName]" --output table`

Se essas quatro tabelas retornarem vazias, sua conta está com custo zero em repouso!

---

## 9. Os 10 Erros Mais Comuns de Iniciantes e Como Resolver

Abaixo listamos as mensagens de erro mais frequentes enfrentadas por quem está começando em AWS e Terraform, com a explicação e a solução exata.

---

### Erro 1: `Error: AccessDenied / UnauthorizedOperation`
- **O que significa:** O seu usuário do IAM não tem permissão para criar aquele recurso específico na AWS.
- **Causa típica:** O usuário foi criado sem anexar a política correta ou suas chaves locais pertencem a um usuário antigo.
- **Solução:**
  1. No console da AWS, verifique as políticas associadas ao usuário no IAM.
  2. Para laboratório de estudos, anexe a política `AdministratorAccess`.
  3. No terminal, execute `aws sts get-caller-identity` para checar com qual usuário a AWS CLI está autenticando.

---

### Erro 2: `Error: Error acquiring the state lock`
- **O que significa:** O Terraform detectou que uma operação anterior não foi finalizada ou que outra pessoa está aplicando mudanças ao mesmo tempo usando o DynamoDB como trava (*lock*).
- **Causa típica:** Você cancelou um `apply` no meio usando `Ctrl + C` ou a conexão caiu.
- **Solução:**
  O Terraform informará o ID do Lock (um código UUID, ex: `b193f412-87ad-4521-...`). Execute:
  ```bash
  terraform force-unlock <LOCK-ID>
  ```
  E tente novamente o comando.

---

### Erro 3: `Error: Reference to undeclared resource / variable`
- **O que significa:** O arquivo `.tf` tenta usar uma variável ou recurso que não foi declarado com `variable "nome"` ou `resource "tipo" "nome"`.
- **Causa típica:** Erro de digitação (exemplo: digitar `var.ambiente` em vez de `var.environment`).
- **Solução:**
  Rode `terraform validate`. O terminal apontará o número exato da linha e o nome incorreto. Corrija a ortografia no arquivo `.tf`.

---

### Erro 4: `Error: Target.FailedHealthChecks` no ALB
- **O que significa:** O Load Balancer tentou fazer uma requisição no endpoint `/health/ready` na porta 8080 das instâncias de aplicação e não recebeu o código HTTP 200 esperado.
- **Causa típica:** Os containers Docker na VM ainda estão inicializando ou o Security Group bloqueou o tráfego.
- **Solução:**
  1. Aguarde 1 a 2 minutos para que os 9 serviços terminem o boot inicial.
  2. Verifique se o `app_sg` autoriza a porta 8080 vindo do `alb_sg`.
  3. Conecte via AWS SSM na VM e veja os logs do Nginx: `docker compose logs -f gateway`.

---

### Erro 5: `Error: BucketAlreadyExists / BucketAlreadyOwnedByOther`
- **O que significa:** Você tentou criar um bucket S3 com um nome que já existe no mundo inteiro.
- **Causa típica:** Os nomes de buckets S3 são globais em toda a AWS.
- **Solução:**
  Adicione um identificador aleatório ou seu nome ao final do bucket no `backend.tf` (ex: `portal-b2b-state-seunome-12345`).

---

### Erro 6: `Error: InvalidParameterValue: The parameter group family does not match`
- **O que significa:** O Parameter Group do RDS configurado no Terraform pertence a uma versão diferente da engine informada.
- **Causa típica:** Tentar usar uma família `postgres15` com uma instância configurada para `engine_version = "16"` (ou fixar uma versão *minor* descontinuada pela AWS, como `"16.3"`).
- **Solução:**
  No arquivo `modules/rds/main.tf`, assegure-se de que a família seja `postgres16`:
  ```hcl
  family = "postgres16"
  ```

---

### Erro 7: `Error: RDS Cannot delete: deletion_protection is enabled`
- **O que significa:** O comando `terraform destroy` falhou ao tentar apagar o RDS PostgreSQL porque o banco está protegido contra exclusões acidentais.
- **Causa típica:** Configuração de segurança ativada propositalmente (como no ambiente `prod`).
- **Solução:**
  1. Em `envs/prod/main.tf`, altere temporariamente `deletion_protection = false`.
  2. Execute `terraform apply -target=module.rds` para atualizar o parâmetro.
  3. Em seguida, execute `terraform destroy`.

---

### Erro 8: `Error: Cycle: cycle contains: module.X -> module.Y`
- **O que significa:** Dependência circular. O módulo X depende de uma saída do módulo Y, e o módulo Y depende de uma saída do módulo X ao mesmo tempo.
- **Causa típica:** Passar o ID do Security Group A para dentro de B e tentar amarrar B diretamente em A no mesmo bloco de recurso.
- **Solução:**
  Quebre a dependência utilizando recursos desacoplados, como o `aws_security_group_rule` independente, em vez de declarar regras inline mútuas.

---

### Erro 9: `Error: No default subnet found in AZ / InvalidSubnetID`
- **O que significa:** O Terraform tentou provisionar um recurso em uma sub-rede que não existe ou que foi deletada manualmente no console.
- **Causa típica:** Alterações feitas manualmente via console web que dessincronizaram o arquivo de estado (`terraform.tfstate`).
- **Solução:**
  Sincronize o estado local com a AWS executando:
  ```bash
  terraform refresh
  ```
  Se necessário, reexecute `terraform plan` para realinhar os IDs.

---

### Erro 10: `Error: FATAL: too many connections for role "portal_admin"`
- **O que significa:** O banco de dados PostgreSQL atingiu o limite de conexões simultâneas permitidas pela instância (`db.t4g.medium`).
- **Causa típica:** Microsserviços abrindo pools descontrolados de 20 ou 30 conexões cada um.
- **Solução:**
  Conforme o requisito `RNF-10`, limite rigorosamente o pool de conexões das aplicações para no máximo 5 por réplica no arquivo `.env`:
  ```bash
  DB_POOL_MAX_SIZE=5
  ```
  Com 9 serviços em 2 instâncias, o total será $9 \times 2 \times 5 = 90$ conexões, mantendo-se perfeitamente abaixo do teto de 100 conexões do RDS.

---

## 10. Conclusão e Próximos Passos

Parabéns! Agora você compreende a lógica, os comandos, a governança de custos e a resolução de problemas em ambientes de nuvem com Terraform.

Quando estiver pronto para ver os 9 microsserviços, o cluster Redpanda e as interfaces rodando juntos na sua máquina local com um único comando, avance para a **Etapa 4: Prova de Conceito (PoC Local)**!
