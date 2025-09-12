FROM apache/airflow:3.0.6

RUN pip install --no-cache-dir apache-airflow-providers-http apache-airflow-providers-postgres
RUN pip install --no-cache-dir requests pandas sqlalchemy psycopg2-binary 
