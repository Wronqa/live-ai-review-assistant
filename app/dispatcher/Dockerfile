FROM public.ecr.aws/lambda/python:3.11

COPY requirements.txt ${LAMBDA_TASK_ROOT}/

RUN python -m pip install --no-cache-dir --upgrade pip && \
    python -m pip install --no-cache-dir \
      -r ${LAMBDA_TASK_ROOT}/requirements.txt \
      --target "${LAMBDA_TASK_ROOT}"


COPY handler.py ${LAMBDA_TASK_ROOT}/

CMD ["handler.lambda_handler"]
