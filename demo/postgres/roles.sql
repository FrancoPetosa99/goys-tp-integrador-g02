-- roles.sql: crea los 4 roles de mínimo privilegio (propuesta §6) desde
-- variables de entorno (D13: nunca passwords hardcodeadas). Corre después de
-- init.sql (orden alfabético de docker-entrypoint-initdb.d).
\set ON_ERROR_STOP on

-- app_writer: SELECT/INSERT/UPDATE sobre las tablas de negocio.
\getenv app_writer_user APP_WRITER_USER
\getenv app_writer_password APP_WRITER_PASSWORD
CREATE ROLE :"app_writer_user" LOGIN PASSWORD :'app_writer_password';
GRANT CONNECT ON DATABASE dbscale TO :"app_writer_user";
GRANT USAGE ON SCHEMA public TO :"app_writer_user";
GRANT SELECT, INSERT, UPDATE ON categories, products TO :"app_writer_user";
-- INSERT usa nextval() de las columnas BIGSERIAL: sin esto, el INSERT falla.
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO :"app_writer_user";

-- app_reader: solo SELECT (A2.2: un INSERT con este rol debe fallar).
\getenv app_reader_user APP_READER_USER
\getenv app_reader_password APP_READER_PASSWORD
CREATE ROLE :"app_reader_user" LOGIN PASSWORD :'app_reader_password';
GRANT CONNECT ON DATABASE dbscale TO :"app_reader_user";
GRANT USAGE ON SCHEMA public TO :"app_reader_user";
GRANT SELECT ON categories, products TO :"app_reader_user";

-- replicator: solo el atributo REPLICATION, sin permisos sobre tablas de
-- negocio. No se usa hasta la fase 3, pero pg_hba.conf y postgresql.conf
-- quedan finales ya en esta fase.
\getenv replicator_user REPLICATOR_USER
\getenv replicator_password REPLICATOR_PASSWORD
CREATE ROLE :"replicator_user" LOGIN REPLICATION PASSWORD :'replicator_password';

-- monitor: rol pg_monitor (vistas de estado), sin SELECT sobre tablas de
-- negocio (A2.2: un SELECT a products con este rol debe fallar).
\getenv monitor_user MONITOR_USER
\getenv monitor_password MONITOR_PASSWORD
CREATE ROLE :"monitor_user" LOGIN PASSWORD :'monitor_password';
GRANT pg_monitor TO :"monitor_user";
