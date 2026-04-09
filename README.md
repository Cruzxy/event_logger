# Event Logger (Fork)

Fork do [event_logger](https://github.com/SuricatoX/event_logger) original do SuricatoX com correções de compatibilidade para versões recentes do FiveM. O projeto original apresentava problemas que impediam o funcionamento, então criei este fork há alguns meses para corrigir e decidi publicar para ajudar outras pessoas que enfrentem os mesmos problemas.

Correções aplicadas neste fork:
- Substituição de `io.open`/`os.execute` por `SaveResourceFile` e `LoadResourceFile` (nativos do FiveM)
- Remoção de `package.config`, `os.mkdir` e `os.execute` (indisponíveis no sandbox)
- Remoção da subpasta `eventLog/` (incompatível com `SaveResourceFile`)
- Remoção de funções obsoletas (`createFile`, `createFolder`, `openFile`, `writeToFile`, `closeFile`)

Ferramenta de depuração para servidores FiveM que monitora eventos Server > Client (S > C), identificando os que mais impactam o desempenho e a rede do servidor.

## Quando usar

Utilize quando encontrar os seguintes avisos no console do servidor:

- `Network thread hitch warning`
- `Sync thread hitch warning`

## Requisitos

- FiveM server build atualizado (compatível com `fx_version 'cerulean'` e `lua54`)
- Acesso ao console do servidor (cmd / txAdmin)

## Instalação

1. Coloque a pasta `event_logger` dentro da pasta `resources` do seu servidor.
2. Adicione `ensure event_logger` no `server.cfg`.
3. No console do servidor, execute:

```
/loginstall
```

Isso injeta a dependência `log_register.lua` em todos os resources automaticamente. Após isso, reinicie o servidor.

## Desinstalação

```
/loguninstall
```

Remove a dependência de todos os resources. Reinicie o servidor após executar.

## Comandos

| Comando | Descrição |
|---|---|
| `/loginstall` | Instala as dependências do logger em todos os resources |
| `/loguninstall` | Remove as dependências do logger de todos os resources |
| `/logevent` | Gera um arquivo `.log` com os eventos dos últimos 10 minutos |
| `/logeventfull` | Gera um arquivo `.log` com todos os eventos desde o start do servidor |
| `/logfilter [arquivo] [evento]` | Gera uma log filtrada removendo um evento específico |
| `/loganalyze [arquivo]` | Analisa a log e classifica eventos por nível de risco |
| `/stoplogevent` | Para o registro de logs |
| `/startlogevent` | Retoma o registro de logs |
| `/clearlogevent` | Limpa os logs armazenados em memória |
| `/collectlogevent` | Força coleta de lixo (garbage collector) |
| `/loghelp` | Lista todos os comandos disponíveis |

## Análise de eventos

Após gerar uma log com `/logevent` ou `/logeventfull`, use `/loganalyze [nome-do-arquivo.log]` para iniciar a análise. O sistema classifica os eventos em três níveis:

| Nível | Descrição |
|---|---|
| **low** | Eventos que disparam de forma excessiva (loop) |
| **mid** | Eventos que enviam dados pesados (muitos bytes) para todos os jogadores |
| **high** | Eventos que combinam loop excessivo com dados pesados para todos — risco máximo |

Após a análise, use os comandos interativos:

| Comando | Descrição |
|---|---|
| `/result low` | Lista eventos de baixo risco |
| `/result mid` | Lista eventos de alto risco |
| `/result high` | Lista eventos de risco máximo |
| `/args` | Mostra argumentos do evento atual (limitado a 80 chars) |
| `/args 1` | Mostra argumentos completos do evento atual |
| `/next` | Avança para o próximo evento na lista |

## Estrutura dos logs

Cada evento registrado contém:

```
[EVENT_NAME]: nome_do_evento
[SOURCE_TRIGGERED]: id_do_source
[BYTES]: tamanho_em_bytes
[DATA_ARGS]: argumentos_do_evento_em_json
```

Os arquivos são salvos na pasta raiz do resource `event_logger/` (ex: `log-1775766089.log`).