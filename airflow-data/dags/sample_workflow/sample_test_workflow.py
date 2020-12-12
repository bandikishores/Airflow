
from datetime import timedelta

# Import the operator
from airflow.contrib.operators.spark_submit_operator import SparkSubmitOperator 

# The DAG object; we'll need this to instantiate a DAG
from airflow import DAG
# Operators; we need this to operate!
from airflow.operators.bash_operator import BashOperator
from airflow.utils.dates import days_ago
# These args will get passed on to each operator
# You can override them on a per-task basis during operator initialization
default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'start_date': days_ago(1),
    'email': ['kishore.bandi@skyflow.com'],
    'email_on_failure': True,
    'email_on_retry': True,
    'retries': 3,
    'retry_delay': timedelta(seconds=10),
    # 'queue': 'bash_queue',
    # 'pool': 'backfill',
    # 'priority_weight': 10,
    # 'end_date': datetime(2016, 1, 1),
    # 'wait_for_downstream': False,
    # 'dag': dag,
    # 'sla': timedelta(hours=2),
    # 'execution_timeout': timedelta(seconds=300),
    # 'on_failure_callback': some_function,
    # 'on_success_callback': some_other_function,
    # 'on_retry_callback': another_function,
    # 'sla_miss_callback': yet_another_function,
    # 'trigger_rule': 'all_success'
}
dag = DAG(
    'SampleTestWorkflow',
    default_args=default_args,
    description='A Sample Test workflow that gets triggered using REST calls',
    catchup=False,
    schedule_interval=None
    # schedule_interval=timedelta(days=1),
)

# t1, t2 and t3 are examples of tasks created by instantiating operators
t1 = BashOperator(
    task_id='print_message',
    bash_command='echo "Here is the message: \'{{ dag_run.conf["msg"] if dag_run else "" }}\'"',
    dag=dag,
)

t2 = BashOperator(
    task_id='sleep',
    depends_on_past=False,
    bash_command='sleep {{ dag_run.conf["sleep_duration"] if dag_run else "30" }}',
    retries=3,
    dag=dag,
)
dag.doc_md = __doc__

t1.doc_md = """\
#### Task Documentation
You can document your task using the attributes `doc_md` (markdown),
`doc` (plain text), `doc_rst`, `doc_json`, `doc_yaml` which gets
rendered in the UI's Task Instance Details page.
![img](http://montcs.bloomu.edu/~bobmon/Semesters/2012-01/491/import%20soul.png)
"""

# Set the path for our files.
# entry_point = os.path.join(os.environ["AIRFLOW_HOME"], "____", "____")
# dependency_path = os.path.join(os.environ["AIRFLOW_HOME"], "____", "____")

# t3 = SparkSubmitOperator(
#     task_id='spark_submit_job',
#     total_executor_cores='1',
#     executor_cores='1',
#     executor_memory='1g',
#     num_executors='1',
#     name='airflow-spark',
#     application='/Users/bandi/go/src/skyflow.com/spikes/kishore/spark-airflow-s3-emr/target/spark-workflow-0.0.1-SNAPSHOT-shaded.jar',
#     verbose=True,
#     driver_memory='2g',
#     conf={
#         # 'master':'spark://192.168.1.11:7077',
#         'spark.driver.extraJavaOptions':'-Dlog4j.configuration=log4j.properties',
#         'spark.executor.extraJavaOptions':'-Dlog4j.configuration=log4j.properties',
#         'driver-java-options':'"-Dlog4j.configuration=log4j.properties"',
#     },
#     files='{{ dag_run.conf["files"] if dag_run else "/Users/bandi/Documents/secrets.txt,/Users/bandi/go/src/skyflow.com/spikes/kishore/spark-airflow-s3-emr/target/classes/log4j.properties" }}',
#     dag=dag,
#     application_args=[
#     ],
#     java_class='com.skyflow.workflow.spark.BulkIngestion',
#     # jars='/Users/bandi/go/src/skyflow.com/spikes/kishore/spark-airflow-s3-emr/target/spark-workflow-0.0.1-SNAPSHOT-shaded.jar'
#     )

# t1 >> [t2, t3]
t1 >> t2
