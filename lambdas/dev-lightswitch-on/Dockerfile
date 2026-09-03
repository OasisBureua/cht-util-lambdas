FROM public.ecr.aws/lambda/python:3.11

COPY requirements.txt ${LAMBDA_TASK_ROOT}/
RUN pip install --no-cache-dir -r requirements.txt --target ${LAMBDA_TASK_ROOT}

COPY allowlist.py ecs_actions.py rds_actions.py holidays_check.py health.py handler.py ${LAMBDA_TASK_ROOT}/

CMD ["handler.handler"]
