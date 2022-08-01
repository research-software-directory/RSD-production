FROM djrobstep/migra:3.0.1621480950

CMD sleep 10 && migra --unsafe postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@database:5432/${POSTGRES_DB} postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@migration-database:5432/${POSTGRES_DB} > migration.sql
