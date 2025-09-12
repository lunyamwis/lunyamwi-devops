FROM apache/airflow:3.0.6-python3.12

RUN pip install --no-cache-dir apache-airflow-providers-http[all]==3.0.0 apache-airflow-providers-postgres==3.0.0 apache-airflow-providers-ftp==3.0.0 apache-airflow-providers-sftp==3.0.0 apache-airflow-providers-celery==3.0.0 apache-airflow-providers-redis==3.0.0 apache-airflow-providers-docker==3.0.0
RUN pip install --no-cache-dir requests pandas sqlalchemy psycopg2-binary 
