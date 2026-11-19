import psycopg2

HOST = "127.0.0.1"
PORT = 5432
DB_NAME = "benchmark"
USERNAME = "postgres"
PASSWORD = "postgres"


def get_connection(autocommit=False):
    connection = psycopg2.connect(host=HOST, port=PORT, dbname=DB_NAME, user=USERNAME, password=PASSWORD)
    connection.autocommit = autocommit

    return connection