# Package FastAPI for AWS Lambda using the official Python base image.
FROM public.ecr.aws/lambda/python:3.12

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app/ ./app/

# Mangum handler defined in app/main.py
CMD ["app.main.handler"]
