# Migração Fiscalização

Repositório com transformações e regras de negócio para migração dos dados do sistema fiscalização legado (SQL Server) para o sistema novo (Oracle).

## Arquitetura

### Fluxo de Dados

1. **Origem**: Sistema legado SQL Server
2. **ADF**: Azure Data Factory copia dados para área de staging
3. **Staging**: Tabelas no schema `FISCALIZACAO_ETL_RW` (prefixo `STG_`)
4. **Transformação**: Tabelas temporárias no schema `FISCALIZACAO_ETL_RW` (sufixo `_TEMP`)
5. **Destino**: Tabelas finais no schema `FISCALIZACAO`

### Tabelas de Staging

A cópia dos dados do SQL Server para a área de staging no Oracle é feita utilizando-se o ADF. O ETL espera encontrar as seguintes tabelas de staging:

1. **STG_TBOCORRENCIA** - Ocorrências/infrações do sistema legado
2. **STG_TBVISTORIA** - Vistorias realizadas em barragens
3. **STG_TBTECNICO** - Dados dos técnicos fiscalizadores
4. **STG_VW_BDBARRAGEM** - Informações de barragens (filtro: apenas operadas pela ANA)
5. **STG_VW_DADOSRH** - Dados de RH para mapeamento de técnicos para servidores

### Tabelas de Destino

Os dados transformados são inseridos nas seguintes tabelas do schema `FISCALIZACAO`:

- **FISTB_CAMPANHA** - Campanhas de fiscalização (conceito criado na migração)
- **FISTB_VISTORIA_BARRAGEM** - Vistorias vinculadas a campanhas
- **FISTB_OCORRENCIA** - Ocorrências/infrações
- **FISTB_INSTRUMENTOFISCALIZACAO** - Instrumentos (autos, notificações) vinculando campanhas, vistorias e ocorrências
- **FISTB_ACOMPANHAMENTOOCORRENCIA** - Histórico de operações nas ocorrências
- **FISTB_MULTAOCORRENCIA** - Dados de multas e pagamentos
- **FISTB_RECURSOOCORRENCIA** - Recursos de 1ª e 2ª instância

## Script Principal: transformacoes.sql

O script `transformacoes.sql` executa a transformação completa dos dados:

### Etapas de Execução

1. **Limpeza**: Remove dados migrados anteriormente (re-executável)
2. **Drop de temporárias**: Remove tabelas temporárias de execuções anteriores
3. **Criação de mapeamentos**: Cria tabelas auxiliares para mapeamento de IDs
   - `TEMP_CAMPANHA_MAP` - Mapeia IDs de campanhas geradas
   - `TEMP_SNISB_MAP` - Mapeia códigos de barragens (BAR_CD ↔ BAR_CD_SNISB)
   - `TEMP_TECNICO_MAP` - Mapeia técnicos para servidores (email e nome)
4. **Transformação**: Popula tabelas temporárias com dados transformados
   - Campanhas (uma por IDCAMPANHA único)
   - Vistorias vinculadas a campanhas
   - Ocorrências
   - Instrumentos de fiscalização
   - Acompanhamento de ocorrências (operações de multa e recurso)
   - Multas e pagamentos (quando aplicável)
   - Recursos de 1ª e 2ª instância (quando aplicável)
5. **Cópia final**: Transfere dados das temporárias para tabelas destino
6. **Sincronização**: Atualiza sequences do Oracle

### Regras de Negócio Importantes

- **Campanhas**: Conceito não existe no sistema legado; derivado de vistorias
- **Filtro de barragens**: Apenas barragens operadas pela ANA (via `STG_VW_BDBARRAGEM`)
- **Exclusões**: Registros com `IDTIPOOCORRENCIA = 7` (Protocolo Emergência) são descartados
- **Multas**: Criadas apenas quando existir valor da multa, valor pago ou data de pagamento
- **Recursos**: Criados apenas quando existir data de recebimento do recurso
- **Observações de recursos**: Armazenadas no recurso de 2ª instância se existir, senão na 1ª instância
- **Marcação de migrados**: Registros marcados com flags (`CAM_IC_MIGRADO`, `CAM_IC_BARRAGEM`, `OCO_IC_MIGRADO`)

### Mapeamentos de Status

**Status de Campanha (CAM_TSC_CD)**:
- Mapeamento 1:1 da origem (1=Prevista, 2=Andamento, 3=Suspensa, 4=Concluída, 5=Cancelada)

**Status de Vistoria (VIB_SVI_CD)**:
- 1→1 (Prevista), 4→2 (Concluída), 5→3 (Cancelada)

**Status de Ocorrência (OCO_TSO_CD)**:
- 7→8 (Aguardando Cadastro Proton → Em edição)
- Demais: mapeamento 1:1

**Status de Recurso (REO_SIR_CD)**:
- 1→1 (Deferido), 2→2 (Indeferido), 3→3 (Deferimento Parcial → Parcialmente deferido)
- 4→4 (Em Procedimento → Não conhecido)

**Tipo de Instrumento (AUI_TIF_CD)**:
- Tipos 1-4, 24 → Auto de Infração (1)
- Tipos 5, 25 → Notificação (3)

## Execução

### Pré-requisitos

1. Dados copiados para tabelas de staging via ADF
2. Acesso ao schema `FISCALIZACAO_ETL_RW` (staging e temporárias)
3. Acesso ao schema `FISCALIZACAO` (destino)
4. Acesso ao schema `SNISSBARRAGENS` (para mapeamento de barragens)

### Executar Migração

O script transformacoes.sql em homologação foi executado via cliente SQL DBeaver. No DBeaver executar o script no modo "SQL Script (Alt+X)" ao invés de "SQL Query (Ctrl+Enter)".

**Importante**: O script é re-executável. Ele remove dados migrados anteriormente antes de inserir novos dados.

## Ambiente

No ambiente de homologação, as tabelas de staging e transformação foram criadas no usuário de ETL `FISCALIZACAO_ETL_RW` a fim de preservar o banco de destino. Posteriormente os dados são copiados para suas respectivas tabelas no schema destino e as sequences atualizadas.

### Sequences Importantes

- `FISSQ_CAMPANHA`
- `FISSQ_VISTORIABARRAGEM`
- `FISSQ_OCORRENCIA`
- `FISSQ_INSTFISCALIZACAO`
- `FISSQ_ACOMPOCORRENCIA` (forma abreviada, não ACOMPANHAMENTOOCORRENCIA)
- `FISSQ_MULTAOCORRENCIA`
- `FISSQ_RECURSOOCORRENCIA`

## Verificação

Após executar a migração, recomenda-se verificar:

1. **Contagem de registros** nas tabelas de destino
2. **Integridade referencial** entre tabelas relacionadas
3. **Validação de multas**: Registros com dados de multa possuem `ACOMPANHAMENTOOCORRENCIA` e `MULTAOCORRENCIA`
4. **Validação de recursos**: Recursos possuem `ACOMPANHAMENTOOCORRENCIA` e `RECURSOOCORRENCIA`
5. **Distribuição de observações**: Observações nos recursos corretos (2ª instância quando existir)
6. **Sequences sincronizadas**: Próximo valor das sequences maior que máximo ID nas tabelas
