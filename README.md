# Migração Fiscalização

Repositório com transformações e regras de negócio para migração dos dados do sistema fiscalização.

A cópia dos dados do SQL Server para a área de staging no Oracle é feita utilizando-se o ADF. O ETL espera encontrar três tabelas de staging:

1. STG_TBOCORRENCIA
1. STG_TBVISTORIA
1. STG_VW_BDBARRAGEM

As tabelas temporárias de transformação são criadas pelo script transformacoes.sql.

No ambiente de homologação as tabelas de staging e transformação foram criadas no usuário de ETL `FISCALIZACAO_ETL_RW` a fim de preservar o banco de destino. Posteriormente os dados são copiados para suas respectivas tabelas no schema destino e as sequences atualizadas.
