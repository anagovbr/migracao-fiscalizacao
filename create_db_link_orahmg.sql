-- Foi necessário criar um DBLINK para o banco de homologação durante o
-- estágio de desenvolvimento no banco DW. No ambiente de homologação
-- esse DBLINK é desnecessário.
CREATE DATABASE LINK ORAHMG_LINK
CONNECT TO IUSR_COGED_RO IDENTIFIED BY "password"
USING 'exacc-hmg-scan.ana.gov.br:1521/ORAHMG.ana.gov.br';